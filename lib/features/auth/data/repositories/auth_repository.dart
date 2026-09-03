import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/supabase_config.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/user_role.dart';

/// Supabase Auth 에러를 사용자 친화적 한국어로 변환
String translateAuthError(Object error) {
  final msg = error.toString().toLowerCase();

  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid_credentials')) {
    return '이메일 또는 비밀번호가 올바르지 않습니다';
  }
  if (msg.contains('email not confirmed')) {
    return '이메일 인증이 완료되지 않았습니다';
  }
  if (msg.contains('user not found')) {
    return '등록되지 않은 이메일입니다';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return '이미 등록된 이메일입니다';
  }
  if (msg.contains('email rate limit') ||
      msg.contains('rate limit')) {
    return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요';
  }
  if (msg.contains('network') ||
      msg.contains('socketexception') ||
      msg.contains('connection')) {
    return '네트워크 연결을 확인해주세요';
  }
  if (msg.contains('weak password') ||
      msg.contains('password')) {
    return '비밀번호가 너무 약합니다. 더 강한 비밀번호를 사용해주세요';
  }
  if (msg.contains('signup is disabled')) {
    return '현재 회원가입이 비활성화되어 있습니다';
  }

  // 기본 메시지
  return '로그인에 실패했습니다. 다시 시도해주세요';
}

/// 인증 관련 데이터 처리
class AuthRepository {
  final _auth = SupabaseConfig.auth;
  final _client = SupabaseConfig.client;

  /// 현재 세션
  Session? get currentSession => _auth.currentSession;

  /// 현재 Supabase 유저
  User? get currentUser => _auth.currentUser;

  /// 인증 상태 스트림
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// 이메일/비밀번호로 회원가입
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.staff,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        // role은 서버 측 트리거가 항상 'staff'로 세팅. 관리자/CEO가 이후 승격.
      },
    );

    if (response.user == null) {
      throw Exception('회원가입에 실패했습니다');
    }

    // profiles는 handle_new_user() 트리거(SECURITY DEFINER)가 자동 생성
    if (response.session != null) {
      return getProfile(response.user!.id);
    }

    return AppUser(
      id: response.user!.id,
      email: email,
      fullName: fullName,
      phone: phone,
      role: role,
    );
  }

  /// 이메일/비밀번호로 로그인
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('로그인에 실패했습니다');
    }

    return getProfile(response.user!.id);
  }

  /// 현재 사용자의 admin 여부를 DB 함수로 확인
  Future<bool> checkIsAdmin() async {
    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// 프로필 조회
  Future<AppUser> getProfile(String userId) async {
    try {
      final data =
          await _client.from('profiles').select().eq('id', userId).single();

      final profileData = Map<String, dynamic>.from(data);

      // PostgREST 스키마 캐시에 is_admin이 없을 수 있으므로 RPC로 확인
      if (!profileData.containsKey('is_admin') && userId == currentUser?.id) {
        profileData['is_admin'] = await checkIsAdmin();
      }

      return AppUser.fromJson(profileData);
    } catch (e) {
      // profiles 테이블 조회 실패 시 Auth 메타데이터로 폴백
      final user = currentUser;
      final isAdmin =
          (userId == user?.id) ? await checkIsAdmin() : false;
      return AppUser(
        id: userId,
        email: user?.email ?? '',
        fullName:
            user?.userMetadata?['full_name'] as String? ?? '사용자',
        role: UserRole.fromString(
          user?.userMetadata?['role'] as String? ?? 'staff',
        ),
        isAdmin: isAdmin,
      );
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 비밀번호 재설정 이메일 발송
  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  /// [Admin] 사용자 역할 변경
  Future<void> updateUserRole(String userId, UserRole role) async {
    await _client
        .from('profiles')
        .update({'role': role.name}).eq('id', userId);
  }

  /// [Admin] 사용자 부서 배정
  Future<void> updateUserDepartment(String userId, String? departmentId) async {
    await _client
        .from('profiles')
        .update({'department_id': departmentId}).eq('id', userId);
  }

  /// [Admin] 모든 사용자 목록 조회
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('full_name');
    return List<Map<String, dynamic>>.from(data);
  }
}
