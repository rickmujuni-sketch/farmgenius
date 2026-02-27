import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('owner_home')),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(onPressed: () async { await auth.signOut(); Navigator.pushReplacementNamed(context, '/'); }, icon: const Icon(Icons.logout))
        ],
      ),
      body: const Center(child: Text('Owner - full access')),
    );
  }
}
