import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors.dart';
import '../../../core/supabase_client.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Cached per user id; the server re-checks the role on every admin RPC anyway.
final isAdminProvider = FutureProvider.family<bool, String>(
  (ref, userId) => ref.watch(authRepositoryProvider).isAdmin(),
);

/// Splash bootstrap: make sure there is a (possibly anonymous) session.
/// Auto-disposed so it runs again after a logout.
final sessionBootstrapProvider = FutureProvider.autoDispose<void>(
  (ref) => ref.watch(authRepositoryProvider).ensureSession(),
);

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> ensureSession() async {
    if (_auth.currentSession == null) await _auth.signInAnonymously();
  }

  Future<bool> isAdmin() async => await _client.rpc('is_admin') as bool;

  /// Signs in and verifies the admin role. A non-admin is swapped back to a
  /// fresh anonymous session and [AppException] is thrown.
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
    if (await isAdmin()) return;

    await _auth.signOut();
    await _auth.signInAnonymously();
    throw const AppException('Akun ini bukan admin.');
  }

  /// The router sends the user to the splash, which creates a new anonymous session.
  Future<void> signOut() => _auth.signOut();
}
