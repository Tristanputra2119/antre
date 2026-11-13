import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/admin_login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/queue/presentation/admin/admin_dashboard_page.dart';
import '../features/queue/presentation/customer/customer_queue_page.dart';
import '../features/queue/presentation/home_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const home = '/';
  static const queue = '/queue';
  static const takeTicket = '/queue/take';
  static const admin = '/admin';
  static const adminLogin = '/admin/login';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final authChanges = _StreamListenable(auth.authStateChanges);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authChanges,
    redirect: (context, state) async {
      final location = state.matchedLocation;
      final user = auth.currentUser;

      // The login page handles its own brief signed-out moment (non-admin rejection).
      if (user == null) {
        return location == Routes.splash || location == Routes.adminLogin
            ? null
            : Routes.splash;
      }
      if (location == Routes.splash) return Routes.home;

      final isProtected =
          location.startsWith(Routes.admin) && location != Routes.adminLogin;
      if (!isProtected) return null;
      if (user.isAnonymous) return Routes.adminLogin;
      // UX only; every admin RPC re-checks the role on the server.
      final isAdmin = await ref
          .read(isAdminProvider(user.id).future)
          .catchError((_) => false);
      return isAdmin ? null : Routes.adminLogin;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
      GoRoute(
        path: Routes.queue,
        builder: (_, _) => const CustomerQueuePage(),
        routes: [
          GoRoute(path: 'take', builder: (_, _) => const TakeTicketPage()),
        ],
      ),
      GoRoute(
        path: Routes.admin,
        builder: (_, _) => const AdminDashboardPage(),
        routes: [
          GoRoute(path: 'login', builder: (_, _) => const AdminLoginPage()),
        ],
      ),
    ],
  );
});

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
