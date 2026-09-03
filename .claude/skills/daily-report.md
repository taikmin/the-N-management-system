# Skill: Daily Report Generator

## Description
일일 개발 보고서를 자동으로 생성한다.

## Trigger
- 사용자가 "일일 보고서", "daily report", "오늘 작업 요약" 요청 시
- 작업 세션 종료 시

## Process
1. 오늘 날짜의 git 커밋 로그를 조회한다
2. 변경된 파일 목록과 diff를 분석한다
3. 테스트 실행 결과를 수집한다
4. 아래 템플릿에 맞춰 보고서를 작성한다
5. `docs/daily-log/YYYY-MM-DD.md`에 저장한다

## Template
```markdown
# Daily Report - {DATE}

## Summary
{1-2줄 요약}

## Completed
- [{type}] {description} ({commit hash})

## In Progress
- [{type}] {description} ({progress}%)

## Blockers
- {blocker description}

## Next Steps
- {planned work}

## Metrics
- Commits: {count}
- Files changed: {count}
- Lines added/removed: +{added}/-{removed}
- Tests: {passed}/{total} ({coverage}%)
```

## Commands
```bash
# Git log for today
git log --oneline --since="today" --format="%h %s"

# Files changed today
git diff --stat $(git log --since="today" --format="%H" | tail -1)^..HEAD

# Test results
flutter test --reporter compact
```
