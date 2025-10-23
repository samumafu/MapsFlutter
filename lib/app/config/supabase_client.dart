import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://jjgetpvtnzlorpfoyxtr.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqZ2V0cHZ0bnpsb3JwZm95eHRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExNjk2MjcsImV4cCI6MjA3Njc0NTYyN30.ace5Kpdo3Mrph-jxdcOnD1cVFJ3KZNoIddEGjWeVLXc';

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
