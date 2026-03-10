import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String phone = '';
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    phone = args?['phone'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('verify_otp')), backgroundColor: const Color(0xFF6D4C41)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('${loc.t('verifying_for')} $phone'),
            TextField(controller: _otpCtrl, decoration: InputDecoration(labelText: loc.t('otp_label'))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final ok = await auth.verifyPhoneOtp(phone, _otpCtrl.text.trim());
                      setState(() {
                        _loading = false;
                        _errorMessage = ok ? null : auth.lastAuthError;
                      });
                      if (ok) {
                        final role = auth.role ?? 'staff';
                        if (role == 'owner') {
                          Navigator.pushReplacementNamed(context, '/owner');
                        } else if (role == 'manager') Navigator.pushReplacementNamed(context, '/manager');
                        else Navigator.pushReplacementNamed(context, '/staff');
                      } else {
                        final details = auth.lastAuthError;
                        final message = details == null || details.isEmpty
                            ? loc.t('otp_verify_failed')
                            : '${loc.t('otp_verify_failed')}\n$details';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
              child: _loading ? const CircularProgressIndicator() : Text(loc.t('verify_otp')),
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
