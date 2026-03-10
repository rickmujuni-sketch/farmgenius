import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+255');
  bool _loading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('login_phone')), backgroundColor: const Color(0xFF6D4C41)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: loc.t('phone_label'))),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D4C41)),
              onPressed: _loading
                  ? null
                  : () async {
                      final net = await Connectivity().checkConnectivity();
                      if (net == ConnectivityResult.none) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('no_internet'))));
                        return;
                      }
                      setState(() => _loading = true);
                      final ok = await auth.sendPhoneOtp(_phoneCtrl.text.trim());
                      setState(() {
                        _loading = false;
                        _errorMessage = ok ? null : auth.lastAuthError;
                      });
                      if (ok) {
                        Navigator.pushNamed(context, '/otp', arguments: {'phone': _phoneCtrl.text.trim()});
                      } else {
                        final details = auth.lastAuthError;
                        final message = details == null || details.isEmpty
                            ? loc.t('otp_send_failed')
                            : '${loc.t('otp_send_failed')}\n$details';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
              child: _loading ? const CircularProgressIndicator() : Text(loc.t('send_otp')),
            ),
            if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
