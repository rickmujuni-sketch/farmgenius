import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../legacy_content.dart';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: SvgPicture.asset(
                'assets/branding/farmgenius_logo_mark.svg',
                height: 120,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              LegacyContent.signboard,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 12),
            Text(
              LegacyContent.websiteHero,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87, height: 1.35),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                LegacyContent.dedication,
                style: const TextStyle(fontSize: 13.5, height: 1.35),
              ),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: Text(loc.t('create_account')),
            ),
            const SizedBox(height: 14),
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
