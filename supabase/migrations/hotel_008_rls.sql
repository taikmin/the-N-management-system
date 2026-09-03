-- ============================================================
-- Hotel Migration 008: Row-Level Security 정책
-- ============================================================
-- 원칙:
--  - profiles: 모두 조회 가능, 본인/관리자만 수정
--  - departments: 모두 조회, 관리자(CEO/Manager)만 CRUD
--  - tasks:
--     · CEO/Manager: 전체 CRUD
--     · Staff: 조회는 본인+본인 부서, 수정은 본인에게 할당된 것만
--  - memos: user_id = auth.uid()만 접근 (개인)
--  - file_attachments: 로그인 사용자 CRUD
--  - activity_logs: CEO/Manager만 조회, INSERT는 트리거(SECURITY DEFINER)
--  - app_settings, digest_recipients: CEO/Manager만 조회/수정
-- ============================================================

-- ============================================================
-- profiles
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS profiles_insert_self ON public.profiles;
CREATE POLICY profiles_insert_self ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id OR public.is_admin(auth.uid()))
  WITH CHECK (auth.uid() = id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS profiles_delete_admin ON public.profiles;
CREATE POLICY profiles_delete_admin ON public.profiles
  FOR DELETE TO authenticated USING (public.is_admin(auth.uid()));

-- ============================================================
-- departments
-- ============================================================
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS departments_select ON public.departments;
CREATE POLICY departments_select ON public.departments
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS departments_crud_admin ON public.departments;
CREATE POLICY departments_crud_admin ON public.departments
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- ============================================================
-- tasks
-- ============================================================
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- CEO/Manager: 전체 CRUD
DROP POLICY IF EXISTS tasks_admin_all ON public.tasks;
CREATE POLICY tasks_admin_all ON public.tasks
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Staff: 자기에게 할당된 것 OR 자기 부서 것 조회
DROP POLICY IF EXISTS tasks_staff_select ON public.tasks;
CREATE POLICY tasks_staff_select ON public.tasks
  FOR SELECT TO authenticated
  USING (
    assignee_id = auth.uid()
    OR department_id = (SELECT department_id FROM public.profiles WHERE id = auth.uid())
  );

-- Staff: 자기에게 할당된 것만 UPDATE (status/completion_note/delay_reason 등)
DROP POLICY IF EXISTS tasks_staff_update ON public.tasks;
CREATE POLICY tasks_staff_update ON public.tasks
  FOR UPDATE TO authenticated
  USING (assignee_id = auth.uid())
  WITH CHECK (assignee_id = auth.uid());

-- Staff는 INSERT/DELETE 불가 (관리자만)

-- ============================================================
-- memos (개인 소유)
-- ============================================================
ALTER TABLE public.memos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS memos_own ON public.memos;
CREATE POLICY memos_own ON public.memos
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- file_attachments (인증 사용자 CRUD)
-- ============================================================
ALTER TABLE public.file_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS file_attachments_all ON public.file_attachments;
CREATE POLICY file_attachments_all ON public.file_attachments
  FOR ALL TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================================
-- activity_logs (관리자만 조회, INSERT는 트리거)
-- ============================================================
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS activity_logs_admin_select ON public.activity_logs;
CREATE POLICY activity_logs_admin_select ON public.activity_logs
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

-- INSERT는 log_activity() 트리거 (SECURITY DEFINER)로만 수행
DROP POLICY IF EXISTS activity_logs_no_insert ON public.activity_logs;
CREATE POLICY activity_logs_no_insert ON public.activity_logs
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- ============================================================
-- app_settings + digest_recipients (관리자만)
-- ============================================================
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_admin ON public.app_settings;
CREATE POLICY app_settings_admin ON public.app_settings
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

ALTER TABLE public.digest_recipients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS digest_recipients_admin ON public.digest_recipients;
CREATE POLICY digest_recipients_admin ON public.digest_recipients
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- ============================================================
-- ROLLBACK: RLS 정책 삭제 (테이블은 유지)
-- ============================================================
-- 각 테이블마다: ALTER TABLE ... DISABLE ROW LEVEL SECURITY;
-- 그리고 DROP POLICY 각 이름별로.
