import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _role = 'staff';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('signup_title')), backgroundColor: const Color(0xFF2E7D32)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: loc.t('email_label'))),
            const SizedBox(height: 8),
            TextField(controller: _passCtrl, decoration: InputDecoration(labelText: loc.t('password_label')), obscureText: true),
            const SizedBox(height: 8),
            TextField(controller: _confirmCtrl, decoration: InputDecoration(labelText: loc.t('confirm_password_label')), obscureText: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: [
                DropdownMenuItem(value: 'owner', child: Text(loc.t('role_owner'))),
                DropdownMenuItem(value: 'manager', child: Text(loc.t('role_manager'))),
                DropdownMenuItem(value: 'staff', child: Text(loc.t('role_staff'))),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'staff'),
              decoration: InputDecoration(labelText: loc.t('role_label')),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: _loading
                  ? null
                  : () async {
                      if (_passCtrl.text != _confirmCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('password_mismatch'))));
                        return;
                      }
                      setState(() => _loading = true);
                      final ok = await auth.signUpWithEmail(_emailCtrl.text.trim(), _passCtrl.text, _role);
                      setState(() => _loading = false);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('signup_success'))));
                        Navigator.pushReplacementNamed(context, '/login');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('signup_failed'))));
                      }
                    },
              child: _loading ? const CircularProgressIndicator() : Text(loc.t('create_account')),
            ),
          ],
        ),
      ),
    );
  }
}
