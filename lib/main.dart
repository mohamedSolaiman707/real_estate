import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/listings_screen.dart';
import 'screens/property_details_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/performance_screen.dart';
import 'constants/colors.dart';
import 'constants/keys.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = Keys.supabaseUrl;
  const supabaseAnonKey = Keys.supabaseAnonKey;

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شركة الحمد للعقارات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceSubtle,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          bodyLarge: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ),
      // ─── Smart Session Gate ───────────────────────────────────────────────────
      // فحص الجلسة عند الفتح: لو في session محفوظة يروح للداشبورد مباشرة
      initialRoute: '/',
      routes: {
        '/': (context) => const _SessionGate(),
        '/home': (context) => const HomeScreen(),
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

/// ─── Session Gate Widget ────────────────────────────────────────────────────
/// يفحص عند فتح التطبيق هل في يوزر مسجل دخوله مسبقاً أم لا.
/// - لو في session → يوجه للـ Dashboard مباشرة (بدون ما يطلب منه تسجيل دخول تاني)
/// - لو مفيش session → يوجه للصفحة الرئيسية العادية للزوار
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // انتظر لحظة عشان الـ UI يتحمل
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // في session محفوظة → روح للداشبورد مباشرة
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // لو مفيش session → يروح للصفحة الرئيسية العادية (HomeScreen)
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // شاشة تحميل بسيطة أثناء الفحص
    return const Scaffold(
      backgroundColor: AppColors.slateDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_center_rounded, color: Colors.white, size: 56),
            SizedBox(height: 16),
            Text(
              'شركة الحمد للعقارات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'جاري التحقق من الجلسة...',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
          ],
        ),
      ),
    );
  }
}
