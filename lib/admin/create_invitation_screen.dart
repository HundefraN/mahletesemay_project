import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'manage_invite_codes_screen.dart';
import 'widgets/admin_ui_kit.dart';

class CreateInvitationScreen extends StatefulWidget {
  const CreateInvitationScreen({super.key});

  @override
  State<CreateInvitationScreen> createState() => _CreateInvitationScreenState();
}

class _CreateInvitationScreenState extends State<CreateInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'moderator';
  bool _isLoading = false;
  String? _generatedCode;
  String? _invitedEmail;
  String? _invitedName;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createInvitation() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _generatedCode = null;
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final email = _emailController.text.trim().toLowerCase();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      try {
        final code = await _firebaseService.createInvitation(
          email: email,
          firstName: firstName,
          lastName: lastName,
          adminId: authProvider.currentUser?.uid ?? 'admin',
          role: _selectedRole,
        );
        setState(() {
          _generatedCode = code;
          _invitedEmail = email;
          _invitedName = '$firstName $lastName'.trim();
        });
        if (mounted) {
          CustomSnackbar.show(context, 'Invitation code generated successfully!');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Failed to create invitation: $e', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _shareInvitation(String code) {
    final name = _invitedName ?? 'Moderator';
    final roleText = _selectedRole.toUpperCase();
    final message = '''
Hello $name,

You have been invited to join the Mahlete Semay Moderator Portal as a $roleText!

Your One-Time Invitation Code: $code

How to activate your account:
1. Open the Mahlete Semay App.
2. Go to Settings ⚙️ -> Moderator Portal 🛡️.
3. Tap "Claim Account".
4. Enter your email ($invitedEmail), create your password, and enter your invitation code ($code).

This code is single-use and linked to your email. Welcome to the team!
''';
    Share.share(message, subject: 'Mahlete Semay - Moderator Portal Invitation');
  }

  String get invitedEmail => _invitedEmail ?? _emailController.text.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Create Invitation',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.history_rounded, size: 18),
            label: Text(AppLocalizations.of(context)?.historyButton ?? 'History'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageInviteCodesScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        physics: const BouncingScrollPhysics(),
        children: [
          // If code was generated, show success card
          if (_generatedCode != null) ...[
            AdminSectionHeader(
              title: AppLocalizations.of(context)?.invitationCodeReady ?? 'Invitation Code Ready!',
              icon: Icons.vpn_key_rounded,
              padding: EdgeInsets.only(top: 8, bottom: 10),
            ),
            AdminGlassCard(
              isGlowing: true,
              glowColor: AdminUiKit.goldAccent,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : AdminUiKit.goldAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminUiKit.goldAccent, width: 1.5),
                        ),
                        child: Text(
                          _generatedCode!,
                          style: GoogleFonts.firaCode(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: isDark ? AdminUiKit.goldHighlight : AdminUiKit.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AdminUiKit.goldAccent,
                          foregroundColor: AdminUiKit.primaryNavy,
                        ),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedCode!));
                          CustomSnackbar.show(context, 'Code copied to clipboard!');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Created for: $_invitedName ($invitedEmail)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AdminStatusBadge(
                    label: AppLocalizations.of(context)?.roleBadgePrefix(_selectedRole.toUpperCase()) ?? 'ROLE: ${_selectedRole.toUpperCase()}',
                    color: _selectedRole == 'admin' ? AdminUiKit.goldAccent : AdminUiKit.royalBlue,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AdminPrimaryButton(
                          label: AppLocalizations.of(context)?.shareInvitation ?? 'Share Invitation',
                          icon: Icons.share_rounded,
                          height: 46,
                          onPressed: () => _shareInvitation(_generatedCode!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Form
          AdminSectionHeader(
            title: AppLocalizations.of(context)?.inviteeDetails ?? 'Invitee Details',
            icon: Icons.person_add_rounded,
            padding: const EdgeInsets.only(top: 8, bottom: 10),
          ),
          AdminGlassCard(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          decoration: _inputDecoration('First Name *', Icons.person_outline_rounded),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          decoration: _inputDecoration('Last Name *', Icons.person_outline_rounded),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                    decoration: _inputDecoration('Email Address *', Icons.email_outlined),
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@') || !v.contains('.')) return 'Invalid email format';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: _inputDecoration('Assigned Role', Icons.shield_outlined),
                    items: [
                      DropdownMenuItem(value: 'moderator', child: Text(AppLocalizations.of(context)?.moderatorRoleDesc ?? 'Moderator (Content Editor)')),
                      DropdownMenuItem(value: 'admin', child: Text(AppLocalizations.of(context)?.adminRoleDesc ?? 'Administrator (Full Control)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          AdminPrimaryButton(
            label: AppLocalizations.of(context)?.generateInviteCode ?? 'Generate Invitation Code',
            icon: Icons.vpn_key_rounded,
            isLoading: _isLoading,
            onPressed: _createInvitation,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      prefixIcon: Icon(icon, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}