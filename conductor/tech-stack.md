# Tech Stack Decisions - R&D Task Manager

## Frontend Framework: Flutter
**Status**: Confirmed
**Date**: 2026-02-21

### Decision
Flutter를 프론트엔드 프레임워크로 선택한다.

### Rationale
- **크로스플랫폼**: 단일 코드베이스로 6개 플랫폼 지원 (Android, iOS, Web, Windows, macOS, Linux)
- **성능**: 네이티브 컴파일, 60fps 렌더링
- **생산성**: Hot reload, 풍부한 위젯 라이브러리
- **Material 3**: Google Material Design 3 네이티브 지원
- **커뮤니티**: 활발한 오픈소스 생태계, 풍부한 패키지

### Alternatives Considered
- React Native: 웹 지원 미흡, 데스크톱 지원 약함
- .NET MAUI: 생태계 작음, Linux 미지원
- Kotlin Multiplatform: 아직 성숙도 부족 (UI 공유 제한적)

---

## Backend: Supabase
**Status**: Confirmed
**Date**: 2026-02-21

### Decision
Supabase를 백엔드 서비스로 선택한다.

### Rationale
- **PostgreSQL**: 강력한 관계형 DB, RLS(Row Level Security)
- **Auth**: 이메일, OAuth, SSO 지원
- **Realtime**: WebSocket 기반 실시간 데이터 동기화
- **Storage**: 파일 업로드 및 관리
- **Edge Functions**: 서버리스 비즈니스 로직
- **Self-hosting**: 필요시 기관 내부 서버에 배포 가능
- **비용**: 무료 티어로 프로토타입 가능

### Alternatives Considered
- Firebase: 벤더 종속, NoSQL (복잡한 관계 쿼리 어려움)
- AWS Amplify: 복잡한 설정, 비용 예측 어려움
- 자체 서버: 개발/운영 부담 큼

---

## State Management: Riverpod
**Status**: Confirmed
**Date**: 2026-02-21

### Decision
Riverpod (v2+)을 상태 관리 솔루션으로 선택한다.

### Rationale
- **타입 안전성**: 컴파일 타임에 에러 감지
- **테스트 용이성**: Provider overriding으로 쉬운 모킹
- **코드 생성**: riverpod_annotation으로 보일러플레이트 감소
- **성능**: 세밀한 리빌드 제어
- **Provider scoping**: feature별 독립적 상태 관리

### Alternatives Considered
- BLoC: 보일러플레이트 많음, 학습 곡선
- GetX: 타입 안전성 부족, 매직 넘버
- Provider: Riverpod의 전신, 한계점 존재

---

## Routing: GoRouter
**Status**: Confirmed
**Date**: 2026-02-21

### Decision
GoRouter를 라우팅 솔루션으로 선택한다.

### Rationale
- **선언적 라우팅**: 타입 안전한 route 정의
- **딥링크**: 모바일 딥링크 네이티브 지원
- **웹 URL**: 브라우저 URL과 자연스러운 동기화
- **리다이렉트**: 인증 가드 등 조건부 라우팅
- **ShellRoute**: 중첩 네비게이션 지원

---

## Package Dependencies (Planned)
```yaml
dependencies:
  flutter_riverpod: ^2.x
  riverpod_annotation: ^2.x
  go_router: ^14.x
  supabase_flutter: ^2.x
  freezed_annotation: ^2.x
  json_annotation: ^4.x
  intl: ^0.19.x
  shared_preferences: ^2.x
  hive_flutter: ^2.x
  cached_network_image: ^3.x
  flutter_svg: ^2.x

dev_dependencies:
  build_runner: ^2.x
  freezed: ^2.x
  json_serializable: ^6.x
  riverpod_generator: ^2.x
  mockito: ^5.x
  flutter_lints: ^5.x
```
