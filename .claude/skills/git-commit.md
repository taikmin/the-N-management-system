# Skill: Git Commit Automation

## Description
Conventional Commits 규칙에 따라 자동으로 커밋 메시지를 생성하고 커밋한다.

## Trigger
- 사용자가 "커밋", "commit", "변경사항 저장" 요청 시

## Process

### 1. 변경사항 분석
```bash
# Staged changes
git diff --cached --stat
git diff --cached

# Unstaged changes
git diff --stat
git status
```

### 2. 커밋 메시지 생성
변경사항을 분석하여 Conventional Commits 형식으로 메시지 생성:

```
<type>(<scope>): <subject>

<body>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Types
| Type | Description | Example |
|------|-------------|---------|
| feat | 새 기능 | feat(auth): add email login |
| fix | 버그 수정 | fix(tasks): correct sort order |
| docs | 문서 변경 | docs(readme): update setup guide |
| style | 코드 스타일 | style(core): apply dart format |
| refactor | 리팩토링 | refactor(dashboard): extract widget |
| test | 테스트 | test(auth): add login unit tests |
| chore | 기타 | chore(deps): update riverpod |

### Scopes
auth, dashboard, projects, tasks, budget, documents, settings, core, shared, ci, deps

### Rules
1. subject는 50자 이내
2. subject는 명령형으로 작성 (영어: "add", "fix", "update")
3. body는 72자 줄바꿈
4. 여러 변경이 있으면 가장 중요한 것을 subject로
5. Breaking change는 footer에 `BREAKING CHANGE:` 추가

### 3. 커밋 실행
```bash
# Stage specific files (not git add -A)
git add <specific files>

# Commit with generated message
git commit -m "<message>"
```

## Examples
```bash
# Feature
git commit -m "feat(tasks): add kanban board view

Implement drag-and-drop kanban board for task management.
Supports todo, in-progress, and done columns.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# Bug fix
git commit -m "fix(auth): handle expired token refresh

Previously, expired tokens caused silent failures.
Now automatically refreshes token before API calls.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```
