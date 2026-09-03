# System Architecture - R&D Task Manager

## Overview
```
┌─────────────────────────────────────────────────┐
│                   Client Apps                    │
│  ┌─────────┐ ┌─────┐ ┌─────┐ ┌───────────────┐ │
│  │ Android │ │ iOS │ │ Web │ │ Desktop       │ │
│  │         │ │     │ │     │ │ (Win/Mac/Lin) │ │
│  └────┬────┘ └──┬──┘ └──┬──┘ └──────┬────────┘ │
│       └─────────┴───────┴───────────┘           │
│                     │                            │
│            ┌────────▼────────┐                   │
│            │   Flutter App   │                   │
│            │  (Single Codebase)                  │
│            └────────┬────────┘                   │
└─────────────────────┼───────────────────────────┘
                      │ HTTPS / WebSocket
┌─────────────────────┼───────────────────────────┐
│                Supabase                          │
│  ┌──────────┐ ┌─────▼─────┐ ┌────────────────┐ │
│  │   Auth   │ │  Realtime  │ │    Storage     │ │
│  │          │ │ (WebSocket)│ │  (Files/Docs)  │ │
│  └──────────┘ └───────────┘ └────────────────┘ │
│  ┌──────────────────────────────────────────┐   │
│  │          PostgreSQL Database              │   │
│  │  ┌──────────┐ ┌────────┐ ┌────────────┐  │   │
│  │  │ profiles │ │projects│ │   tasks    │  │   │
│  │  │          │ │        │ │            │  │   │
│  │  └──────────┘ └────────┘ └────────────┘  │   │
│  │  ┌──────────┐ ┌────────┐ ┌────────────┐  │   │
│  │  │  budget  │ │  docs  │ │  comments  │  │   │
│  │  └──────────┘ └────────┘ └────────────┘  │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │         Edge Functions (Deno)             │   │
│  │  - 알림 발송                               │   │
│  │  - 보고서 생성                              │   │
│  │  - 외부 시스템 연동                          │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## App Architecture (Flutter)

### Layer Diagram
```
┌──────────────────────────────────────────┐
│            Presentation Layer            │
│  ┌────────┐ ┌──────────┐ ┌───────────┐  │
│  │Screens │ │ Widgets  │ │Controllers│  │
│  └────┬───┘ └────┬─────┘ └─────┬─────┘  │
│       └──────────┴──────────────┘        │
│                   │ ref.watch/read       │
│       ┌───────────▼───────────┐          │
│       │   Riverpod Providers  │          │
│       └───────────┬───────────┘          │
├───────────────────┼──────────────────────┤
│            Domain Layer                  │
│  ┌────────────────▼──────────────────┐   │
│  │     Repository Interfaces         │   │
│  └────────────────┬──────────────────┘   │
│  ┌────────────────▼──────────────────┐   │
│  │     Models (Freezed)              │   │
│  └───────────────────────────────────┘   │
├──────────────────────────────────────────┤
│              Data Layer                  │
│  ┌───────────────────────────────────┐   │
│  │     Repository Implementations    │   │
│  └────────────────┬──────────────────┘   │
│       ┌───────────┴───────────┐          │
│  ┌────▼────┐          ┌──────▼──────┐    │
│  │ Remote  │          │   Local     │    │
│  │(Supabase│          │(Hive/Prefs) │    │
│  └─────────┘          └─────────────┘    │
└──────────────────────────────────────────┘
```

### Directory Structure
```
lib/
├── main.dart                 # Entry point
├── app/
│   ├── app.dart              # MaterialApp 설정
│   ├── router.dart           # GoRouter 라우트 정의
│   ├── theme.dart            # Material 3 테마
│   └── supabase_config.dart  # Supabase 초기화
├── core/
│   ├── constants/            # 상수 정의
│   ├── extensions/           # Dart 확장 함수
│   ├── utils/                # 유틸리티 함수
│   └── errors/               # 에러 클래스
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   ├── presentation/
│   │   └── providers/
│   ├── dashboard/
│   ├── projects/
│   ├── tasks/
│   ├── budget/
│   ├── documents/
│   └── settings/
└── shared/
    ├── widgets/              # 공용 위젯
    └── models/               # 공용 모델
```

## Navigation Structure
```
App
├── /login              (AuthScreen)
├── /register           (RegisterScreen)
└── /                   (ShellRoute - BottomNav)
    ├── /dashboard      (DashboardScreen)
    ├── /projects       (ProjectListScreen)
    │   └── /:id        (ProjectDetailScreen)
    │       └── /tasks  (TaskBoardScreen)
    ├── /tasks          (MyTasksScreen)
    └── /settings       (SettingsScreen)
```

## Data Flow
```
User Action → Widget → Controller (Notifier)
    → Repository → Supabase API
    → Response → Repository → Provider state update
    → Widget rebuild
```

## Security
1. **Authentication**: Supabase Auth (JWT)
2. **Authorization**: PostgreSQL Row Level Security (RLS)
3. **API Keys**: 환경 변수로 관리 (.env)
4. **HTTPS**: 모든 통신 암호화
5. **Input Validation**: 클라이언트 + 서버 양쪽 검증
