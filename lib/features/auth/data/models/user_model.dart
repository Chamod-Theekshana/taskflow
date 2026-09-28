import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.fullName,
    required super.email,
  });

  factory UserModel.fromMap(Map<String, Object?> map) => UserModel(
    id: map['id'] as String,
    fullName: map['full_name'] as String? ?? '',
    email: map['email'] as String? ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'full_name': fullName,
    'email': email,
  };
}
