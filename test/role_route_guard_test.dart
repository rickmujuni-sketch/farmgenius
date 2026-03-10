import 'package:farmgenius/main.dart';
import 'package:farmgenius/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({required bool loggedIn, String? initialRole}) : _loggedIn = loggedIn {
    role = initialRole;
  }

  final bool _loggedIn;

  @override
  bool get isLoggedIn => _loggedIn;
}

Widget _buildApp(AuthService auth, {required String initialRoute}) {
  return ChangeNotifierProvider<AuthService>.value(
    value: auth,
    child: MaterialApp(
      initialRoute: initialRoute,
      routes: {
        '/owner': (_) => const RoleRouteGuard(
              requiredRole: 'owner',
              child: Scaffold(body: Text('OWNER_SCREEN')),
            ),
        '/manager': (_) => const Scaffold(body: Text('MANAGER_SCREEN')),
        '/staff': (_) => const Scaffold(body: Text('STAFF_SCREEN')),
        '/login': (_) => const Scaffold(body: Text('LOGIN_SCREEN')),
      },
    ),
  );
}

void main() {
  testWidgets('manager cannot access owner route', (tester) async {
    final auth = _FakeAuthService(loggedIn: true, initialRole: 'manager');

    await tester.pumpWidget(_buildApp(auth, initialRoute: '/owner'));
    await tester.pumpAndSettle();

    expect(find.text('OWNER_SCREEN'), findsNothing);
    expect(find.text('MANAGER_SCREEN'), findsOneWidget);
  });

  testWidgets('staff cannot access owner route', (tester) async {
    final auth = _FakeAuthService(loggedIn: true, initialRole: 'staff');

    await tester.pumpWidget(_buildApp(auth, initialRoute: '/owner'));
    await tester.pumpAndSettle();

    expect(find.text('OWNER_SCREEN'), findsNothing);
    expect(find.text('STAFF_SCREEN'), findsOneWidget);
  });

  testWidgets('unauthenticated user is redirected to login', (tester) async {
    final auth = _FakeAuthService(loggedIn: false, initialRole: null);

    await tester.pumpWidget(_buildApp(auth, initialRoute: '/owner'));
    await tester.pumpAndSettle();

    expect(find.text('OWNER_SCREEN'), findsNothing);
    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
  });
}
