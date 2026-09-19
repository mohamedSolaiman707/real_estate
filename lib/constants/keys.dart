class Keys {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gkxjatpqwxcbrlkiltms.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdreGphdHBxd3hjYnJsa2lsdG1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5MDUzMzEsImV4cCI6MjA5MjQ4MTMzMX0.51DHRB6PQX3t7f4U78qNLAiQtD2LAYScFTAk-zK7RRE',
  );
}
