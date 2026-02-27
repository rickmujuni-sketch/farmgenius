import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);

    // if session already exists, redirect immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.isLoggedIn) {
        final role = auth.role ?? 'staff';
        if (role == 'owner') {
          Navigator.pushReplacementNamed(context, '/owner');
        } else if (role == 'manager') {
          Navigator.pushReplacementNamed(context, '/manager');
        } else {
          Navigator.pushReplacementNamed(context, '/staff');
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('welcome_title')),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: Text(loc.t('login_email')),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D4C41)),
              onPressed: () => Navigator.pushNamed(context, '/phone'),
              child: Text(loc.t('login_phone')),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('English'),
                Switch(
                  value: loc.locale.languageCode == 'sw',
                  onChanged: (_) => loc.toggleLocale(),
                ),
                const Text('Kiswahili'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
