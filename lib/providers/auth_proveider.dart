import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/models/moderator_model.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  User? _user;
  Moderator? _moderator;
  bool _isLoading = false;

  User? get currentUser => _user;
  Moderator? get currentModerator => _moderator;
  String? get userRole => _moderator?.role;
  String? get userStatus => _moderator?.status;
  bool get isLoading => _isLoading;
  bool get isAdmin => userRole == 'admin';

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadUserData(user);
    } else {
      _moderator = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserData(User user) async {
    final moderatorDoc = await _firebaseService.getModeratorDoc(user.uid);
    if (moderatorDoc != null && moderatorDoc.exists) {
      _moderator = Moderator.fromFirestore(moderatorDoc);
    } else {
      await signOut();
    }
  }

  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _moderator = null;
    notifyListeners();
  }
}