import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/providers/auth_proveider.dart';
import 'package:mahlete_semay_project/services/firebase_service.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';

class CreateInvitationScreen extends StatefulWidget {
  const CreateInvitationScreen({super.key});

  @override
  State<CreateInvitationScreen> createState() => _CreateInvitationScreenState();
}

class _CreateInvitationScreenState extends State<CreateInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _generatedCode;

  Future<void> _createInvitation() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _generatedCode = null;
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        final code = await _firebaseService.createInvitation(
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          adminId: authProvider.currentUser!.uid,
        );
        setState(() => _generatedCode = code);
        CustomSnackbar.show(context, 'Invitation created successfully!');
      } catch (e) {
        CustomSnackbar.show(context, e.toString(), isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Invitation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'First, create the user in the Firebase Authentication console. Then, fill out their details here to generate a one-time invitation code.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(controller: _firstNameController, decoration: _inputDecoration('First Name *', Icons.person_outline), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _lastNameController, decoration: _inputDecoration('Last Name *', Icons.person_outline), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _emailController, decoration: _inputDecoration('Email Address *', Icons.email_outlined), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createInvitation,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Generate Invitation Code'),
                ),
              ],
            ),
          ),
          if (_generatedCode != null) ...[
            const SizedBox(height: 32),
            _buildGeneratedCodeCard(_generatedCode!),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratedCodeCard(String code) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('Share this code with the new moderator:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: GoogleFonts.robotoMono(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    CustomSnackbar.show(context, 'Code copied to clipboard');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('This code is for one-time use.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(labelText: label, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), prefixIcon: Icon(icon));
}