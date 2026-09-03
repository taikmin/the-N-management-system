-- ============================================================================
-- 015: 공용 데이터 RLS 정책 — "메모만 개인, 나머지 전부 공용"
--
-- 핵심 원칙:
--   - 인증된 사용자(auth.uid() IS NOT NULL)는 모든 공용 데이터를 읽고 쓰고 수정 가능
--   - 삭제만 Admin(is_admin()) 제한
--   - 메모(memos)만 유일한 개인 영역 (user_id = auth.uid())
--
-- 이전 마이그레이션(001~014)의 RLS를 전부 대체합니다.
-- Supabase SQL Editor에서 한번에 실행하세요.
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PART 1: 스키마 보장 (idempotent)                            ║
-- ╚══════════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS default_zoom_link TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS default_zoom_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS default_zoom_password TEXT;

ALTER TABLE public.tasks ALTER COLUMN project_id DROP NOT NULL;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS category TEXT;

ALTER TABLE public.meetings ADD COLUMN IF NOT EXISTS meeting_mode TEXT NOT NULL DEFAULT 'in_person';
ALTER TABLE public.meetings ADD COLUMN IF NOT EXISTS online_platform TEXT;
ALTER TABLE public.meetings ADD COLUMN IF NOT EXISTS online_link TEXT;
ALTER TABLE public.meetings ADD COLUMN IF NOT EXISTS online_meeting_id TEXT;
ALTER TABLE public.meetings ADD COLUMN IF NOT EXISTS online_password TEXT;

CREATE TABLE IF NOT EXISTS public.memos (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title       TEXT NOT NULL DEFAULT '',
  content     TEXT DEFAULT '',
  category    TEXT,
  is_pinned   BOOLEAN NOT NULL DEFAULT false,
  priority    TEXT NOT NULL DEFAULT 'none',
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.memos ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_memos_user_id ON public.memos(user_id);
CREATE INDEX IF NOT EXISTS idx_memos_user_status ON public.memos(user_id, status);
CREATE INDEX IF NOT EXISTS idx_memos_user_pinned ON public.memos(user_id, is_pinned DESC, created_at DESC);
DROP TRIGGER IF EXISTS set_memos_updated_at ON public.memos;
CREATE TRIGGER set_memos_updated_at BEFORE UPDATE ON public.memos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TABLE IF NOT EXISTS public.file_attachments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  file_name TEXT NOT NULL,
  file_size BIGINT NOT NULL DEFAULT 0,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  bucket_name TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  uploader_id UUID NOT NULL REFERENCES auth.users(id),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.file_attachments ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_file_attachments_entity ON public.file_attachments(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_file_attachments_uploader ON public.file_attachments(uploader_id);
DROP TRIGGER IF EXISTS set_file_attachments_updated_at ON public.file_attachments;
CREATE TRIGGER set_file_attachments_updated_at BEFORE UPDATE ON public.file_attachments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.file_attachments DROP CONSTRAINT IF EXISTS file_attachments_entity_type_check;
ALTER TABLE public.file_attachments ADD CONSTRAINT file_attachments_entity_type_check
  CHECK (entity_type IN ('project','task','daily_log','meeting','meeting_document','memo'));


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PART 2: 모든 기존 정책 삭제                                  ║
-- ╚══════════════════════════════════════════════════════════════╝

-- profiles
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or admin" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;

-- projects
DROP POLICY IF EXISTS "Project members can view projects" ON public.projects;
DROP POLICY IF EXISTS "Authenticated users can create projects" ON public.projects;
DROP POLICY IF EXISTS "Project owner/admin can update" ON public.projects;
DROP POLICY IF EXISTS "Project owner can delete" ON public.projects;
DROP POLICY IF EXISTS "projects_select" ON public.projects;
DROP POLICY IF EXISTS "projects_insert" ON public.projects;
DROP POLICY IF EXISTS "projects_update" ON public.projects;
DROP POLICY IF EXISTS "projects_delete" ON public.projects;

-- project_members
DROP POLICY IF EXISTS "Project members can view members" ON public.project_members;
DROP POLICY IF EXISTS "Project owner/admin can add members" ON public.project_members;
DROP POLICY IF EXISTS "Project owner/admin can remove members" ON public.project_members;
DROP POLICY IF EXISTS "View project members" ON public.project_members;
DROP POLICY IF EXISTS "Add project members" ON public.project_members;
DROP POLICY IF EXISTS "Remove project members" ON public.project_members;
DROP POLICY IF EXISTS "pm_select" ON public.project_members;
DROP POLICY IF EXISTS "pm_insert" ON public.project_members;
DROP POLICY IF EXISTS "pm_delete" ON public.project_members;

-- tasks
DROP POLICY IF EXISTS "Project members can view tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project members can create tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project members can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project owner/admin can delete tasks" ON public.tasks;
DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;

-- daily_logs
DROP POLICY IF EXISTS "Project members can view daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "Users can create own daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "Users can update own daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "Users can delete own daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_select" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_insert" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_update" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_delete" ON public.daily_logs;

-- task_comments
DROP POLICY IF EXISTS "Project members can view comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can create comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_select" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_insert" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_update" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_delete" ON public.task_comments;

-- meetings
DROP POLICY IF EXISTS "Project members can view meetings" ON public.meetings;
DROP POLICY IF EXISTS "Project members can create meetings" ON public.meetings;
DROP POLICY IF EXISTS "Meeting creator/project owner can update" ON public.meetings;
DROP POLICY IF EXISTS "Meeting creator/project owner can delete" ON public.meetings;
DROP POLICY IF EXISTS "meetings_select" ON public.meetings;
DROP POLICY IF EXISTS "meetings_insert" ON public.meetings;
DROP POLICY IF EXISTS "meetings_update" ON public.meetings;
DROP POLICY IF EXISTS "meetings_delete" ON public.meetings;

-- meeting_participants
DROP POLICY IF EXISTS "Meeting participants can view" ON public.meeting_participants;
DROP POLICY IF EXISTS "Users can manage participants" ON public.meeting_participants;
DROP POLICY IF EXISTS "Users can update own attendance" ON public.meeting_participants;
DROP POLICY IF EXISTS "Organizer can remove participants" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_select" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_insert" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_update" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_delete" ON public.meeting_participants;

-- meeting_documents
DROP POLICY IF EXISTS "Project members can view documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "Users can upload documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "Uploader/organizer can update documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "Uploader/organizer can delete documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_select" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_insert" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_update" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_delete" ON public.meeting_documents;

-- meeting_agenda
DROP POLICY IF EXISTS "Project members can view agenda" ON public.meeting_agenda;
DROP POLICY IF EXISTS "Organizer can manage agenda" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_select" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_insert" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_update" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_delete" ON public.meeting_agenda;

-- meeting_timeline
DROP POLICY IF EXISTS "Project members can view timeline" ON public.meeting_timeline;
DROP POLICY IF EXISTS "Organizer can manage timeline" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_select" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_insert" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_update" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_delete" ON public.meeting_timeline;

-- memos
DROP POLICY IF EXISTS "memos_select" ON public.memos;
DROP POLICY IF EXISTS "memos_insert" ON public.memos;
DROP POLICY IF EXISTS "memos_update" ON public.memos;
DROP POLICY IF EXISTS "memos_delete" ON public.memos;

-- file_attachments
DROP POLICY IF EXISTS "file_attachments_select" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_insert" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_update" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_delete" ON public.file_attachments;
DROP POLICY IF EXISTS "Authenticated users can view files" ON public.file_attachments;
DROP POLICY IF EXISTS "Authenticated users can upload files" ON public.file_attachments;
DROP POLICY IF EXISTS "Uploader or admin can update files" ON public.file_attachments;
DROP POLICY IF EXISTS "Uploader or admin can delete files" ON public.file_attachments;


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PART 3: 새 정책 — 메모만 개인, 나머지 전부 공용              ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ━━━━━━━━━━ profiles ━━━━━━━━━━
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- ━━━━━━━━━━ projects (공용) ━━━━━━━━━━
CREATE POLICY "projects_select" ON public.projects FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "projects_insert" ON public.projects FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "projects_update" ON public.projects FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "projects_delete" ON public.projects FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ project_members (공용) ━━━━━━━━━━
CREATE POLICY "pm_select" ON public.project_members FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "pm_insert" ON public.project_members FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
  );
CREATE POLICY "pm_delete" ON public.project_members FOR DELETE
  USING (
    public.is_admin()
    OR project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
  );

-- ━━━━━━━━━━ tasks (공용) ━━━━━━━━━━
CREATE POLICY "tasks_select" ON public.tasks FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "tasks_insert" ON public.tasks FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "tasks_update" ON public.tasks FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "tasks_delete" ON public.tasks FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ daily_logs (공용) ━━━━━━━━━━
CREATE POLICY "daily_logs_select" ON public.daily_logs FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "daily_logs_insert" ON public.daily_logs FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "daily_logs_update" ON public.daily_logs FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "daily_logs_delete" ON public.daily_logs FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ task_comments (공용) ━━━━━━━━━━
CREATE POLICY "task_comments_select" ON public.task_comments FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "task_comments_insert" ON public.task_comments FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "task_comments_update" ON public.task_comments FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "task_comments_delete" ON public.task_comments FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ meetings (공용) ━━━━━━━━━━
CREATE POLICY "meetings_select" ON public.meetings FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "meetings_insert" ON public.meetings FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "meetings_update" ON public.meetings FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "meetings_delete" ON public.meetings FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ meeting_participants (공용) ━━━━━━━━━━
CREATE POLICY "mp_select" ON public.meeting_participants FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "mp_insert" ON public.meeting_participants FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "mp_update" ON public.meeting_participants FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "mp_delete" ON public.meeting_participants FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ meeting_documents (공용) ━━━━━━━━━━
CREATE POLICY "md_select" ON public.meeting_documents FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "md_insert" ON public.meeting_documents FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "md_update" ON public.meeting_documents FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "md_delete" ON public.meeting_documents FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ meeting_agenda (공용) ━━━━━━━━━━
CREATE POLICY "ma_select" ON public.meeting_agenda FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "ma_insert" ON public.meeting_agenda FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "ma_update" ON public.meeting_agenda FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "ma_delete" ON public.meeting_agenda FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ meeting_timeline (공용) ━━━━━━━━━━
CREATE POLICY "mt_select" ON public.meeting_timeline FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "mt_insert" ON public.meeting_timeline FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "mt_update" ON public.meeting_timeline FOR UPDATE
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "mt_delete" ON public.meeting_timeline FOR DELETE
  USING (public.is_admin());

-- ━━━━━━━━━━ memos (개인 — 유일한 개인 영역) ━━━━━━━━━━
CREATE POLICY "memos_select" ON public.memos FOR SELECT
  USING (user_id = auth.uid());
CREATE POLICY "memos_insert" ON public.memos FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "memos_update" ON public.memos FOR UPDATE
  USING (user_id = auth.uid());
CREATE POLICY "memos_delete" ON public.memos FOR DELETE
  USING (user_id = auth.uid());

-- ━━━━━━━━━━ file_attachments (공용 조회, 본인 삭제) ━━━━━━━━━━
CREATE POLICY "file_attachments_select" ON public.file_attachments FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "file_attachments_insert" ON public.file_attachments FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "file_attachments_update" ON public.file_attachments FOR UPDATE
  USING (auth.uid() = uploader_id OR public.is_admin());
CREATE POLICY "file_attachments_delete" ON public.file_attachments FOR DELETE
  USING (auth.uid() = uploader_id OR public.is_admin());

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  완료! 메모만 개인, 나머지 전부 공용                            ║
-- ╚══════════════════════════════════════════════════════════════╝
