import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  User? _user;
  String? role;

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  Future<void> loadSession() async {
    final session = SupabaseService.client.auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      role = _user!.userMetadata?['role'] ?? await _storage.read(key: 'role');
    }
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    // if we already have a session and the user object, just return true
    if (_user != null) return true;

    // simple connectivity check so we can fail fast when offline
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      return false;
    }

    try {
      final res = await SupabaseService.client.auth.signInWithPassword(email: email, password: password);
      _user = res.user;
      role = _user?.userMetadata?['role'];
      if (role == null && _user != null) {
        // fall back to our own profiles table
        final profileResp = await SupabaseService.client
            .from('profiles')
            .select('role')
            .eq('id', _user!.id)
            .maybeSingle()
            .execute();
        if (profileResp.error == null && profileResp.data != null) {
          role = (profileResp.data as Map)['role'];
        }
      }
      if (role != null) await _storage.write(key: 'role', value: role);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String role) async {
    try {
      final res = await SupabaseService.client.auth.signUp(email: email, password: password);
      // store role locally immediately so a newly created user doesn't have to
      // wait for a round trip to the profiles table for UI decisions.
      await _storage.write(key: 'role', value: role);
      // persist to a "profiles" table where we keep additional fields.
      if (res.user != null) {
        await SupabaseService.client.from('profiles').insert({
          'id': res.user!.id,
          'email': email,
          'role': role,
        }).execute();
      }
      return true;
    } catch (e) {
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
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Phone login: send OTP (Supabase SMS). Implementation depends on your Supabase
  // SMS setup. This sends an OTP to the phone number.
  Future<bool> sendPhoneOtp(String phone) async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return false;

    try {
      await SupabaseService.client.auth.signInWithOtp(phone: phone);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Verify OTP: supabase-dart may support verifying OTP via verifyOTP or signInWithOtp
  Future<bool> verifyPhoneOtp(String phone, String token) async {
    // Supabase's signInWithOtp method handles both sending and verifying
    // codes.  When we call it with a token it attempts to verify and return
    // a session if successful.
    try {
      final res = await SupabaseService.client.auth.signInWithOtp(
        phone: phone,
        token: token,
      );
      _user = res.user;
      role = _user?.userMetadata?['role'];
      if (role == null && _user != null) {
        final profileResp = await SupabaseService.client
            .from('profiles')
            .select('role')
            .eq('id', _user!.id)
            .maybeSingle()
            .execute();
        if (profileResp.error == null && profileResp.data != null) {
          role = (profileResp.data as Map)['role'];
        }
      }
      if (role != null) await _storage.write(key: 'role', value: role);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
