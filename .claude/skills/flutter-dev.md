# Skill: Flutter Development Guidelines

## Description
Flutter 앱 개발 시 따라야 할 가이드라인과 패턴을 제공한다.

## Architecture Pattern
Feature-first + Repository Pattern:
```
feature/
├── data/
│   ├── repositories/       # Repository 구현
│   └── data_sources/       # Remote/Local data source
├── domain/
│   ├── models/             # Data models (freezed)
│   └── repositories/       # Repository 인터페이스
├── presentation/
│   ├── screens/            # 전체 화면
│   ├── widgets/            # 재사용 위젯
│   └── controllers/        # 화면별 로직 (Riverpod Notifier)
└── providers/              # Riverpod Provider 정의
```

## Widget Rules
1. **StatelessWidget 우선**: 상태가 없으면 StatelessWidget 사용
2. **ConsumerWidget**: Riverpod 상태 접근 시 사용
3. **const 생성자**: 가능하면 항상 const 생성자 사용
4. **Key 사용**: ListView 아이템에는 반드시 Key 전달
5. **Trailing comma**: 항상 trailing comma 사용

## Model Pattern (Freezed)
```dart
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    String? description,
    @Default(TaskStatus.todo) TaskStatus status,
    required DateTime createdAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
```

## Provider Pattern
```dart
@riverpod
class TaskList extends _$TaskList {
  @override
  FutureOr<List<Task>> build() async {
    return ref.read(taskRepositoryProvider).getTasks();
  }

  Future<void> addTask(Task task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).createTask(task);
      return ref.read(taskRepositoryProvider).getTasks();
    });
  }
}
```

## Screen Pattern
```dart
class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: tasksAsync.when(
        data: (tasks) => TaskListView(tasks: tasks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

## Error Handling
- Repository에서 예외를 잡아 Result 타입으로 반환
- UI에서는 AsyncValue.when()으로 에러 표시
- 사용자에게 의미 있는 에러 메시지 제공 (기술적 용어 X)

## Performance
- `const` 위젯 적극 활용
- `select()`로 필요한 상태만 구독
- 이미지는 `cached_network_image` 사용
- 리스트는 `ListView.builder()` 사용 (lazy loading)
