import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
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
      if (Platform.isAndroid) {
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
    final isSeedAdmin = normalizedEmail == 'admin@gmail.com' && trimmedPassword == '123456';

    try {
      User? user;
      try {
        final response = await _supabase.auth.signInWithPassword(
          email: normalizedEmail,
          password: trimmedPassword,
        );
        user = response.user;
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        // If email not confirmed, attempt auto confirmation then retry
        if (msg.contains('not confirmed') || msg.contains('unconfirmed')) {
          try {
            final dummySignUp = await _supabase.auth.signUp(email: normalizedEmail, password: trimmedPassword);
            if (dummySignUp.user != null) {
              await _supabaseService.confirmUserEmail(dummySignUp.user!.id);
              final retryRes = await _supabase.auth.signInWithPassword(email: normalizedEmail, password: trimmedPassword);
              user = retryRes.user;
            }
          } catch (_) {}
        }

        // If seed admin doesn't exist yet in Supabase Auth, bootstrap account
        if (user == null && isSeedAdmin) {
          try {
            final signUpRes = await _supabase.auth.signUp(
              email: normalizedEmail,
              password: trimmedPassword,
            );
            user = signUpRes.user;
            if (user != null) {
              await _supabaseService.confirmUserEmail(user.id);
            }
          } catch (signUpErr) {
            debugPrint("Admin bootstrap signUp error: $signUpErr");
          }
        }
        if (user == null) {
          _authError = e.message;
          return SignInResult.failed;
        }
      } catch (e) {
        if (isSeedAdmin) {
          try {
            final signUpRes = await _supabase.auth.signUp(
              email: normalizedEmail,
              password: trimmedPassword,
            );
            user = signUpRes.user;
          } catch (_) {}
        }
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
        if (isSeedAdmin || normalizedEmail == 'admin@gmail.com') {
          final adminProfile = {
            'id': user.id,
            'email': normalizedEmail,
            'first_name': 'Admin',
            'last_name': 'User',
            'username': 'admin',
            'role': 'admin',
            'status': 'active',
            'is_active': true,
            'approved_devices': currentDeviceInfo != null ? [currentDeviceInfo] : [],
            'pending_device': null,
            'created_at': DateTime.now().toIso8601String(),
            'last_login': DateTime.now().toIso8601String(),
          };
          await _supabaseService.setModeratorData(user.id, adminProfile);
          _moderator = Moderator.fromMap(adminProfile, user.id);
          _user = user;
          _setupSecurityListener(user.id);
          await _supabaseService.logActivity(
            moderatorId: user.id,
            moderatorName: 'Admin User',
            action: 'ADMIN_BOOTSTRAP',
            details: 'Master Admin account initialized and logged in',
          );
          return SignInResult.success;
        } else {
          _authError = "Your moderator profile was not found. Please claim your account first using your invitation code.";
          await _supabase.auth.signOut();
          return SignInResult.failed;
        }
      }

      _moderator = Moderator.fromMap(moderatorDoc.data(), user.id);

      if (_moderator!.status == 'blocked') {
        _authError = "Your account is currently blocked. Please contact an administrator.";
        await _supabase.auth.signOut();
        return SignInResult.accountBlocked;
      }

      // If user is Admin, auto-approve device to prevent administrative lockouts
      if (_moderator!.role == 'admin' || isSeedAdmin) {
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

  Future<SignInResult> claimAccount({required String email, required String password, required String inviteCode}) async {
    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanCode = inviteCode.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();

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

      final invitation = await _supabaseService.getInvitationByCode(cleanCode);
      if (invitation == null) {
        _authError = "Invitation code '$inviteCode' was not found. Please check your code or ask an admin for a new invite.";
        return SignInResult.failed;
      }

      if (invitation.email.toLowerCase().trim() != cleanEmail) {
        _authError = "This invitation was issued to '${invitation.email}'. Please enter that email address to claim this account.";
        return SignInResult.failed;
      }

      if (invitation.isClaimed) {
        _authError = "This invitation has already been claimed. Please sign in directly with your email and password.";
        return SignInResult.failed;
      }

      if (invitation.status.toLowerCase() == 'revoked') {
        _authError = "This invitation was revoked by an administrator.";
        return SignInResult.failed;
      }

      final currentDeviceInfo = await _getDeviceInfo();
      final username = "${invitation.firstName.toLowerCase().replaceAll(' ', '')}.${invitation.lastName.toLowerCase().replaceAll(' ', '')}";

      // Step 1: Run secure claim stored procedure (creates/updates auth.users directly, bypassing email rate limit)
      final rpcResult = await _supabaseService.claimModeratorAccountRpc(
        email: cleanEmail,
        password: password.trim(),
        code: invitation.code,
        deviceInfo: currentDeviceInfo,
      );

      if (rpcResult != null && rpcResult['success'] == false) {
        _authError = rpcResult['error']?.toString() ?? 'Could not claim account.';
        return SignInResult.failed;
      }

      // Step 2: Establish active session via signInWithPassword (no confirmation email needed)
      User? activeUser;
      try {
        final signInRes = await _supabase.auth.signInWithPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        activeUser = signInRes.user;
      } on AuthException catch (e) {
        // If signIn fails, try fallback signUp / confirmation
        try {
          final signUpRes = await _supabase.auth.signUp(
            email: cleanEmail,
            password: password.trim(),
          );
          activeUser = signUpRes.user;
          if (activeUser != null) {
            await _supabaseService.confirmUserEmail(activeUser.id);
            final retry = await _supabase.auth.signInWithPassword(email: cleanEmail, password: password.trim());
            activeUser = retry.user;
          }
        } on AuthException catch (signUpErr) {
          final msg = signUpErr.message.toLowerCase();
          if (msg.contains('rate limit')) {
            _authError = "Email service rate limit reached. Please run the provided SQL script in Supabase or try again in a few minutes.";
          } else {
            _authError = signUpErr.message;
          }
          return SignInResult.failed;
        } catch (_) {
          _authError = e.message;
          return SignInResult.failed;
        }
      } catch (e) {
        _authError = "Sign-in after claim failed: ${e.toString()}";
        return SignInResult.failed;
      }

      final verifiedUser = activeUser ?? _supabase.auth.currentUser;
      if (verifiedUser == null) {
        _authError = "Could not establish user authentication session.";
        return SignInResult.failed;
      }

      // Step 3: Ensure moderator profile and invitation are updated
      final moderatorData = {
        'id': verifiedUser.id,
        'email': cleanEmail,
        'first_name': invitation.firstName,
        'last_name': invitation.lastName,
        'username': username,
        'role': invitation.role,
        'status': 'active',
        'is_active': true,
        'approved_devices': currentDeviceInfo != null ? [currentDeviceInfo] : [],
        'pending_device': null,
        'created_at': DateTime.now().toIso8601String(),
        'last_login': DateTime.now().toIso8601String(),
      };
      await _supabaseService.setModeratorData(verifiedUser.id, moderatorData);
      await _supabaseService.claimInvitation(invitation.id, verifiedUser.id);
      await _supabaseService.confirmUserEmail(verifiedUser.id);

      // Step 4: Log activity
      await _supabaseService.logActivity(
        moderatorId: verifiedUser.id,
        moderatorName: '${invitation.firstName} ${invitation.lastName}',
        action: 'ACCOUNT_CLAIMED',
        details: 'Claimed ${invitation.role.toUpperCase()} account with code ${invitation.code}',
      );

      // Step 7: Load freshly synced moderator profile
      final freshDoc = await _supabaseService.getModeratorDoc(verifiedUser.id);
      if (freshDoc.exists) {
        _moderator = Moderator.fromMap(freshDoc.data(), verifiedUser.id);
      } else {
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