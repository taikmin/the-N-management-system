# Workflow - R&D Task Manager

## Development Workflow

### Git Flow
```
main (production-ready)
  └── develop (integration)
       ├── feature/auth-login
       ├── feature/dashboard
       ├── fix/task-sorting
       └── docs/api-guide
```

### Branch Rules
1. `main`: 릴리스 가능한 안정 코드만
2. `develop`: 통합 브랜치 (CI 통과 필수)
3. `feature/*`: 기능 개발
4. `fix/*`: 버그 수정
5. `docs/*`: 문서 작업

### Commit Convention
```
<type>(<scope>): <subject>

<body>

<footer>
```
- type: feat, fix, docs, style, refactor, test, chore
- scope: auth, dashboard, tasks, budget, docs, core
- subject: 50자 이내, 명령형, 한국어/영어 혼용 가능

### PR Process
1. feature 브랜치에서 작업
2. 로컬 테스트 통과 확인
3. PR 생성 (템플릿 사용)
4. 코드 리뷰 (Claude Code 또는 팀원)
5. CI 통과 확인
6. Squash merge to develop

---

## TDD (Test-Driven Development)

### Testing Pyramid
```
        /  E2E  \          ← integration_test (최소)
       / Integration \     ← widget_test (적당히)
      /    Unit Tests   \  ← test (최대)
```

### Test Naming Convention
```dart
test('should [expected behavior] when [condition]', () {
  // Given (Arrange)
  // When (Act)
  // Then (Assert)
});
```

### Coverage Target
- Unit: 80% 이상
- Widget: 주요 화면 50% 이상
- Integration: 핵심 유저 플로우

---

## Daily Report

### Format
```markdown
# Daily Report - YYYY-MM-DD

## Completed
- [feature] 구현 완료된 기능
- [fix] 수정된 버그

## In Progress
- [feature] 진행 중인 작업 (진행률 %)

## Blockers
- 차단 요소

## Next
- 다음 작업 계획

## Metrics
- Commits: N
- Tests: passed/total
- Coverage: N%
```

### 생성 규칙
- 매 작업 세션 종료 시 자동 생성
- `docs/daily-log/YYYY-MM-DD.md`에 저장
- Git 커밋 히스토리 기반 자동 요약

---

## CI/CD Pipeline (Planned)

### GitHub Actions
```yaml
on: [push, pull_request]

jobs:
  analyze:    # dart analyze
  format:     # dart format --set-exit-if-changed
  test:       # flutter test --coverage
  build-web:  # flutter build web
  build-apk:  # flutter build apk
```

### Release Process
1. develop → main PR 생성
2. 버전 태그 (semantic versioning)
3. 자동 빌드 및 배포
   - Web: GitHub Pages / Vercel
   - Android: Google Play (Internal Track)
   - iOS: TestFlight

---

## Code Review Checklist
- [ ] CLAUDE.md 코드 스타일 준수
- [ ] 테스트 작성 및 통과
- [ ] 불필요한 주석/코드 없음
- [ ] 보안 취약점 없음 (API 키 노출 등)
- [ ] 성능 이슈 없음 (불필요한 리빌드 등)
- [ ] 접근성 고려 (Semantics, 최소 터치 영역)
- [ ] 반응형 레이아웃 확인
