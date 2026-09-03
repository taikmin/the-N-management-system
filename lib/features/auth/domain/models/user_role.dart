/// 사용자 도메인 역할 (호텔 조직 위계)
///
/// 시스템 관리자(Admin)는 별도의 `is_admin` 컬럼으로 관리.
/// 여기 enum은 호텔 도메인 역할만 담는다.
enum UserRole {
  /// 대표 (호텔 도메인 최상위, 인사권)
  ceo('대표'),

  /// 관리자 (현장 관리자, 부서/업무 관리)
  manager('관리자'),

  /// 직원 (본인 업무 수행/보고)
  staff('직원');

  const UserRole(this.label);
  final String label;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.staff,
    );
  }
}
