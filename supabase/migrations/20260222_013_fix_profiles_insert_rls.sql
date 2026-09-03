-- ============================================
-- 013: profiles INSERT RLS 정책 추가
--
-- 문제: 회원가입 시 profiles INSERT 권한 없음 (42501)
-- 원인: handle_new_user() 트리거는 SECURITY DEFINER로 동작하지만,
--       클라이언트 측 upsert 호출 시 INSERT 정책이 없어 차단됨
--
-- Supabase SQL Editor에서 실행하세요.
-- ============================================

-- profiles INSERT 정책: 본인 프로필만 삽입 가능
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);
