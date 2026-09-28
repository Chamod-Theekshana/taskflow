import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(dbProviderProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authLocalDataSourceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

/// The signed-in user (`null` when signed out).
///
/// The provider is only in the *loading* state while the stored session is
/// being restored at start-up. Sign-in, sign-up and sign-out deliberately do
/// **not** switch it back to loading: the router treats "loading" as "show
/// the splash screen", so doing that used to unmount the login form mid
/// request (hiding any error) and leave the app stuck on the splash screen.
/// Failures are thrown to the caller instead, which shows them in the form.
final authProvider = AsyncNotifierProvider<Auth, User?>(Auth.new);

/// True only while the saved session is being restored at start-up — the
/// one time the app should sit on the splash screen.
bool isRestoringSession(AsyncValue<User?> auth) =>
    auth.isLoading && !auth.hasValue && !auth.hasError;

class Auth extends AsyncNotifier<User?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Upper bound for restoring the saved session. Reading one row from the
  /// local database takes milliseconds; if it ever takes longer than this,
  /// something is wrong and the user is better off on the login screen than
  /// on a splash screen that never ends.
  static const _restoreTimeout = Duration(seconds: 10);

  @override
  Future<User?> build() async {
    try {
      final user = await GetCurrentUserUseCase(
        _repository,
      )().timeout(_restoreTimeout);
      debugPrint(
        'TaskFlow: session restored '
        '(${user == null ? 'signed out' : 'signed in'})',
      );
      return user;
    } catch (error, stackTrace) {
      // Never leave the app stuck on the splash screen: a session that
      // cannot be restored is treated as "signed out".
      debugPrint(
        'TaskFlow: could not restore the saved session: $error\n$stackTrace',
      );
      return null;
    }
  }

  Future<User> login(
    String email,
    String password, {
    bool rememberSession = true,
  }) async {
    final user = await LoginUseCase(
      _repository,
    )(email, password, rememberSession: rememberSession);
    if (ref.mounted) state = AsyncData(user);
    return user;
  }

  Future<User> signup(String fullName, String email, String password) async {
    final user = await SignupUseCase(
      _repository,
    )(fullName: fullName, email: email, password: password);
    if (ref.mounted) state = AsyncData(user);
    return user;
  }

  Future<void> updateFullName(String fullName) async {
    final current = state.value;
    if (current == null) return;
    final updated = await UpdateProfileUseCase(
      _repository,
    )(current.id, fullName);
    if (ref.mounted) state = AsyncData(updated);
  }

  Future<void> logout() async {
    await LogoutUseCase(_repository)();
    if (ref.mounted) state = const AsyncData(null);
  }
}
