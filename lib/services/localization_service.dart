import 'package:flutter/material.dart';

class LocalizationService extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  static const supportedLocales = [Locale('en'), Locale('sw')];

  void toggleLocale() {
    _locale = _locale.languageCode == 'en' ? const Locale('sw') : const Locale('en');
    notifyListeners();
  }

  String t(String key) {
    final t = _translations[_locale.languageCode] ?? _translations['en']!;
    return t[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'welcome_title': 'Welcome to FarmGenius',
      'login_email': 'Email Login',
      'login_phone': 'Phone Login',
      'email_label': 'Email',
      'password_label': 'Password',
      'login_button': 'Sign In',
      'send_otp': 'Send OTP',
      'verify_otp': 'Verify OTP',
      'reset_password': 'Reset Password',
      'owner_home': 'Owner Dashboard',
      'manager_home': 'Manager Dashboard',
      'staff_home': 'Staff Dashboard',
      'logout': 'Logout',
      'signup_title': 'Sign up',
      'confirm_password_label': 'Confirm Password',
      'create_account': 'Create account',
      'password_mismatch': 'Passwords do not match',
      'signup_success': 'Sign up successful — check email for confirmation',
      'signup_failed': 'Sign up failed',
      'role_label': 'Role',
      'role_owner': 'Owner',
      'role_manager': 'Manager',
      'role_staff': 'Staff',
      'phone_label': 'Phone (+255)',
      'otp_label': 'OTP',
      'verifying_for': 'Verifying for:',
      'otp_verify_failed': 'OTP verification failed',
      'otp_send_failed': 'Could not send OTP',
      'login_failed': 'Login failed',
      'reset_email_sent': 'Email sent',
      'reset_failed': 'Failed',
      'no_internet': 'No internet connection',
    },
    'sw': {
      'welcome_title': 'Karibu FarmGenius',
      'login_email': 'Ingia kwa Barua Pepe',
      'login_phone': 'Ingia kwa Simu',
      'email_label': 'Barua pepe',
      'password_label': 'Nenosiri',
      'login_button': 'Ingia',
      'send_otp': 'Tuma OTP',
      'verify_otp': 'Thibitisha OTP',
      'reset_password': 'Weka upya nenosiri',
      'owner_home': 'Dashibodi ya Mmiliki',
      'manager_home': 'Dashibodi ya Meneja',
      'staff_home': 'Dashibodi ya Mfanyakazi',
      'logout': 'Toka',
      'signup_title': 'Sajili',
      'confirm_password_label': 'Thibitisha Nenosiri',
      'create_account': 'Tengeneza akaunti',
      'password_mismatch': 'Nenosiri hazifani',
      'signup_success': 'Usajili umefanikiwa – angalia barua pepe kwa uthibitisho',
      'signup_failed': 'Usajili umeshindikana',
      'role_label': 'Jukumu',
      'role_owner': 'Mmiliki',
      'role_manager': 'Meneja',
      'role_staff': 'Mfanyakazi',
      'phone_label': 'Simu (+255)',
      'otp_label': 'OTP',
      'verifying_for': 'Inathibitisha kwa:',
      'otp_verify_failed': 'Uthibitisho wa OTP umeshindwa',
      'otp_send_failed': 'Haikuweza kutuma OTP',
      'login_failed': 'Imeshindwa kuingia',
      'reset_email_sent': 'Barua pepe imetumwa',
      'reset_failed': 'Imeshindwa',
      'no_internet': 'Hakuna muunganisho wa intaneti',
    }
  };
}
