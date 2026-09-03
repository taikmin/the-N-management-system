/// 앱 전체에서 사용하는 문자열 상수
class AppStrings {
  AppStrings._();

  static const String appName = 'The N Resort Management';
  static const String appDescription = 'The N Resort 관리 시스템';

  // Auth
  static const String login = '로그인';
  static const String register = '회원가입';
  static const String email = '이메일';
  static const String password = '비밀번호';
  static const String confirmPassword = '비밀번호 확인';
  static const String fullName = '이름';
  static const String department = '부서';
  static const String phone = '연락처';
  static const String forgotPassword = '비밀번호 찾기';
  static const String noAccount = '계정이 없으신가요?';
  static const String hasAccount = '이미 계정이 있으신가요?';
  static const String logout = '로그아웃';

  // Navigation
  static const String dashboard = '대시보드';
  static const String departments = '부서';
  static const String tasks = '업무';
  static const String calendar = '캘린더';
  static const String memos = '메모';
  static const String settings = '설정';

  // Roles
  static const String roleCeo = '대표';
  static const String roleManager = '관리자';
  static const String roleStaff = '직원';
  static const String roleAdmin = '시스템 관리자';

  // Dashboard
  static const String welcomeMessage = '환영합니다';
  static const String noTasks = '등록된 업무가 없습니다';
  static const String createFirstTask = '첫 번째 업무를 생성해보세요';

  // Task status labels
  static const String statusAssigned = '지시됨';
  static const String statusInProgress = '진행중';
  static const String statusCompleted = '완료';
  static const String statusIncomplete = '미완료';
  static const String statusDelayed = '지연';

  // Errors
  static const String errorGeneral = '오류가 발생했습니다';
  static const String errorNetwork = '네트워크 연결을 확인해주세요';
  static const String errorInvalidEmail = '올바른 이메일을 입력해주세요';
  static const String errorPasswordShort = '비밀번호는 6자 이상이어야 합니다';
  static const String errorPasswordMismatch = '비밀번호가 일치하지 않습니다';
}
