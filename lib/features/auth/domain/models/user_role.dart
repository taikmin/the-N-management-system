/// 사용자 역할
enum UserRole {
  /// 과제책임자 (Principal Investigator)
  pi('과제책임자 (PI)'),

  /// 연구원
  researcher('연구원'),

  /// 외부참여자
  external_('외부참여자');

  const UserRole(this.label);
  final String label;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.researcher,
    );
  }
}
