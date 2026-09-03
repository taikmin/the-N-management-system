# Skill: Supabase Setup Guide

## Description
Supabase 프로젝트 설정 및 Flutter 연동 가이드.

## Initial Setup

### 1. Supabase 프로젝트 생성
1. https://supabase.com 접속
2. New Project 생성
3. Project URL과 anon key 복사

### 2. Flutter 패키지 설치
```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.x
```

### 3. 환경 변수 설정
```
# .env (git에 포함하지 않음)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

```
# .env.example (git에 포함)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 4. 초기화 코드
```dart
// lib/app/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
}

final supabase = Supabase.instance.client;
```

## Database Tables (Core)

### profiles
```sql
CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  full_name TEXT NOT NULL,
  department TEXT,
  position TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### projects
```sql
CREATE TABLE projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'active',
  start_date DATE,
  end_date DATE,
  budget BIGINT DEFAULT 0,
  owner_id UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### tasks
```sql
CREATE TABLE tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'todo',
  priority TEXT DEFAULT 'medium',
  assignee_id UUID REFERENCES profiles(id),
  due_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Row Level Security (RLS)
```sql
-- Enable RLS
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Policy: 프로젝트 멤버만 접근 가능
CREATE POLICY "project_member_access" ON projects
  FOR ALL USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM project_members
      WHERE user_id = auth.uid()
    )
  );
```

## Auth Pattern
```dart
// Sign up
await supabase.auth.signUp(email: email, password: password);

// Sign in
await supabase.auth.signInWithPassword(email: email, password: password);

// Sign out
await supabase.auth.signOut();

// Auth state listener
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;
  final session = data.session;
});
```

## Realtime
```dart
// Subscribe to task changes
final channel = supabase
  .channel('tasks')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'tasks',
    callback: (payload) {
      // Handle change
    },
  )
  .subscribe();
```
