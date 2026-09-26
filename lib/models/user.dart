class User {
  final int? id;
  final String fullName;
  final String email;
  final String avatarUrl;
  final String workspace;
  final DateTime memberSince;
  final String plan;

  User({
    this.id,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.workspace,
    required this.memberSince,
    required this.plan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'workspace': workspace,
      'memberSince': memberSince.toIso8601String(),
      'plan': plan,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      fullName: map['fullName'],
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      workspace: map['workspace'],
      memberSince: DateTime.parse(map['memberSince']),
      plan: map['plan'],
    );
  }

  User copyWith({
    int? id,
    String? fullName,
    String? email,
    String? avatarUrl,
    String? workspace,
    DateTime? memberSince,
    String? plan,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      workspace: workspace ?? this.workspace,
      memberSince: memberSince ?? this.memberSince,
      plan: plan ?? this.plan,
    );
  }
}
