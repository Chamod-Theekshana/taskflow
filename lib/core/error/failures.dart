/// Base type for expected, user-facing failures (wrong password, duplicate
/// e-mail, ...).
///
/// `toString()` returns only the message so it can be shown directly in a
/// SnackBar without the noisy `Exception:` prefix.
class Failure implements Exception {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// Turns any thrown object into a message that is safe to show to the user.
String describeError(Object error) {
  if (error is Failure) return error.message;
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
