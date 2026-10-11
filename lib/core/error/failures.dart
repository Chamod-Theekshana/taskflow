import 'package:dio/dio.dart';

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

/// The server could not be reached (offline, timeout, DNS...).
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = "Can't reach the server. Check your connection.",
  ]);
}

/// The server answered with an error (RFC 9457 problem details).
class ApiFailure extends Failure {
  final int status;
  final String code;

  const ApiFailure(super.message, {required this.status, required this.code});

  bool get isUnauthorized => status == 401;
}

/// Turns anything that was thrown into text that is fine to show the user.
String describeError(Object error) {
  if (error is Failure) return error.message;
  if (error is DioException) {
    final inner = error.error;
    if (inner is Failure) return inner.message;
    return const NetworkFailure().message;
  }
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
