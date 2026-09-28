/// An expected, user-facing error (wrong password, duplicate e-mail...).
///
/// `toString()` is just the message so it can go straight into a SnackBar.
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

/// Turns anything that was thrown into text that is fine to show the user.
String describeError(Object error) {
  if (error is Failure) return error.message;
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
