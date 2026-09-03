import 'user_role.dart';

/// 앱 사용자 모델
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.department,
    this.position,
    this.avatarUrl,
    this.role = UserRole.researcher,
    this.isAdmin = false,
    this.defaultZoomLink,
    this.defaultZoomId,
    this.defaultZoomPassword,
  });

  final String id;
  final String email;
  final String fullName;
  final String? department;
  final String? position;
  final String? avatarUrl;
  final UserRole role;
  final bool isAdmin;
  final String? defaultZoomLink;
  final String? defaultZoomId;
  final String? defaultZoomPassword;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      department: json['department'] as String?,
      position: json['position'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'researcher'),
      isAdmin: json['is_admin'] as bool? ?? false,
      defaultZoomLink: json['default_zoom_link'] as String?,
      defaultZoomId: json['default_zoom_id'] as String?,
      defaultZoomPassword: json['default_zoom_password'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'department': department,
      'position': position,
      'avatar_url': avatarUrl,
      'role': role.name,
      'is_admin': isAdmin,
      'default_zoom_link': defaultZoomLink,
      'default_zoom_id': defaultZoomId,
      'default_zoom_password': defaultZoomPassword,
    };
  }

  String get greeting {
    switch (role) {
      case UserRole.pi:
        return '$fullName 책임연구원님, 환영합니다';
      case UserRole.researcher:
        return '$fullName 연구원님, 환영합니다';
      case UserRole.external_:
        return '$fullName님, 환영합니다';
    }
  }

  /// 편집/삭제 권한: 인증된 사용자 모두 가능
  bool canEdit(String? ownerId) => true;
  bool canDelete(String? ownerId) => true;

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? department,
    String? position,
    String? avatarUrl,
    UserRole? role,
    bool? isAdmin,
    String? Function()? defaultZoomLink,
    String? Function()? defaultZoomId,
    String? Function()? defaultZoomPassword,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      department: department ?? this.department,
      position: position ?? this.position,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      defaultZoomLink: defaultZoomLink != null
          ? defaultZoomLink()
          : this.defaultZoomLink,
      defaultZoomId: defaultZoomId != null
          ? defaultZoomId()
          : this.defaultZoomId,
      defaultZoomPassword: defaultZoomPassword != null
          ? defaultZoomPassword()
          : this.defaultZoomPassword,
    );
  }
}
