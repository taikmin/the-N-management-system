# Skill: Code Review Checklist

## Description
PR 또는 코드 변경 시 자동으로 코드 리뷰를 수행한다.

## Trigger
- 사용자가 "코드 리뷰", "review", "PR 리뷰" 요청 시
- 새로운 feature 브랜치 완성 시

## Review Process

### 1. 자동 분석
```bash
# 정적 분석
flutter analyze

# 포맷 확인
dart format --set-exit-if-changed .

# 테스트 실행
flutter test
```

### 2. Checklist

#### Code Quality
- [ ] 변수/함수/클래스 이름이 의미를 명확히 전달하는가?
- [ ] 함수가 단일 책임 원칙(SRP)을 따르는가?
- [ ] 중복 코드가 없는가?
- [ ] 매직 넘버/문자열이 상수로 정의되었는가?
- [ ] 불필요한 주석이 없는가? (코드 자체가 문서가 되는가?)

#### Flutter Specific
- [ ] `const` 위젯을 적절히 사용했는가?
- [ ] 불필요한 `setState` 또는 리빌드가 없는가?
- [ ] `BuildContext`를 async gap 이후 사용하지 않는가?
- [ ] Trailing comma를 사용했는가?
- [ ] 위젯 트리가 너무 깊지 않은가? (3단계 이상이면 분리)

#### Architecture
- [ ] Feature-first 구조를 따르는가?
- [ ] data/domain/presentation 레이어 분리가 적절한가?
- [ ] Provider가 올바르게 정의되었는가?
- [ ] Repository 패턴을 따르는가?

#### Security
- [ ] API 키/시크릿이 코드에 하드코딩되지 않았는가?
- [ ] 사용자 입력이 적절히 검증되는가?
- [ ] SQL 인젝션 가능성이 없는가? (Supabase RLS 활용)
- [ ] XSS 취약점이 없는가? (웹 빌드 시)

#### Performance
- [ ] 불필요한 네트워크 요청이 없는가?
- [ ] 리스트에 `ListView.builder()`를 사용했는가?
- [ ] 이미지 캐싱이 적용되었는가?
- [ ] 메모리 누수 가능성이 없는가? (dispose 확인)

#### Testing
- [ ] 새 기능에 대한 테스트가 작성되었는가?
- [ ] 엣지 케이스가 테스트되었는가?
- [ ] 모든 테스트가 통과하는가?

#### Accessibility
- [ ] Semantics 위젯이 적절히 사용되었는가?
- [ ] 터치 영역이 최소 48x48dp인가?
- [ ] 색상 대비가 충분한가?
- [ ] 스크린 리더 호환성이 확인되었는가?

## Output Format
```markdown
## Code Review Result

### Summary
{전반적 평가}

### Issues Found
1. [{severity}] {file}:{line} - {description}

### Suggestions
1. {suggestion description}

### Verdict
- [ ] Approved
- [ ] Changes Requested
```
