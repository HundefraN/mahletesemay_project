import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/permissions/permission_screen.dart';
import '../services/app_update_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'onboarding/language_selection_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'update/app_update_lock_screen.dart';

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
/// 2. **Language Selection** — first-run language picker (EN / AM / OM).
///
/// 3. **Permissions** — first-run professional permission request screen (Mobile only).
///
/// 4. **Onboarding** — modern 2026 onboarding carousel (Mobile only).
///
/// 5. **HomeScreen** — the main app.
/// ──────────────────────────────────────────────────────────────────────────────
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

enum AppStatus {
  checking,
  needsUpdate,
  needsLanguage,
  needsPermissions,
  needsOnboarding,
  ready,
}

class _SplashWrapperState extends State<SplashWrapper> {
  late Future<AppStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _checkAppStatus();
    // The splash screen is removed only when the future is complete.
    // On web we never called FlutterNativeSplash.preserve(), so skip remove().
    if (!kIsWeb) {
      _statusFuture.whenComplete(() {
        FlutterNativeSplash.remove();
      });
    }
  }

  Future<AppStatus> _checkAppStatus() async {
    if (kIsWeb) {
      // ── Web path ───────────────────────────────────────────────────────────
      // Services are already initialized in main(). No force-update check,
      // no permission/onboarding/language selection gates on web initial load.
      return AppStatus.ready;
    }

    // ── Mobile path (unchanged) ─────────────────────────────────────────────

    // ── 1. Force update check ───────────────────────────────────────────────
    // This runs before anything else: if an update is required the user is
    // blocked immediately. The check is intentionally fail-open — if the
    // backend is unreachable or the column doesn't exist, the app proceeds.
    final isUpdateRequired = await AppUpdateService.instance.checkForUpdate();
    if (isUpdateRequired) {
      return AppStatus.needsUpdate;
    }

    // ── 2. Local preferences (language / permissions / onboarding) ──────────
    final prefs = await SharedPreferences.getInstance();
    final bool hasSelectedLanguage =
        prefs.getBool(prefLanguageSelected) ?? false;
    final bool hasCompletedPermissions =
        prefs.getBool(prefPermissionsCompleted) ?? false;
    final bool hasCompletedOnboarding =
        prefs.getBool(prefOnboardingCompleted) ?? false;

    // On Mobile (iOS & Android): Show language, permissions, and onboarding flows.
    if (!hasSelectedLanguage) {
      return AppStatus.needsLanguage;
    } else if (!hasCompletedPermissions) {
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
            // Force update: show production non-dismissible AppUpdateLockScreen
            case AppStatus.needsUpdate:
              return AppUpdateLockScreen(
                config: AppUpdateService.instance.currentConfig,
              );
            case AppStatus.needsLanguage:
              return const LanguageSelectionScreen();
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

        // While the future is resolving, the native splash screen is shown.
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
