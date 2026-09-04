import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/auth/claim_account_screen.dart';
import 'package:mahlete_semay_project/screens/auth/waiting_for_approval_screen.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_proveider.dart';

import '../admin/portal_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if(mounted) {
      setState(() => _isOffline = !result.contains(ConnectivityResult.mobile) && !result.contains(ConnectivityResult.wifi));
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        switch (result) {
          case SignInResult.success:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PortalHomeScreen()),
            );
            break;
          case SignInResult.pendingApproval:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => WaitingForApprovalScreen()),
            );
            break;
          case SignInResult.failed:
          case SignInResult.accountBlocked:
            CustomSnackbar.show(context, authProvider.authError ?? 'An unknown error occurred.', isError: true);
            break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.secondary.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDFB76C).withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8)),

                  const SizedBox(height: 24),
                  Text(l10n.moderatorPortal, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 32, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(l10n.pleaseSignInToContinue, style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
                  const SizedBox(height: 48),

                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration(l10n.email, Icons.email_outlined),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty ? l10n.pleaseEnterEmail : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: _inputDecoration(l10n.password, Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white.withValues(alpha: 0.7)),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) => value!.isEmpty ? l10n.pleaseEnterPassword : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authProvider.isSigningIn || _isOffline ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: authProvider.isSigningIn
                          ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary))
                          : Text(l10n.signIn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.firstTimeHere, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClaimAccountScreen())),
                        child: Text(l10n.claimAccount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white, width: 2)),
    );
  }
}