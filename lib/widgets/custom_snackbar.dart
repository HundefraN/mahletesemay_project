import 'package:flutter/material.dart';
import '../main.dart';

class CustomSnackbar {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final messenger = scaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final backgroundColor = isError
        ? const Color(0xFFD32F2F)
        : (isDark ? const Color(0xFF1B3B6F) : const Color(0xFF0A1E3F));

    final iconColor = isError
        ? Colors.white
        : (isDark ? theme.colorScheme.primary : Colors.white);

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.fixed,
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      duration: const Duration(seconds: 3),
    );

    messenger.showSnackBar(snackBar);
  }
}