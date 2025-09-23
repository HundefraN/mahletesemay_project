import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';

class ClaimAccountScreen extends StatefulWidget {
  const ClaimAccountScreen({super.key});

  @override
  State<ClaimAccountScreen> createState() => _ClaimAccountScreenState();
}

class _ClaimAccountScreenState extends State<ClaimAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _claimAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.claimAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        inviteCode: _inviteCodeController.text.trim(),
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          CustomSnackbar.show(context, 'Account claimed successfully! You can now sign in.');
        } else {
          CustomSnackbar.show(context, authProvider.authError ?? 'An error occurred.', isError: true);
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Claim Your Account"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.secondary.withOpacity(0.6),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text('Moderator Account Setup', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 32),
                  TextFormField(controller: _emailController, decoration: _inputDecoration('Email Address', Icons.email_outlined), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _passwordController, decoration: _inputDecoration('Password', Icons.lock_outline), style: const TextStyle(color: Colors.white), obscureText: true, validator: (v) => v!.length < 6 ? 'Must be at least 6 characters' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _inviteCodeController, decoration: _inputDecoration('Invitation Code', Icons.vpn_key_outlined), style: const TextStyle(color: Colors.white), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _claimAccount,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3))
                          : const Text('Claim Account & Finalize Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                    ),
                  ),
                ],
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
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white, width: 2)),
    );
  }
}