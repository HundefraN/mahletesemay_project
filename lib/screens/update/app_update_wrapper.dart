import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/app_update_service.dart';
import 'app_update_lock_screen.dart';

/// App-level root wrapper that monitors remote release configuration
/// and intercepts all app navigation when a mandatory update is required.
class AppUpdateWrapper extends StatefulWidget {
  final Widget child;

  const AppUpdateWrapper({super.key, required this.child});

  @override
  State<AppUpdateWrapper> createState() => _AppUpdateWrapperState();
}

class _AppUpdateWrapperState extends State<AppUpdateWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Live monitoring: Realtime + push-triggered apply + foreground poll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.instance.startMonitoring();
    });
  }

  @override
  void dispose() {
    AppUpdateService.instance.pauseBackgroundPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // After Install-unknown-apps settings, continue with the existing APK.
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint('[AppUpdateWrapper] App resumed from background. Continuing update flow...');
      AppUpdateService.instance.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      AppUpdateService.instance.pauseBackgroundPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If running on web, we do not lock the screen for native APK installs
    if (kIsWeb) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: AppUpdateService.instance,
      builder: (context, _) {
        final updateService = AppUpdateService.instance;

        // Strict App Lock: Replace entire route tree with Lock Screen
        if (updateService.isUpdateRequired) {
          return AppUpdateLockScreen(
            config: updateService.currentConfig,
          );
        }

        return widget.child;
      },
    );
  }
}
