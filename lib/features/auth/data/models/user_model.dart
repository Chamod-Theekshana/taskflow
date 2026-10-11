import '../../domain/entities/user.dart';

/// API / cache JSON <-> [User].
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.fullName,
    required super.email,
    super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'createdAt': createdAt?.toUtc().toIso8601String(),
  };
}
