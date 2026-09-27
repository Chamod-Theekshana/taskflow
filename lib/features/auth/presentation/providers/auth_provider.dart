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

final authProvider = AsyncNotifierProvider<Auth, User?>(Auth.new);

class Auth extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final useCase = GetCurrentUserUseCase(ref.read(authRepositoryProvider));
    return await useCase();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = LoginUseCase(ref.read(authRepositoryProvider));
      return await useCase(email, password);
    });
  }

  Future<void> signup(String fullName, String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = SignupUseCase(ref.read(authRepositoryProvider));
      return await useCase(fullName: fullName, email: email, password: password);
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = LogoutUseCase(ref.read(authRepositoryProvider));
      await useCase();
      return null;
    });
  }
}
