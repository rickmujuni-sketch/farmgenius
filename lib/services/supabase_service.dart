import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> init({required String supabaseUrl, required String supabaseAnonKey}) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
