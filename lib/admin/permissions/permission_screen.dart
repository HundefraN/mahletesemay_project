import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mahlete_semay_project/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // FIX: Add a flag to prevent multiple requests
  bool _isRequestingPermission = false;

  final List<_PermissionInfo> _permissions = [
    _PermissionInfo(
      permission: Permission.notification,
      icon: Icons.notifications_active_outlined,
      title: 'Enable Notifications',
      description:
      'Get friendly reminders for your daily vocal workouts to stay on track with your training.',
    ),
    _PermissionInfo(
      permission: Permission.microphone,
      icon: Icons.mic_none_rounded,
      title: 'Microphone Access',
      description:
      'Needed for the Vocal Range Finder to analyze your pitch and help you discover your voice type.',
    ),
    _PermissionInfo(
      permission: Permission.photos,
      icon: Icons.photo_library_outlined,
      title: 'Photo Library Access',
      description:
      'Allows you to select beautiful images for artist profiles and album covers in the admin panel.',
    ),
  ];

  Future<void> _requestCurrentPermission() async {
    // FIX: Guard against multiple taps
    if (_isRequestingPermission) return;

    setState(() => _isRequestingPermission = true);

    try {
      final status = await _permissions[_currentPage].permission.request();

      if (status.isPermanentlyDenied) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: Text(
                'You have permanently denied the ${_permissions[_currentPage].title} permission. Please go to your device settings to enable it.'),
            actions: [
              TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context)),
              FilledButton(
                  child: const Text('Open Settings'),
                  onPressed: () => openAppSettings()),
            ],
          ),
        );
      }

      if (_currentPage < _permissions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        await _markPermissionsAsCompleted();
      }
    } finally {
      // FIX: Ensure the flag is always reset, even if there's an error
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }

  Future<void> _markPermissionsAsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_completed', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _permissions.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final item = _permissions[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon,
                            size: 100, color: theme.colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(item.title,
                            style: theme.textTheme.headlineLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(item.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5, color: Colors.grey.shade600),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      // FIX: Disable the button while a request is running
                      onPressed: _isRequestingPermission ? null : _requestCurrentPermission,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isRequestingPermission
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Allow Access'),
                    ),
                  ),
                  TextButton(
                    onPressed: _isRequestingPermission ? null : _markPermissionsAsCompleted,
                    child: const Text('Ask Me Later'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionInfo {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;

  _PermissionInfo({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
  });
}