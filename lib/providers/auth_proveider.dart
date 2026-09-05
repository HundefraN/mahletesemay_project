import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/moderator_model.dart';
import '../services/fcm_service.dart';
import '../services/supabase_service.dart';

enum SignInResult { success, failed, pendingApproval, accountBlocked }

extension SupabaseUserCompatExtension on User {
  String get uid => id;
}

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  User? _user;
  Moderator? _moderator;
  bool _isSigningIn = false;
  bool _isLoadingUser = true;
  String? _authError;
  StreamSubscription? _moderatorSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  User? get currentUser => _user;
  Moderator? get currentModerator => _moderator;
  String? get userRole => _moderator?.role;
  String? get userStatus => _moderator?.status;
  bool get isSigningIn => _isSigningIn;
  bool get isLoadingUser => _isLoadingUser;
  String? get authError => _authError;
  bool get isAdmin => userRole == 'admin';

  AuthProvider() {
    _isLoadingUser = true;
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      _setupSecurityListener(_user!.id);
    } else {
      _isLoadingUser = false;
    }

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      _onAuthStateChanged(data.session?.user);
    });
  }

  Future<Map<String, dynamic>?> _getDeviceInfo() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return {
          'id': 'web_${webInfo.userAgent?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch}',
          'os': 'Web ${webInfo.browserName.name}',
          'model': webInfo.platform ?? 'Web Browser',
          'type': 'Browser',
          'addedAt': DateTime.now().toIso8601String(),
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'id': androidInfo.id,
          'os': 'Android ${androidInfo.version.release}',
          'model': '${androidInfo.brand} ${androidInfo.model}',
          'type': androidInfo.isPhysicalDevice ? 'Physical' : 'Emulator',
          'addedAt': DateTime.now().toIso8601String(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'id': iosInfo.identifierForVendor ?? 'unknown',
          'os': 'iOS ${iosInfo.systemVersion}',
          'model': iosInfo.utsname.machine,
          'type': iosInfo.isPhysicalDevice ? 'Physical' : 'Simulator',
          'addedAt': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      debugPrint("Error getting device info: $e");
    }
    return null;
  }

  Future<void> _onAuthStateChanged(User? user) async {
    await _moderatorSubscription?.cancel();
    _user = user;

    if (user != null) {
      _setupSecurityListener(user.id);
      FcmService.updateUserToken(user.id);
    } else {
      _moderator = null;
      _isLoadingUser = false;
      _authError = null;
      notifyListeners();
    }
  }

  Future<SignInResult> signIn(String email, String password) async {
    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();
    final trimmedPassword = password.trim();

    try {
      User? user;
      try {
        user = await _signInRepairingSchema(normalizedEmail, trimmedPassword);
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        // If email not confirmed, attempt auto confirmation then retry
        if (msg.contains('not confirmed') || msg.contains('unconfirmed')) {
          try {
            final dummySignUp = await _supabase.auth.signUp(email: normalizedEmail, password: trimmedPassword);
            if (dummySignUp.user != null) {
              await _supabaseService.confirmUserEmail(dummySignUp.user!.id);
              user = await _signInRepairingSchema(normalizedEmail, trimmedPassword);
            }
          } catch (_) {}
        }

        if (user == null) {
          if (msg.contains('database error querying schema') || msg.contains('unexpected_failure')) {
            _authError = "Account synchronization in progress. Please try logging in again.";
          } else {
            _authError = e.message;
          }
          return SignInResult.failed;
        }
      } catch (e) {
        if (user == null) {
          _authError = "Authentication failed: ${e.toString()}";
          return SignInResult.failed;
        }
      }

      if (user == null) {
        _authError = "Authentication failed. Please check your credentials.";
        return SignInResult.failed;
      }

      final currentDeviceInfo = await _getDeviceInfo();
      final currentDeviceId = currentDeviceInfo?['id'] ?? 'device_${DateTime.now().millisecondsSinceEpoch}';

      // Check moderator document
      var moderatorDoc = await _supabaseService.getModeratorDoc(user.id);

      // Handle missing moderator document
      if (!moderatorDoc.exists) {
        _authError = "Your moderator profile was not found. Please claim your account first using your invitation code.";
        await _supabase.auth.signOut();
        return SignInResult.failed;
      }

      _moderator = Moderator.fromMap(moderatorDoc.data(), user.id);

      if (_moderator!.status == 'blocked') {
        _authError = "Your account is currently blocked. Please contact an administrator.";
        await _supabase.auth.signOut();
        return SignInResult.accountBlocked;
      }

      // If user is Admin, auto-approve device to prevent administrative lockouts
      if (_moderator!.role == 'admin') {
        final isDeviceApproved = _moderator!.approvedDevices.any((d) => d['id'] == currentDeviceId);
        if (!isDeviceApproved && currentDeviceInfo != null) {
          final updatedDevices = List<Map<String, dynamic>>.from(_moderator!.approvedDevices)..add(currentDeviceInfo);
          await _supabaseService.setModeratorData(user.id, {
            'approved_devices': updatedDevices,
            'pending_device': null,
            'status': 'active',
            'last_login': DateTime.now().toIso8601String(),
          });
        } else {
          await _supabaseService.setModeratorData(user.id, {
            'last_login': DateTime.now().toIso8601String(),
          });
        }
        _user = user;
        _setupSecurityListener(user.id);
        await _supabaseService.logActivity(
          moderatorId: user.id,
          moderatorName: _moderator!.fullName.isNotEmpty ? _moderator!.fullName : 'Admin',
          action: 'ADMIN_LOGIN',
          details: 'Admin logged in from ${currentDeviceInfo?['model'] ?? 'Authorized Device'}',
        );
        return SignInResult.success;
      }

      // For standard moderators
      final isDeviceApproved = _moderator!.approvedDevices.any((d) => d['id'] == currentDeviceId);

      // Auto-approve primary device if list is currently empty
      if (!isDeviceApproved && _moderator!.approvedDevices.isEmpty && currentDeviceInfo != null) {
        await _supabaseService.setModeratorData(user.id, {
          'approved_devices': [currentDeviceInfo],
          'pending_device': null,
          'status': 'active',
          'last_login': DateTime.now().toIso8601String(),
        });
        _user = user;
        _setupSecurityListener(user.id);
        await _supabaseService.logActivity(
          moderatorId: user.id,
          moderatorName: _moderator!.fullName,
          action: 'MODERATOR_LOGIN',
          details: 'Primary device auto-authorized: ${currentDeviceInfo['model']}',
        );
        return SignInResult.success;
      }

      if (!isDeviceApproved) {
        if (currentDeviceInfo != null) {
          if (_moderator!.pendingDevice == null || _moderator!.pendingDevice!['id'] != currentDeviceId) {
            await _supabaseService.setModeratorData(user.id, {
              'pending_device': currentDeviceInfo,
              'status': 'review',
            });
            await _supabaseService.logActivity(
              moderatorId: user.id,
              moderatorName: _moderator!.fullName,
              action: 'NEW_DEVICE_REQUEST',
              details: 'New device login attempt from ${currentDeviceInfo['model']}',
            );
          }
        }
        return SignInResult.pendingApproval;
      }

      await _supabaseService.setModeratorData(user.id, {
        'status': 'active',
        'last_login': DateTime.now().toIso8601String(),
      });

      await _supabaseService.logActivity(
        moderatorId: user.id,
        moderatorName: _moderator!.fullName,
        action: 'MODERATOR_LOGIN',
        details: 'Moderator logged in from ${currentDeviceInfo?['model'] ?? 'Authorized Device'}',
      );

      _user = user;
      _setupSecurityListener(user.id);
      return SignInResult.success;
    } on AuthException catch (e) {
      _authError = e.message;
      return SignInResult.failed;
    } catch (e) {
      _authError = "An unexpected error occurred: ${e.toString()}";
      return SignInResult.failed;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  String _friendlyInviteError(String? rawError, String displayCode) {
    final error = (rawError ?? '').toLowerCase();
    if (error.contains('not found') || error.contains('invalid invitation')) {
      return "Invitation code '$displayCode' was not found. Please check your code or ask an admin for a new invite.";
    }
    if (rawError != null && rawError.trim().isNotEmpty) {
      return rawError;
    }
    return 'Could not claim account. Please check your invitation code and email.';
  }

  Future<User?> _signInRepairingSchema(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      return res.user;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('schema') || msg.contains('database error') || msg.contains('unexpected_failure')) {
        await _supabaseService.repairAuthUsersSchema();
        final retry = await _supabase.auth.signInWithPassword(email: email, password: password);
        return retry.user;
      }
      rethrow;
    }
  }

  Future<SignInResult> claimAccount({required String email, required String password, required String inviteCode}) async {
    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    try {
      final cleanEmail = email.trim().toLowerCase();
      final displayCode = inviteCode.trim().toUpperCase();
      final cleanCode = displayCode.replaceAll('-', '').replaceAll(' ', '');

      if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
        _authError = "Please enter a valid email address.";
        return SignInResult.failed;
      }
      if (cleanCode.isEmpty) {
        _authError = "Please enter your invitation code.";
        return SignInResult.failed;
      }
      if (password.trim().length < 6) {
        _authError = "Password must be at least 6 characters.";
        return SignInResult.failed;
      }

      final currentDeviceInfo = await _getDeviceInfo();

      // Validate + claim server-side. Client SELECT on invitations is blocked
      // for anonymous users after RLS hardening, so do not look the row up here.
      final rpcResult = await _supabaseService.claimModeratorAccountRpc(
        email: cleanEmail,
        password: password.trim(),
        code: displayCode,
        deviceInfo: currentDeviceInfo,
      );

      if (rpcResult == null) {
        _authError = "Could not reach the invitation service. Please try again.";
        return SignInResult.failed;
      }

      if (rpcResult['success'] == false) {
        _authError = _friendlyInviteError(rpcResult['error']?.toString(), displayCode);
        return SignInResult.failed;
      }

      final firstName = rpcResult['first_name']?.toString() ?? '';
      final lastName = rpcResult['last_name']?.toString() ?? '';
      final role = rpcResult['role']?.toString() ?? 'moderator';
      final username = "${firstName.toLowerCase().replaceAll(' ', '')}.${lastName.toLowerCase().replaceAll(' ', '')}";

      User? activeUser;
      try {
        activeUser = await _signInRepairingSchema(cleanEmail, password.trim());
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('rate limit')) {
          _authError = "Your account was successfully claimed! Please sign in from the login screen.";
          return SignInResult.failed;
        }
        if (msg.contains('schema') || msg.contains('database error') || msg.contains('unexpected_failure')) {
          _authError = "Account synchronized successfully. Please sign in directly with your email and password.";
          return SignInResult.failed;
        }
        _authError = e.message;
        return SignInResult.failed;
      } catch (e) {
        _authError = "Sign-in after claim failed: ${e.toString()}";
        return SignInResult.failed;
      }

      final verifiedUser = activeUser ?? _supabase.auth.currentUser;
      if (verifiedUser == null) {
        _authError = "Your account was claimed. Please sign in with your email and password.";
        return SignInResult.failed;
      }

      await _supabaseService.confirmUserEmail(verifiedUser.id);

      final moderatorData = {
        'id': verifiedUser.id,
        'email': cleanEmail,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'role': role,
        'status': 'active',
        'is_active': true,
        'approved_devices': currentDeviceInfo != null ? [currentDeviceInfo] : [],
        'pending_device': null,
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
      };

      final freshDoc = await _supabaseService.getModeratorDoc(verifiedUser.id);
      if (freshDoc.exists) {
        _moderator = Moderator.fromMap(freshDoc.data(), verifiedUser.id);
      } else {
        await _supabaseService.setModeratorData(verifiedUser.id, moderatorData);
        _moderator = Moderator.fromMap(moderatorData, verifiedUser.id);
      }

      _user = verifiedUser;
      _isLoadingUser = false;
      _authError = null;
      notifyListeners();

      _setupSecurityListener(verifiedUser.id);

      return SignInResult.success;
    } on AuthException catch (e) {
      _authError = e.message;
      return SignInResult.failed;
    } catch (e) {
      _authError = "Claim failed: ${e.toString()}";
      return SignInResult.failed;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _moderatorSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    await _moderatorSubscription?.cancel();
    _moderatorSubscription = null;
    _moderator = null;
    _isLoadingUser = false;
    _authError = null;
    await _supabase.auth.signOut();
    notifyListeners();
  }

  void _setupSecurityListener(String uid) async {
    _moderatorSubscription?.cancel();
    
    // Add a timeout to prevent infinite loading if the stream is delayed or offline
    Future.delayed(const Duration(seconds: 3), () {
      if (_isLoadingUser) {
        _isLoadingUser = false;
        notifyListeners();
      }
    });

    // Initial direct fetch to ensure immediate load without relying solely on realtime stream
    try {
      final doc = await _supabaseService.getModeratorDoc(uid);
      if (doc.exists) {
        _moderator = Moderator.fromMap(doc.data(), uid);
        _isLoadingUser = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching initial moderator doc: $e');
    }

    _moderatorSubscription = _supabaseService.getModeratorStream(uid).listen((snapshot) async {
      if (!snapshot.exists) {
        // Double check via direct query before signing out to avoid false positives from stream delay/RLS
        final doubleCheckDoc = await _supabaseService.getModeratorDoc(uid);
        if (!doubleCheckDoc.exists) {
          _authError = "Your moderator profile was removed.";
          await signOut();
          return;
        } else {
          _moderator = Moderator.fromMap(doubleCheckDoc.data(), uid);
          _isLoadingUser = false;
          notifyListeners();
          return;
        }
      }

      final latestModerator = Moderator.fromMap(snapshot.data(), uid);
      _moderator = latestModerator;

      if (latestModerator.status == 'blocked') {
        _authError = "Your account has been blocked by an administrator.";
        await signOut();
        return;
      }

      if (latestModerator.role != 'admin' && latestModerator.status != 'active' && latestModerator.status != 'review') {
        _authError = "Your account status was changed to '${latestModerator.status}'.";
        await signOut();
        return;
      }

      if (_isLoadingUser) {
        _isLoadingUser = false;
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error in moderator stream: $error');
      if (_isLoadingUser) {
        _isLoadingUser = false;
        notifyListeners();
      }
    });
  }
}