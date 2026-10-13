class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String? authProvider;
  final String timezone;
  final String? preferredLanguage;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.authProvider,
    required this.timezone,
    this.preferredLanguage,
    required this.isActive,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? authProvider,
    String? timezone,
    String? preferredLanguage,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authProvider: authProvider ?? this.authProvider,
      timezone: timezone ?? this.timezone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    final str = val.toString().trim();
    if (str.isEmpty) return DateTime.now();
    final asInt = int.tryParse(str);
    if (asInt != null && asInt > 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.tryParse(str) ?? DateTime.now();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName'] as String? ??
          json['full_name'] as String? ??
          json['displayName'] as String? ??
          json['display_name'] as String? ??
          json['name'] as String? ??
          '',
      phone: json['phone'] as String? ??
          json['phoneNumber'] as String? ??
          json['phone_number'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      authProvider: json['authProvider'] as String? ?? json['auth_provider'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      preferredLanguage: json['preferredLanguage'] as String? ??
          json['preferred_language'] as String?,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'authProvider': authProvider,
        'timezone': timezone,
        'preferredLanguage': preferredLanguage,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };
}
