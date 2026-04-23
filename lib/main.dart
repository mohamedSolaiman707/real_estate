import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/listings_screen.dart';
import 'screens/property_details_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/performance_screen.dart';
import 'constants/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  String cleanConfig(String key) {
    String value = String.fromEnvironment(key).trim();
    return value.replaceAll(RegExp(r"^['""]+|['"";]"), "");
  }

  final supabaseUrl = cleanConfig('SUPABASE_URL');
  final supabaseAnonKey = cleanConfig('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint('Supabase initialized successfully with URL: $supabaseUrl');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
    }
  } else {
    debugPrint('Critical Error: Supabase keys are missing or empty after cleaning!');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عقارات طنطا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          secondary: AppColors.secondary,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text),
          headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.text),
          bodySmall: TextStyle(fontSize: 14, color: AppColors.text),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/listings': (context) => const ListingsScreen(),
        '/property_details': (context) => const PropertyDetailsScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/performance': (context) => const PerformanceScreen(),
      },
    );
  }
}
