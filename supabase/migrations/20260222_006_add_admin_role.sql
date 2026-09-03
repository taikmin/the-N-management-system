-- ============================================================
-- Migration: Admin 계정 시스템
-- profiles 테이블에 is_admin 컬럼 추가 + RLS 정책 업데이트
-- ============================================================

-- 1. profiles 테이블에 is_admin 컬럼 추가
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

-- 2. admin 헬퍼 함수: 현재 사용자가 admin인지 확인
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- 3. RLS 정책 업데이트: admin은 모든 행에 CRUD 가능
-- ============================================================

-- ─── profiles ───
-- admin은 다른 사용자의 프로필(역할 포함)도 수정 가능
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile or admin"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id OR public.is_admin());

-- ─── projects ───
DROP POLICY IF EXISTS "Project members can view projects" ON public.projects;
CREATE POLICY "Project members can view projects"
  ON public.projects FOR SELECT
  USING (
    public.is_admin()
    OR owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Project owner/admin can update" ON public.projects;
CREATE POLICY "Project owner/admin can update"
  ON public.projects FOR UPDATE
  USING (
    public.is_admin()
    OR owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

DROP POLICY IF EXISTS "Project owner can delete" ON public.projects;
CREATE POLICY "Project owner can delete"
  ON public.projects FOR DELETE
  USING (public.is_admin() OR owner_id = auth.uid());

-- ─── tasks ───
DROP POLICY IF EXISTS "Project members can view tasks" ON public.tasks;
CREATE POLICY "Project members can view tasks"
  ON public.tasks FOR SELECT
  USING (
    public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Project members can update tasks" ON public.tasks;
CREATE POLICY "Project members can update tasks"
  ON public.tasks FOR UPDATE
  USING (
    public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Project owner/admin can delete tasks" ON public.tasks;
CREATE POLICY "Project owner/admin can delete tasks"
  ON public.tasks FOR DELETE
  USING (
    public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

-- ─── meetings ───
DROP POLICY IF EXISTS "Project members can view meetings" ON public.meetings;
CREATE POLICY "Project members can view meetings"
  ON public.meetings FOR SELECT
  USING (
    public.is_admin()
    OR creator_id = auth.uid()
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Meeting creator/project owner can update" ON public.meetings;
CREATE POLICY "Meeting creator/project owner can update"
  ON public.meetings FOR UPDATE
  USING (
    public.is_admin()
    OR creator_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Meeting creator/project owner can delete" ON public.meetings;
CREATE POLICY "Meeting creator/project owner can delete"
  ON public.meetings FOR DELETE
  USING (
    public.is_admin()
    OR creator_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

-- ─── meeting_documents ───
DROP POLICY IF EXISTS "Uploader/organizer can update documents" ON public.meeting_documents;
CREATE POLICY "Uploader/organizer can update documents"
  ON public.meeting_documents FOR UPDATE
  USING (
    public.is_admin()
    OR uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Uploader/organizer can delete documents" ON public.meeting_documents;
CREATE POLICY "Uploader/organizer can delete documents"
  ON public.meeting_documents FOR DELETE
  USING (
    public.is_admin()
    OR uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

-- ─── meeting_agenda ───
DROP POLICY IF EXISTS "Organizer can manage agenda" ON public.meeting_agenda;
CREATE POLICY "Organizer can manage agenda"
  ON public.meeting_agenda FOR ALL
  USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

-- ─── meeting_timeline ───
DROP POLICY IF EXISTS "Organizer can manage timeline" ON public.meeting_timeline;
CREATE POLICY "Organizer can manage timeline"
  ON public.meeting_timeline FOR ALL
  USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

-- ─── daily_logs ───
DROP POLICY IF EXISTS "Users can update own daily logs" ON public.daily_logs;
CREATE POLICY "Users can update own daily logs"
  ON public.daily_logs FOR UPDATE
  USING (public.is_admin() OR author_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own daily logs" ON public.daily_logs;
CREATE POLICY "Users can delete own daily logs"
  ON public.daily_logs FOR DELETE
  USING (public.is_admin() OR author_id = auth.uid());

-- ─── task_comments ───
DROP POLICY IF EXISTS "Users can update own comments" ON public.task_comments;
CREATE POLICY "Users can update own comments"
  ON public.task_comments FOR UPDATE
  USING (public.is_admin() OR author_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own comments" ON public.task_comments;
CREATE POLICY "Users can delete own comments"
  ON public.task_comments FOR DELETE
  USING (public.is_admin() OR author_id = auth.uid());

-- ============================================================
-- 4. 특정 사용자를 admin으로 설정하는 SQL (수동 실행)
-- 아래 '여기에_내_이메일' 부분을 실제 이메일로 교체하세요.
-- ============================================================
-- UPDATE public.profiles SET is_admin = true WHERE email = '여기에_내_이메일';
