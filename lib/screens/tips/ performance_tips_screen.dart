import 'package:flutter/material.dart';
import '../../models/performance_tip_model.dart';
import '../../utils/constants.dart';

class PerformanceTipsScreen extends StatelessWidget {
  const PerformanceTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage Performance Tips'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        itemCount: demoPerformanceTips.length,
        itemBuilder: (context, index) {
          final tip = demoPerformanceTips[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                tip.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(tip.content),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(tip.title),
                    content: Text(tip.content),
                    actions: [
                      TextButton(
                        child: const Text('Got it!'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      )
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}