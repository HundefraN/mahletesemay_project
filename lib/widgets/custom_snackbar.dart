import 'package:flutter/material.dart';

class CustomSnackbar {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final theme = Theme.of(context);
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(12),
      elevation: 4,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}