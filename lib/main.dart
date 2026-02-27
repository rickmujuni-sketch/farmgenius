import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/localization_service.dart';
import 'services/ai_orchestrator.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/phone_login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/owner_home.dart';
import 'screens/manager_home.dart';
import 'screens/staff_home.dart';
import 'constants.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init(supabaseUrl: SUPABASE_URL, supabaseAnonKey: SUPABASE_ANON_KEY);
  // Initialize AuthService and load any existing session before starting the app
  final authService = AuthService();
  await authService.loadSession();
  // Initialize the AI Orchestrator and run it
  final aiOrchestrator = AIOrchestrator();
  // Run daily orchestration in the background (non-blocking)
  aiOrchestrator.runDailyOrchestration().ignore();
  runApp(FarmGeniusApp(authService: authService, aiOrchestrator: aiOrchestrator));
}

class FarmGeniusApp extends StatelessWidget {
  const FarmGeniusApp({super.key, required this.authService, required this.aiOrchestrator});

  final AuthService authService;
  final AIOrchestrator aiOrchestrator;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      primarySwatch: Colors.green,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5EF),
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    );

        return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => aiOrchestrator),
      ],
      child: Consumer<LocalizationService>(builder: (context, loc, _) {
        return MaterialApp(
          title: 'FarmGenius',
          theme: theme,
          locale: loc.locale,
          supportedLocales: LocalizationService.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (_) => const WelcomeScreen(),
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/phone': (_) => const PhoneLoginScreen(),
            '/otp': (_) => const OtpScreen(),
            '/reset': (_) => const PasswordResetScreen(),
            '/owner': (_) => const OwnerHome(),
            '/manager': (_) => const ManagerHome(),
            '/staff': (_) => const StaffHome(),
          },
        );
      }),
    );
  }
}
