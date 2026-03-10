import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  User? _user;
  String? role;
  String? _lastAuthError;

  User? get user => _user;
  String? get lastAuthError => _lastAuthError;

  bool get isLoggedIn => _user != null;

  String _friendlyAuthError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('over_email_send_rate_limit') || normalized.contains('email rate limit exceeded')) {
      return 'Too many signup attempts right now. Please wait a few minutes and try again.';
    }
    if (normalized.contains('email_address_invalid') || normalized.contains('email address') && normalized.contains('invalid')) {
      return 'Invalid email format. Please use a standard address like name@gmail.com.';
    }
    return raw;
  }

  String _normalizeSafeRole(String? value) {
    final roleValue = (value ?? '').toLowerCase().trim();
    if (roleValue == 'owner' ||
        roleValue == 'manager' ||
        roleValue == 'staff' ||
        roleValue == 'doctor' ||
        roleValue == 'supplier') {
      return roleValue;
    }
    return 'staff';
  }

  String? _roleFromAuthMetadata() {
    final user = _user;
    if (user == null) return null;

    final metadataRole = user.userMetadata?['role']?.toString();
    if (metadataRole != null && metadataRole.isNotEmpty) {
      return _normalizeSafeRole(metadataRole);
    }

    final appMetadataRole = user.appMetadata['role']?.toString();
    if (appMetadataRole != null && appMetadataRole.isNotEmpty) {
      return _normalizeSafeRole(appMetadataRole);
    }

    return null;
  }

  Future<String?> _resolveRole({String? fallback}) async {
    if (_user == null) return fallback;

    try {
      final profileResp = await SupabaseService.client
          .from('profiles')
          .select<Map<String, dynamic>>('role')
          .eq('id', _user!.id)
          .maybeSingle();
      final profileRole = profileResp['role'] as String?;
      if (profileRole != null && profileRole.isNotEmpty) {
        return _normalizeSafeRole(profileRole);
      }
    } catch (_) {
      // Non-fatal: fall back to metadata/local cache.
    }

    final metadataRole = _roleFromAuthMetadata();
    if (metadataRole != null && metadataRole.isNotEmpty) {
      return metadataRole;
    }

    if (fallback != null && fallback.isNotEmpty) {
      return _normalizeSafeRole(fallback);
    }

    return 'staff';
  }

  Future<void> _ensureOwnProfile({required String fallbackEmail, required String fallbackRole}) async {
    if (_user == null) return;

    final email = _user!.email ?? fallbackEmail;
    final resolvedRole = (role ?? fallbackRole).toLowerCase();

    try {
      await SupabaseService.client.from('profiles').upsert({
        'id': _user!.id,
        'email': email,
        'role': resolvedRole,
      });
    } catch (_) {
      // Non-fatal: role can still be read from auth metadata/local cache.
    }
  }

  Future<void> loadSession() async {
    final session = SupabaseService.client.auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      role = await _resolveRole(fallback: await _storage.read(key: 'role'));
      if (role != null) {
        await _storage.write(key: 'role', value: role);
      }
    }
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _lastAuthError = null;

    // simple connectivity check so we can fail fast when offline
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      _lastAuthError = 'No internet connection.';
      return false;
    }

    try {
      if (_user != null || SupabaseService.client.auth.currentSession != null) {
        await SupabaseService.client.auth.signOut();
        _user = null;
        role = null;
      }

      final res = await SupabaseService.client.auth.signInWithPassword(email: email, password: password);
      _user = res.user;
      role = await _resolveRole(fallback: await _storage.read(key: 'role'));
      if (role != null) await _storage.write(key: 'role', value: role);
      await _ensureOwnProfile(fallbackEmail: email, fallbackRole: role ?? 'staff');
      notifyListeners();
      return true;
    } catch (e) {
      _lastAuthError = _friendlyAuthError(e);
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String role) async {
    _lastAuthError = null;
    try {
      final normalizedEmail = email.trim();
      const normalizedRole = 'staff';

      if (SupabaseService.client.auth.currentSession != null || _user != null) {
        await SupabaseService.client.auth.signOut();
        _user = null;
        this.role = null;
      }

      final res = await SupabaseService.client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'role': normalizedRole},
      );
      // store role locally immediately so a newly created user doesn't have to
      // wait for a round trip to the profiles table for UI decisions.
      await _storage.write(key: 'role', value: normalizedRole);
      _user = res.user;
      this.role = normalizedRole;
      await _ensureOwnProfile(fallbackEmail: normalizedEmail, fallbackRole: normalizedRole);
      return true;
    } catch (e) {
      _lastAuthError = _friendlyAuthError(e);
      return false;
    }
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
    _user = null;
    role = null;
    await _storage.delete(key: 'role');
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    _lastAuthError = null;
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _lastAuthError = _friendlyAuthError(e);
      return false;
    }
  }

  // Phone login: send OTP (Supabase SMS). Implementation depends on your Supabase
  // SMS setup. This sends an OTP to the phone number.
  Future<bool> sendPhoneOtp(String phone) async {
    _lastAuthError = null;
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      _lastAuthError = 'No internet connection.';
      return false;
    }

    final normalizedPhone = phone.trim();
    final isE164 = RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalizedPhone);
    if (!isE164) {
      _lastAuthError = 'Phone format must be E.164, e.g. +2557XXXXXXXX.';
      return false;
    }

    try {
      await SupabaseService.client.auth.signInWithOtp(phone: normalizedPhone);
      return true;
    } catch (e) {
      _lastAuthError = _friendlyAuthError(e);
      return false;
    }
  }

  // Verify OTP: supabase-dart may support verifying OTP via verifyOTP or signInWithOtp
  Future<bool> verifyPhoneOtp(String phone, String token) async {
    _lastAuthError = null;
    // Supabase's signInWithOtp method handles both sending and verifying
    // codes.  When we call it with a token it attempts to verify and return
    // a session if successful.
    final normalizedPhone = phone.trim();
    final normalizedToken = token.trim();

    if (normalizedToken.isEmpty) {
      _lastAuthError = 'OTP code is required.';
      return false;
    }

    try {
      final res = await SupabaseService.client.auth.verifyOTP(
        phone: normalizedPhone,
        token: normalizedToken,
        type: OtpType.sms,
      );
      _user = res.user;
      role = await _resolveRole(fallback: await _storage.read(key: 'role'));
      if (role != null) await _storage.write(key: 'role', value: role);
      await _ensureOwnProfile(fallbackEmail: normalizedPhone, fallbackRole: role ?? 'staff');
      notifyListeners();
      return true;
    } catch (e) {
      _lastAuthError = e.toString();
      return false;
    }
  }
}
