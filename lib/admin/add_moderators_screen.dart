import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';

class AddModeratorScreen extends StatefulWidget {
  const AddModeratorScreen({super.key});

  @override
  State<AddModeratorScreen> createState() => _AddModeratorScreenState();
}

class _AddModeratorScreenState extends State<AddModeratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _uidController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'moderator';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final uid = _uidController.text.trim();
      final data = {
        'email': _emailController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'role': _selectedRole,
        'status': 'active',
      };

      try {
        await _firebaseService.setModeratorData(uid, data);
        if (mounted) {
          Navigator.pop(context);
          CustomSnackbar.show(context, 'Successfully created new $_selectedRole.');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Error: ${e.toString()}', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Moderator')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Create the user in Firebase Authentication first, then paste their UID here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _uidController, decoration: _inputDecoration('User UID *', Icons.fingerprint), validator: (v) => v!.isEmpty ? 'UID is required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _firstNameController, decoration: _inputDecoration('First Name *', Icons.person_outline), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _lastNameController, decoration: _inputDecoration('Last Name *', Icons.person_outline), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _emailController, decoration: _inputDecoration('Email Address *', Icons.email_outlined), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: _inputDecoration('Role', Icons.shield_outlined),
              items: ['moderator', 'admin'].map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase()))).toList(),
              onChanged: (value) => setState(() => _selectedRole = value!),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _submit, child: const Text('Create Moderator Profile')),
          ],
        ),
      ),
    );
  }
  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(labelText: label, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), prefixIcon: Icon(icon));
}