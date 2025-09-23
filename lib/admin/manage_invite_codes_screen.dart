import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:nanoid/nanoid.dart';
import 'package:timeago/timeago.dart' as timeago;

class ManageInviteCodesScreen extends StatefulWidget {
  const ManageInviteCodesScreen({super.key});

  @override
  State<ManageInviteCodesScreen> createState() => _ManageInviteCodesScreenState();
}

class _ManageInviteCodesScreenState extends State<ManageInviteCodesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _generateCode() async {
    setState(() => _isLoading = true);
    try {
      final code = nanoid(10);
      await _firestore.collection('inviteCodes').doc(code).set({
        'createdAt': FieldValue.serverTimestamp(),
        'used': false,
        'usedBy': null,
      });
      if (mounted) {
        CustomSnackbar.show(context, 'New invite code created!');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 'Failed to create code.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Invite Codes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('inviteCodes').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final codes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: codes.length,
            itemBuilder: (context, index) {
              final doc = codes[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isUsed = data['used'] ?? false;
              final Timestamp? createdAt = data['createdAt'];

              return ListTile(
                leading: Icon(isUsed ? Icons.check_circle : Icons.vpn_key, color: isUsed ? Colors.grey : Theme.of(context).colorScheme.primary),
                title: Text(doc.id, style: TextStyle(fontWeight: FontWeight.bold, color: isUsed ? Colors.grey : null)),
                subtitle: Text(createdAt != null ? 'Created ${timeago.format(createdAt.toDate())}' : 'Creating...'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: doc.id));
                    CustomSnackbar.show(context, 'Code copied to clipboard!');
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _generateCode,
        label: const Text('Generate New Code'),
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
      ),
    );
  }
}