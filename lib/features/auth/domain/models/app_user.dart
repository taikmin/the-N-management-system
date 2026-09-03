import 'user_role.dart';

/// 앱 사용자 모델
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = UserRole.staff,
    this.isAdmin = false,
    this.departmentId,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;

  /// 시스템 관리자 여부 (앱 자체 운영자, role과 별도의 축)
  final bool isAdmin;

  final String? departmentId;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'staff'),
      isAdmin: json['is_admin'] as bool? ?? false,
      departmentId: json['department_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role.name,
      'is_admin': isAdmin,
      'department_id': departmentId,
    };
  }

  /// 환영 문구
  String get greeting {
    if (isAdmin && role == UserRole.staff) {
      return '$fullName 관리자님, 환영합니다';
    }
    switch (role) {
      case UserRole.ceo:
        return '$fullName 대표님, 환영합니다';
      case UserRole.manager:
        return '$fullName 관리자님, 환영합니다';
      case UserRole.staff:
        return '$fullName님, 환영합니다';
    }
  }

  /// 역할 표시 라벨 (배지 등에 사용)
  String get roleDisplay {
    if (isAdmin) {
      return role == UserRole.staff ? 'Admin' : 'Admin · ${role.label}';
    }
    return role.label;
  }

  // ─── 권한 헬퍼 (UI에서 사용) ───

  /// 시스템 슈퍼유저 (Admin 전용 화면 접근)
  bool get isSuperadmin => isAdmin;

  /// CEO 또는 Admin (인사권, 다이제스트 설정 조회)
  bool get isCeoOrAbove => isAdmin || role == UserRole.ceo;

  /// 관리급 (Admin/CEO/Manager) — 부서/업무 CRUD, 활동 로그 조회
  bool get isManagement =>
      isAdmin || role == UserRole.ceo || role == UserRole.manager;

  /// 일반 직원 여부 (관리 권한 없음)
  bool get isStaffOnly => !isManagement;

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? Function()? phone,
    String? Function()? avatarUrl,
    UserRole? role,
    bool? isAdmin,
    String? Function()? departmentId,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone != null ? phone() : this.phone,
      avatarUrl: avatarUrl != null ? avatarUrl() : this.avatarUrl,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      departmentId: departmentId != null ? departmentId() : this.departmentId,
    );
  }
}
