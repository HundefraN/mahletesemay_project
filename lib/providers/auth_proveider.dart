import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/moderator_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';

enum SignInResult { success, failed, pendingApproval, accountBlocked }

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  User? _user;
  Moderator? _moderator;
  bool _isSigningIn = false;
  bool _isLoadingUser = true;
  String? _authError;
  StreamSubscription<DocumentSnapshot>? _moderatorSubscription;

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
    _auth.authStateChanges().listen(_onAuthStateChanged);
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
          'addedAt': Timestamp.now(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'id': iosInfo.identifierForVendor ?? 'unknown',
          'os': 'iOS ${iosInfo.systemVersion}',
          'model': iosInfo.utsname.machine,
          'type': iosInfo.isPhysicalDevice ? 'Physical' : 'Simulator',
          'addedAt': Timestamp.now(),
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
      _setupSecurityListener(user.uid);
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

    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;

      if (user == null) {
        _authError = "Authentication failed. Please try again.";
        return SignInResult.failed;
      }

      final moderatorDoc = await _firebaseService.getModeratorDoc(user.uid);
      if (!moderatorDoc.exists) {
        _authError = "Your moderator profile does not exist. Please claim your account first or contact an admin.";
        await _auth.signOut();
        return SignInResult.failed;
      }

      _moderator = Moderator.fromFirestore(moderatorDoc);

      if (_moderator!.status == 'blocked') {
        _authError = "Your account is currently blocked. Contact an admin.";
        await _auth.signOut();
        return SignInResult.accountBlocked;
      }

      final currentDeviceInfo = await _getDeviceInfo();
      if (currentDeviceInfo == null) {
        _authError = "Could not verify your device.";
        await _auth.signOut();
        return SignInResult.failed;
      }
      final currentDeviceId = currentDeviceInfo['id'];
      final isDeviceApproved = _moderator!.approvedDevices.any((d) => d['id'] == currentDeviceId);

      if (!isDeviceApproved) {
        if (_moderator!.pendingDevice == null || _moderator!.pendingDevice!['id'] != currentDeviceId) {
          await _firebaseService.setModeratorData(user.uid, {
            'pendingDevice': currentDeviceInfo,
            'status': 'review',
          });
          await _firebaseService.logActivity(
            moderatorId: user.uid,
            moderatorName: _moderator!.fullName,
            action: "NEW_DEVICE_REQUEST",
            details: "New device login attempt from ${currentDeviceInfo['model']}",
          );
        }
        return SignInResult.pendingApproval;
      }

      return SignInResult.success;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          _authError = 'Incorrect email or password.';
          break;
        case 'too-many-requests':
          _authError = 'Too many failed attempts. Please try again later.';
          break;
        case 'user-disabled':
          _authError = 'This account has been disabled.';
          break;
        default:
          _authError = "Authentication error: ${e.message}";
      }
      return SignInResult.failed;
    } catch (e) {
      _authError = "An unexpected error occurred: ${e.toString()}";
      return SignInResult.failed;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<bool> claimAccount({required String email, required String password, required String inviteCode}) async {
    _isSigningIn = true;
    _authError = null;
    notifyListeners();

    try {
      final invitation = await _firebaseService.getInvitationByCode(inviteCode);
      if (invitation == null) {
        _authError = "This invitation code is invalid, expired, or has already been used.";
        return false;
      }

      if (invitation.email.toLowerCase() != email.toLowerCase()) {
        _authError = "This invitation is for a different email address.";
        return false;
      }

      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;

      if (user == null) {
        _authError = "Could not sign in to claim account. Please check your password.";
        return false;
      }

      final username = "${invitation.firstName.toLowerCase()}.${invitation.lastName.toLowerCase()}";
      final moderatorData = {
        'email': invitation.email,
        'firstName': invitation.firstName,
        'lastName': invitation.lastName,
        'username': username,
        'role': 'moderator',
        'status': 'active',
        'approvedDevices': [],
        'pendingDevice': null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firebaseService.setModeratorData(user.uid, moderatorData);
      await _firebaseService.claimInvitation(invitation.id, user.uid);
      await _auth.signOut();

      return true;
    } on FirebaseAuthException {
      _authError = "Incorrect email or password. You must be able to log in to claim the account.";
      return false;
    } catch (e) {
      _authError = e.toString();
      return false;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }


  @override
  void dispose() {
    _moderatorSubscription?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    await _moderatorSubscription?.cancel();
    _moderatorSubscription = null;
    _moderator = null;
    _isLoadingUser = false;
    _authError = null;
    await _auth.signOut();
    notifyListeners();
  }

  void _setupSecurityListener(String uid) {
    _moderatorSubscription?.cancel();
    _moderatorSubscription = _firebaseService.getModeratorStream(uid).listen((snapshot) async {
      if (!snapshot.exists) {
        _authError = "Your moderator profile was removed.";
        await signOut();
        return;
      }

      final latestModerator = Moderator.fromFirestore(snapshot);
      _moderator = latestModerator;

      if (latestModerator.role != 'admin' && latestModerator.status != 'active') {
        _authError = "Your account status was changed to '${latestModerator.status}'.";
        await signOut();
        return;
      }

      if (latestModerator.status == 'active' && latestModerator.pendingDevice == null) {
        await _firebaseService.setModeratorData(uid, {'lastLogin': FieldValue.serverTimestamp()});
      }

      if (_isLoadingUser) {
        _isLoadingUser = false;
      }
      notifyListeners();
    });
  }
}