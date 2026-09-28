import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/auth/domain/entities/user.dart';
import 'package:taskflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:taskflow/features/auth/presentation/providers/auth_provider.dart';

/// Repository whose session restore fails, like a broken database would.
class _FailingRestoreRepository implements AuthRepository {
  @override
  Future<User?> getCurrentUser() async => throw Exception('database broken');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('isRestoringSession', () {
    test('is true only before the first result arrives', () {
      expect(isRestoringSession(const AsyncLoading<User?>()), isTrue);
      expect(isRestoringSession(const AsyncData<User?>(null)), isFalse);
      expect(
        isRestoringSession(
          AsyncError<User?>(Exception('boom'), StackTrace.empty),
        ),
        isFalse,
      );
    });
  });

  test('a failed session restore ends as "signed out", not loading', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FailingRestoreRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(authProvider.future), isNull);
    expect(isRestoringSession(container.read(authProvider)), isFalse);
  });
}
