import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('login_email')), backgroundColor: const Color(0xFF2E7D32)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: loc.t('email_label'))),
            const SizedBox(height: 8),
            TextField(controller: _passCtrl, decoration: InputDecoration(labelText: loc.t('password_label')), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      final net = await Connectivity().checkConnectivity();
                      if (net == ConnectivityResult.none) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('no_internet'))));
                        return;
                      }
                      setState(() => _loading = true);
                      final ok = await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
                      setState(() => _loading = false);
                      if (ok) {
                        final role = auth.role ?? 'staff';
                        if (role == 'owner') {
                          Navigator.pushReplacementNamed(context, '/owner');
                        } else if (role == 'manager') Navigator.pushReplacementNamed(context, '/manager');
                        else Navigator.pushReplacementNamed(context, '/staff');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('login_failed'))));
                      }
                    },
              child: _loading ? const CircularProgressIndicator() : Text(loc.t('login_button')),
            ),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/reset'), child: Text(loc.t('reset_password'))),
          ],
        ),
      ),
    );
  }
}
