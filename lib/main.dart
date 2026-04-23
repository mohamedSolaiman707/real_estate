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
  
  // قراءة القيم وتنظيفها من أي فواصل منقوطة أو مسافات زائدة
  String supabaseUrl = const String.fromEnvironment('SUPABASE_URL').trim();
  String supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY').trim();

  // إزالة الفصلة المنقوطة لو وجدت في النهاية (بسبب أخطاء الإدخال)
  if (supabaseUrl.endsWith(';')) {
    supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - 1);
  }
  if (supabaseAnonKey.endsWith(';')) {
    supabaseAnonKey = supabaseAnonKey.substring(0, supabaseAnonKey.length - 1);
  }

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
    }
  } else {
    debugPrint('Critical Error: Supabase keys are missing!');
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
