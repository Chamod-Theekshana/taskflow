import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(databaseProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authLocalDataSourceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

/// The signed-in user, or null.
///
/// Only the start-up session restore puts this in the loading state. Sign in,
/// sign up and sign out update it directly and throw failures back to the
/// form that called them.
final authProvider = AsyncNotifierProvider<Auth, User?>(Auth.new);

/// True only while the saved session is being read at start-up.
bool isRestoringSession(AsyncValue<User?> auth) =>
    auth.isLoading && !auth.hasValue && !auth.hasError;

class Auth extends AsyncNotifier<User?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<User?> build() async {
    try {
      return await GetCurrentUserUseCase(
        _repository,
      )().timeout(const Duration(seconds: 10));
    } catch (error) {
      // A session that can't be restored just means "signed out".
      debugPrint('Could not restore the saved session: $error');
      return null;
    }
  }

  Future<User> login(
    String email,
    String password, {
    bool rememberSession = true,
  }) async {
    final user = await LoginUseCase(_repository)(
      email,
      password,
      rememberSession: rememberSession,
    );
    if (ref.mounted) state = AsyncData(user);
    return user;
  }

  Future<User> signup(String fullName, String email, String password) async {
    final user = await SignupUseCase(_repository)(
      fullName: fullName,
      email: email,
      password: password,
    );
    if (ref.mounted) state = AsyncData(user);
    return user;
  }

  Future<void> updateFullName(String fullName) async {
    final current = state.value;
    if (current == null) return;
    final updated = await UpdateProfileUseCase(_repository)(
      current.id,
      fullName,
    );
    if (ref.mounted) state = AsyncData(updated);
  }

  Future<void> logout() async {
    await LogoutUseCase(_repository)();
    if (ref.mounted) state = const AsyncData(null);
  }
}
