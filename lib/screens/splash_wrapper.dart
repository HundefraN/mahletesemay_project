import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/permissions/permission_screen.dart';
import '../services/force_update_service.dart';
import '../widgets/force_update_dialog.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// ──────────────────────────────────────────────────────────────────────────────
/// SplashWrapper — app initialization gate
/// ──────────────────────────────────────────────────────────────────────────────
///
/// This widget is the first screen shown after the native splash. It resolves
/// several asynchronous checks in order:
///
/// 1. **Force update check** — queries the backend for `min_required_version`
///    and compares it against the installed version. If an update is required,
///    an un-dismissible dialog blocks the user (see [ForceUpdateDialog]).
///
/// 2. **Permissions** — first-run permission request screen.
///
/// 3. **Onboarding** — first-run onboarding carousel.
///
/// 4. **HomeScreen** — the main app.
///
/// Place any other startup-gate checks (maintenance mode, auth, etc.) alongside
/// step 1 inside [_checkAppStatus].
/// ──────────────────────────────────────────────────────────────────────────────
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

enum AppStatus { checking, needsUpdate, needsPermissions, needsOnboarding, ready }

class _SplashWrapperState extends State<SplashWrapper> {
  late Future<AppStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _checkAppStatus();
    // The splash screen is removed only when the future is complete.
    _statusFuture.whenComplete(() {
      FlutterNativeSplash.remove();
    });
  }

  Future<AppStatus> _checkAppStatus() async {
    // ── 1. Force update check ───────────────────────────────────────────────
    // This runs before anything else: if an update is required the user is
    // blocked immediately. The check is intentionally fail-open — if the
    // backend is unreachable or the column doesn't exist, the app proceeds.
    final updateResult = await ForceUpdateService.instance.checkForUpdate();
    if (updateResult.updateRequired) {
      return AppStatus.needsUpdate;
    }

    // ── 2. Local preferences (permissions / onboarding) ─────────────────────
    final prefs = await SharedPreferences.getInstance();
    final bool hasCompletedPermissions =
        prefs.getBool('permissions_completed') ?? false;
    final bool hasCompletedOnboarding =
        prefs.getBool('onboarding_completed') ?? false;

    if (!hasCompletedPermissions) {
      return AppStatus.needsPermissions;
    } else if (!hasCompletedOnboarding) {
      return AppStatus.needsOnboarding;
    } else {
      return AppStatus.ready;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final status = snapshot.data;
          switch (status) {
            // Force update: show the home screen underneath but immediately
            // present the blocking dialog. Using addPostFrameCallback ensures
            // the dialog is shown after the widget tree is built.
            case AppStatus.needsUpdate:
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) ForceUpdateDialog.show(context);
              });
              // Show an empty scaffold behind the dialog.
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const SizedBox.shrink(),
              );
            case AppStatus.needsPermissions:
              return const PermissionScreen();
            case AppStatus.needsOnboarding:
              return const OnboardingScreen();
            case AppStatus.ready:
              return const HomeScreen();
            default:
              return const Scaffold(body: Center(child: Text("Error")));
          }
        }

        // While the future is resolving, the native splash screen is shown,
        // so returning an empty container is fine and prevents any flicker.
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
