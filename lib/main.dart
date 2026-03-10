import 'package:flutter/gestures.dart';
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
import 'screens/owner_home_hub.dart';
import 'screens/manager_home.dart';
import 'screens/staff_home_hub.dart';
import 'constants.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const String _forceHomeRoute = String.fromEnvironment('FORCE_HOME_ROUTE', defaultValue: '');

String _resolveInitialRoute() {
  if (_forceHomeRoute == 'owner') return '/owner';
  if (_forceHomeRoute == 'manager') return '/manager';
  if (_forceHomeRoute == 'staff') return '/staff';
  return '/';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SUPABASE_URL.trim().isEmpty || SUPABASE_ANON_KEY.trim().isEmpty) {
    throw StateError(
      'Supabase configuration is missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
    );
  }
  await SupabaseService.init(supabaseUrl: SUPABASE_URL, supabaseAnonKey: SUPABASE_ANON_KEY);
  // Initialize AuthService and load any existing session before starting the app
  final authService = AuthService();
  await authService.loadSession();
  // Initialize the AI Orchestrator and run it
  final aiOrchestrator = AIOrchestrator();
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
          scrollBehavior: const _FarmGeniusScrollBehavior(),
          locale: loc.locale,
          supportedLocales: LocalizationService.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          initialRoute: _resolveInitialRoute(),
          routes: {
            '/': (_) => const WelcomeScreen(),
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/phone': (_) => const PhoneLoginScreen(),
            '/otp': (_) => const OtpScreen(),
            '/reset': (_) => const PasswordResetScreen(),
            '/owner': (_) => const RoleRouteGuard(requiredRole: 'owner', child: OwnerHome()),
            '/manager': (_) => const RoleRouteGuard(requiredRole: 'manager', child: ManagerHome()),
            '/staff': (_) => const RoleRouteGuard(requiredRole: 'staff', child: StaffHome()),
          },
        );
      }),
    );
  }
}

class RoleRouteGuard extends StatelessWidget {
  const RoleRouteGuard({super.key, required this.requiredRole, required this.child});

  final String requiredRole;
  final Widget child;

  String _homeRouteForRole(String? role) {
    if (role == 'owner') return '/owner';
    if (role == 'manager') return '/manager';
    return '/staff';
  }

  bool _isRoleAllowedForRoute(String currentRole) {
    if (requiredRole == 'staff') {
      return currentRole == 'staff' || currentRole == 'doctor' || currentRole == 'supplier';
    }
    return currentRole == requiredRole;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentRole = (auth.role ?? 'staff').toLowerCase();
    if (!_isRoleAllowedForRoute(currentRole)) {
      final redirectRoute = _homeRouteForRole(currentRole);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, redirectRoute);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return child;
  }
}

class _FarmGeniusScrollBehavior extends MaterialScrollBehavior {
  const _FarmGeniusScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
