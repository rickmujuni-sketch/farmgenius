// Supabase project values. These can be overridden at build time via
// --dart-define so that secrets don’t live in source control.
// Example: flutter run -d chrome --dart-define=SUPABASE_URL=https://... \
//   --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
const String SUPABASE_URL = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://hrtlaxxzsewcnjvthsct.supabase.co',
);
const String SUPABASE_ANON_KEY = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhydGxheHh6c2V3Y25qdnRoc2N0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5OTQ2MjUsImV4cCI6MjA4NzU3MDYyNX0.Ofo56ccknANvgeIcgqVXhhqmo2jAJmrb_fQQqAH07dY',
);

// App color palette (high contrast for outdoor use)
const int APP_GREEN = 0xFF2E7D32; // deep green
const int APP_BROWN = 0xFF6D4C41; // earth brown
const int APP_BEIGE = 0xFFF5F5EF;
