import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/permissions/permission_screen.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

enum AppStatus { checking, needsPermissions, needsOnboarding, ready }

class _SplashWrapperState extends State<SplashWrapper> {
  // Use a Future to hold the status, which prevents rebuilding.
  late Future<AppStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    // Set the future in initState. This runs only once.
    _statusFuture = _checkAppStatus();
  }

  Future<AppStatus> _checkAppStatus() async {
    // This logic runs completely before the first frame is shown.
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
    // FutureBuilder will wait for our check to complete before deciding which screen to show.
    return FutureBuilder<AppStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final status = snapshot.data;
          switch (status) {
            case AppStatus.needsPermissions:
              return const PermissionScreen();
            case AppStatus.needsOnboarding:
              return const OnboardingScreen();
            case AppStatus.ready:
              return const HomeScreen();
            default:
            // This case should not be reached, but it's good practice.
              return const Scaffold(body: Center(child: Text("Error")));
          }
        }

        // While checking, show the splash screen (or a simple loader).
        // The native splash screen will cover this, so it's seamless.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}