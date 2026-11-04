import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class FinanzasApp extends ConsumerWidget {
  const FinanzasApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Finanzas Móvil',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: financeTheme(ref.watch(themeProvider), Brightness.light),
        darkTheme: financeTheme(ref.watch(themeProvider), Brightness.dark),
        routerConfig: ref.watch(routerProvider),
      );
}
