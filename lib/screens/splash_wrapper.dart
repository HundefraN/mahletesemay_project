import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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

