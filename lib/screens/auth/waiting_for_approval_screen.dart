import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/admin/widgets/admin_ui_kit.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/screens/admin/portal_home_screen.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';

class WaitingForApprovalScreen extends StatefulWidget {
  const WaitingForApprovalScreen({super.key});

  @override
  State<WaitingForApprovalScreen> createState() => _WaitingForApprovalScreenState();
}

class _WaitingForApprovalScreenState extends State<WaitingForApprovalScreen> {
  bool _isChecking = false;

  void _checkStatus() async {
    setState(() => _isChecking = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      // Re-trigger auth listener check
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        if (authProvider.userStatus == 'active' || authProvider.isAdmin) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PortalHomeScreen()),
            (route) => false,
          );
          CustomSnackbar.show(context, 'Device approved! Welcome to the portal.');
          return;
        } else {
          CustomSnackbar.show(context, 'Still waiting for admin approval.');
        }
      }
    }
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Auto-navigate when approved by an admin
        if (authProvider.userStatus == 'active' || authProvider.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const PortalHomeScreen()),
                (route) => false,
              );
            }
          });
        }

        final modName = authProvider.currentModerator?.fullName ?? 'Moderator';

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0A1E3F), const Color(0xFF070E1B)]
                    : [AdminUiKit.primaryNavy.withOpacity(0.08), const Color(0xFFF5F7FB)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Shield Icon with Pulse
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AdminUiKit.amberOrange, AdminUiKit.goldAccent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AdminUiKit.amberOrange.withOpacity(0.35),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shield_outlined,
                            size: 52,
                            color: AdminUiKit.primaryNavy,
                          ),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 1500.ms),
                      const SizedBox(height: 28),

                      Text(
                        'Device Approval Pending',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Hello $modName, your login request from this device has been submitted. An administrator will review and authorize your device.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                          height: 1.55,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Status Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AdminUiKit.amberOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Listening for admin authorization...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminUiKit.amberOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Refresh Status Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isChecking ? null : _checkStatus,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(_isChecking ? 'Checking...' : 'Check Status'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminUiKit.royalBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => authProvider.signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign Out & Return'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminUiKit.roseRed,
                            side: BorderSide(color: AdminUiKit.roseRed.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      },
    );
  }
}