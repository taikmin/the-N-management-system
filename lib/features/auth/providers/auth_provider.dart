import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/models/app_user.dart';
import '../domain/models/user_role.dart';

/// AuthRepository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// 인증 상태 Provider (세션 기반)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});

/// 현재 사용자 Provider
final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, AppUser?>(
  CurrentUserNotifier.new,
);

class CurrentUserNotifier extends AsyncNotifier<AppUser?> {
  @override
  FutureOr<AppUser?> build() async {
    final repo = ref.read(authRepositoryProvider);
    final user = repo.currentUser;
    if (user == null) return null;
    return repo.getProfile(user.id);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return repo.signIn(email: email, password: password);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    UserRole role = UserRole.staff,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );
    });
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AsyncData(null);
  }

  Future<void> refresh() async {
    final repo = ref.read(authRepositoryProvider);
    final user = repo.currentUser;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    state = AsyncData(await repo.getProfile(user.id));
  }
}

/// 로그인 여부 간편 조회
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull != null;
});

/// 시스템 관리자(Admin) 여부
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.isSuperadmin ?? false;
});

/// CEO 또는 Admin (인사권/설정 조회)
final isCeoOrAboveProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.isCeoOrAbove ?? false;
});

/// 관리급 (Admin/CEO/Manager) — 부서/업무 관리
final isManagementProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.isManagement ?? false;
});
