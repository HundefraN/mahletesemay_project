import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/admin/widgets/admin_ui_kit.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/screens/admin/portal_home_screen.dart';
import 'package:mahlete_semay_project/screens/auth/waiting_for_approval_screen.dart';
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
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _claimAccount() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final cleanEmail = _emailController.text.trim().toLowerCase();
      final cleanPassword = _passwordController.text.trim();
      final cleanCode = _inviteCodeController.text.trim().toUpperCase();

      final result = await authProvider.claimAccount(
        email: cleanEmail,
        password: cleanPassword,
        inviteCode: cleanCode,
      );

      if (mounted) {
        switch (result) {
          case SignInResult.success:
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const PortalHomeScreen()),
              (route) => false,
            );
            CustomSnackbar.show(
              context,
              'Account claimed successfully! Welcome to the portal.',
            );
            break;
          case SignInResult.pendingApproval:
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => WaitingForApprovalScreen()),
              (route) => false,
            );
            break;
          case SignInResult.failed:
          case SignInResult.accountBlocked:
            CustomSnackbar.show(
              context,
              authProvider.authError ?? 'Failed to claim account.',
              isError: true,
            );
            break;
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          "Claim Your Account",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A1E3F), const Color(0xFF070E1B)]
                : [AdminUiKit.primaryNavy, const Color(0xFF132A52)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 24.0),
              child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // App Logo & Shield Badge
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AdminUiKit.goldAccent.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().scale().fadeIn(),
                  const SizedBox(height: 18),
                  Text(
                    'Portal Activation',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your invitation credentials to claim and activate your moderator or administrator access.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration('Invited Email Address', Icons.email_outlined),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.5),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Invitation Code Input
                  TextFormField(
                    controller: _inviteCodeController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      _CodeInputFormatter(),
                    ],
                    decoration: _inputDecoration('Invitation Code (e.g. MS-XXXX-XXXX)', Icons.vpn_key_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, color: AdminUiKit.goldHighlight, size: 20),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            setState(() {
                              _inviteCodeController.text = data.text!.trim().toUpperCase();
                            });
                          }
                        },
                      ),
                    ),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontSize: 15,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Invitation code is required';
                      if (v.trim().length < 6) return 'Enter a valid code';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('Create New Password', Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.5),
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Input
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _claimAccount(),
                    decoration: _inputDecoration('Confirm Password', Icons.lock_reset_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.5),
                    validator: (v) {
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Claim Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _claimAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AdminUiKit.primaryNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AdminUiKit.primaryNavy),
                            )
                          : Text(
                              'Claim Account & Activate',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AdminUiKit.primaryNavy,
                              ),
                            ),
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
      labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminUiKit.goldAccent, width: 1.8)),
    );
  }
}

class _CodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Keep uppercase and alphanumeric or dash
    final cleaned = newValue.text.toUpperCase();
    return TextEditingValue(
      text: cleaned,
      selection: newValue.selection,
    );
  }
}