-- ============================================================
-- Hotel Migration 010: Admin 분리 + CEO 인사권 + 부서 권한 조정
-- ============================================================
-- 권한 정책:
--   Admin(is_admin=true) — 시스템 슈퍼유저. 모든 것 가능.
--   CEO(role='ceo')     — 도메인 최상위. 조직 인사권 + 다이제스트 설정 조회.
--   Manager(role='manager') — 부서/업무 관리.
--   Staff(role='staff')  — 본인 업무만.
--
-- 헬퍼 함수:
--   is_superadmin(uid): profiles.is_admin=true만
--   is_ceo_or_above(uid): admin OR ceo
--   is_management(uid): admin OR ceo OR manager
--
-- 권한 매트릭스:
--   | 대상                              | 권한                     |
--   |-----------------------------------|--------------------------|
--   | app_settings SELECT               | is_ceo_or_above (조회)   |
--   | app_settings 수정                 | is_superadmin (Admin만)  |
--   | digest_recipients SELECT          | is_ceo_or_above (조회)   |
--   | digest_recipients CRUD            | is_superadmin (Admin만)  |
--   | profiles.role → 'ceo' 또는 is_admin=true 부여 | is_superadmin (권한 상승) |
--   | profiles.role: manager ↔ staff    | is_ceo_or_above (인사권) |
--   | departments 조회                  | 모두                     |
--   | departments 생성/수정/삭제        | is_management            |
--   | tasks 전체 관리                   | is_management            |
--   | tasks 본인 것                     | Staff 본인               |
--   | activity_logs 조회                | is_management            |
--   | memos                             | 본인만                   |
-- ============================================================

-- ============================================================
-- 1. 새 헬퍼 함수
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_superadmin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = user_id),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.is_ceo_or_above(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin OR role = 'ceo'
     FROM public.profiles WHERE id = user_id),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.is_management(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin OR role IN ('ceo', 'manager')
     FROM public.profiles WHERE id = user_id),
    false
  );
$$;

-- 기존 is_admin() 함수는 superadmin으로 통일
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.is_superadmin(user_id);
$$;

-- ============================================================
-- 2. RLS 정책 재배치 — profiles
-- ============================================================
-- CEO 이상은 다른 사용자 role 변경 가능 (인사권)
-- 단, role='ceo' 또는 is_admin=true 부여는 Admin만 (권한 상승 방지)

DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = id                         -- 본인 프로필 수정
    OR public.is_ceo_or_above(auth.uid())   -- CEO 또는 Admin은 다른 사용자 수정
  )
  WITH CHECK (
    auth.uid() = id
    OR public.is_ceo_or_above(auth.uid())
  );

DROP POLICY IF EXISTS profiles_delete_admin ON public.profiles;
CREATE POLICY profiles_delete_admin ON public.profiles
  FOR DELETE TO authenticated
  USING (public.is_superadmin(auth.uid()));

-- 방어 트리거: 권한 상승 방지
-- - 본인이 자기 role/is_admin 임의 변경 불가 (Admin 제외)
-- - role='ceo' 부여는 Admin만
-- - is_admin=true 부여는 Admin만
CREATE OR REPLACE FUNCTION public.prevent_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_is_super BOOLEAN;
  v_is_ceo BOOLEAN;
BEGIN
  -- SQL Editor / service role 등 auth 컨텍스트 없는 호출은 통과
  -- (DB에 직접 접근 가능한 주체는 이미 최고 권한)
  IF v_actor IS NULL THEN
    RETURN NEW;
  END IF;

  v_is_super := public.is_superadmin(v_actor);
  v_is_ceo := public.is_ceo_or_above(v_actor);

  -- Admin은 모두 가능
  IF v_is_super THEN
    RETURN NEW;
  END IF;

  -- is_admin 변경은 Admin만
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'is_admin 은(는) 시스템 관리자만 변경할 수 있습니다.';
  END IF;

  -- role 변경 규칙
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- CEO 이상만 다른 사람 role 변경 (본인은 아예 불가)
    IF v_actor = NEW.id THEN
      RAISE EXCEPTION '본인의 role은 변경할 수 없습니다.';
    END IF;
    IF NOT v_is_ceo THEN
      RAISE EXCEPTION 'role 변경은 CEO 이상만 가능합니다.';
    END IF;
    -- CEO는 'ceo'로 승격 불가 (권한 상승 방지)
    IF NEW.role = 'ceo' THEN
      RAISE EXCEPTION 'role=''ceo'' 부여는 시스템 관리자만 가능합니다.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_self_role_escalation_trigger ON public.profiles;
DROP TRIGGER IF EXISTS prevent_privilege_escalation_trigger ON public.profiles;
CREATE TRIGGER prevent_privilege_escalation_trigger
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_privilege_escalation();

-- ============================================================
-- 3. RLS 정책 재배치 — departments
-- ============================================================
-- 조회: 모두 (기존 유지)
-- 생성/수정/삭제: is_management (Manager도 가능)

DROP POLICY IF EXISTS departments_crud_admin ON public.departments;
DROP POLICY IF EXISTS departments_insert ON public.departments;
DROP POLICY IF EXISTS departments_update ON public.departments;
DROP POLICY IF EXISTS departments_delete ON public.departments;

CREATE POLICY departments_crud_management ON public.departments
  FOR ALL TO authenticated
  USING (public.is_management(auth.uid()))
  WITH CHECK (public.is_management(auth.uid()));

-- ============================================================
-- 4. RLS 정책 재배치 — tasks
-- ============================================================
DROP POLICY IF EXISTS tasks_admin_all ON public.tasks;
DROP POLICY IF EXISTS tasks_management_all ON public.tasks;
CREATE POLICY tasks_management_all ON public.tasks
  FOR ALL TO authenticated
  USING (public.is_management(auth.uid()))
  WITH CHECK (public.is_management(auth.uid()));
-- Staff 정책 (tasks_staff_select, tasks_staff_update)는 hotel_008 그대로 유지

-- ============================================================
-- 5. RLS 정책 재배치 — activity_logs
-- ============================================================
DROP POLICY IF EXISTS activity_logs_admin_select ON public.activity_logs;
DROP POLICY IF EXISTS activity_logs_management_select ON public.activity_logs;
CREATE POLICY activity_logs_management_select ON public.activity_logs
  FOR SELECT TO authenticated
  USING (public.is_management(auth.uid()));

-- ============================================================
-- 6. RLS 정책 재배치 — app_settings, digest_recipients
-- ============================================================
-- 조회: CEO 이상 (다이제스트 발송 시각/수신자 열람)
-- 수정: Admin만

-- app_settings
DROP POLICY IF EXISTS app_settings_admin ON public.app_settings;
DROP POLICY IF EXISTS app_settings_superadmin ON public.app_settings;
DROP POLICY IF EXISTS app_settings_select ON public.app_settings;
DROP POLICY IF EXISTS app_settings_modify ON public.app_settings;

CREATE POLICY app_settings_select ON public.app_settings
  FOR SELECT TO authenticated
  USING (public.is_ceo_or_above(auth.uid()));

CREATE POLICY app_settings_insert ON public.app_settings
  FOR INSERT TO authenticated
  WITH CHECK (public.is_superadmin(auth.uid()));

CREATE POLICY app_settings_update ON public.app_settings
  FOR UPDATE TO authenticated
  USING (public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_superadmin(auth.uid()));

CREATE POLICY app_settings_delete ON public.app_settings
  FOR DELETE TO authenticated
  USING (public.is_superadmin(auth.uid()));

-- digest_recipients
DROP POLICY IF EXISTS digest_recipients_admin ON public.digest_recipients;
DROP POLICY IF EXISTS digest_recipients_superadmin ON public.digest_recipients;
DROP POLICY IF EXISTS digest_recipients_select ON public.digest_recipients;
DROP POLICY IF EXISTS digest_recipients_modify ON public.digest_recipients;

CREATE POLICY digest_recipients_select ON public.digest_recipients
  FOR SELECT TO authenticated
  USING (public.is_ceo_or_above(auth.uid()));

CREATE POLICY digest_recipients_insert ON public.digest_recipients
  FOR INSERT TO authenticated
  WITH CHECK (public.is_superadmin(auth.uid()));

CREATE POLICY digest_recipients_update ON public.digest_recipients
  FOR UPDATE TO authenticated
  USING (public.is_superadmin(auth.uid()))
  WITH CHECK (public.is_superadmin(auth.uid()));

CREATE POLICY digest_recipients_delete ON public.digest_recipients
  FOR DELETE TO authenticated
  USING (public.is_superadmin(auth.uid()));

-- ============================================================
-- 확인 쿼리
-- ============================================================
-- SELECT public.is_superadmin(auth.uid());
-- SELECT public.is_ceo_or_above(auth.uid());
-- SELECT public.is_management(auth.uid());
