-- ============================================================================
-- 014: 포괄적 RLS 수정 — 비관리자(일반 사용자) 정상 동작 보장
--
-- 이 마이그레이션은 모든 테이블의 스키마와 RLS를 한번에 정리합니다.
-- 어떤 이전 마이그레이션이 적용되었든 상관없이 안전하게 실행 가능합니다.
--
-- 수정 내용:
--   1. 누락 가능한 스키마 변경 (IF NOT EXISTS)
--   2. 모든 테이블의 RLS 정책 DROP & 재생성
--   3. 독립 태스크(project_id IS NULL) 완전 지원
--   4. 일반 사용자 권한 정상화
--   5. file_attachments entity_type에 'memo' 추가
--
-- Supabase SQL Editor에서 한번에 실행하세요.
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PART 1: 스키마 보장 (모두 idempotent)                        ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ─── is_admin() 헬퍼 함수 ───
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ─── profiles 추가 컬럼 ───
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS default_zoom_link TEXT;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS default_zoom_id TEXT;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS default_zoom_password TEXT;

-- ─── tasks: 독립 태스크 지원 ───
ALTER TABLE public.tasks ALTER COLUMN project_id DROP NOT NULL;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS category TEXT;

-- ─── meetings: 온라인 모드 ───
ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS meeting_mode TEXT NOT NULL DEFAULT 'in_person';
ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_platform TEXT;
ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_link TEXT;
ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_meeting_id TEXT;
ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_password TEXT;

-- ─── memos 테이블 ───
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

CREATE INDEX IF NOT EXISTS idx_memos_user_id
  ON public.memos(user_id);
CREATE INDEX IF NOT EXISTS idx_memos_user_status
  ON public.memos(user_id, status);
CREATE INDEX IF NOT EXISTS idx_memos_user_pinned
  ON public.memos(user_id, is_pinned DESC, created_at DESC);

DROP TRIGGER IF EXISTS set_memos_updated_at ON public.memos;
CREATE TRIGGER set_memos_updated_at
  BEFORE UPDATE ON public.memos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ─── file_attachments 테이블 ───
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

CREATE INDEX IF NOT EXISTS idx_file_attachments_entity
  ON public.file_attachments(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_file_attachments_uploader
  ON public.file_attachments(uploader_id);

DROP TRIGGER IF EXISTS set_file_attachments_updated_at ON public.file_attachments;
CREATE TRIGGER set_file_attachments_updated_at
  BEFORE UPDATE ON public.file_attachments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- file_attachments entity_type CHECK: 'memo' 추가
-- (기존 CHECK 제약 삭제 후 재생성)
ALTER TABLE public.file_attachments
  DROP CONSTRAINT IF EXISTS file_attachments_entity_type_check;
ALTER TABLE public.file_attachments
  ADD CONSTRAINT file_attachments_entity_type_check
  CHECK (entity_type IN (
    'project', 'task', 'daily_log',
    'meeting', 'meeting_document', 'memo'
  ));


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PART 2: 모든 기존 RLS 정책 삭제                              ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ─── profiles ───
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile or admin" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;

-- ─── projects ───
DROP POLICY IF EXISTS "Project members can view projects" ON public.projects;
DROP POLICY IF EXISTS "Authenticated users can create projects" ON public.projects;
DROP POLICY IF EXISTS "Project owner/admin can update" ON public.projects;
DROP POLICY IF EXISTS "Project owner can delete" ON public.projects;
DROP POLICY IF EXISTS "projects_select" ON public.projects;
DROP POLICY IF EXISTS "projects_insert" ON public.projects;
DROP POLICY IF EXISTS "projects_update" ON public.projects;
DROP POLICY IF EXISTS "projects_delete" ON public.projects;

-- ─── project_members ───
DROP POLICY IF EXISTS "Project members can view members" ON public.project_members;
DROP POLICY IF EXISTS "Project owner/admin can add members" ON public.project_members;
DROP POLICY IF EXISTS "Project owner/admin can remove members" ON public.project_members;
DROP POLICY IF EXISTS "View project members" ON public.project_members;
DROP POLICY IF EXISTS "Add project members" ON public.project_members;
DROP POLICY IF EXISTS "Remove project members" ON public.project_members;
DROP POLICY IF EXISTS "pm_select" ON public.project_members;
DROP POLICY IF EXISTS "pm_insert" ON public.project_members;
DROP POLICY IF EXISTS "pm_delete" ON public.project_members;

-- ─── tasks ───
DROP POLICY IF EXISTS "Project members can view tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project members can create tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project members can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project owner/admin can delete tasks" ON public.tasks;
DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;

-- ─── daily_logs ───
DROP POLICY IF EXISTS "Project members can view daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "Users can create own daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "Users can update own daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "Users can delete own daily logs" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_select" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_insert" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_update" ON public.daily_logs;
DROP POLICY IF EXISTS "daily_logs_delete" ON public.daily_logs;

-- ─── task_comments ───
DROP POLICY IF EXISTS "Project members can view comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can create comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON public.task_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_select" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_insert" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_update" ON public.task_comments;
DROP POLICY IF EXISTS "task_comments_delete" ON public.task_comments;

-- ─── meetings ───
DROP POLICY IF EXISTS "Project members can view meetings" ON public.meetings;
DROP POLICY IF EXISTS "Project members can create meetings" ON public.meetings;
DROP POLICY IF EXISTS "Meeting creator/project owner can update" ON public.meetings;
DROP POLICY IF EXISTS "Meeting creator/project owner can delete" ON public.meetings;
DROP POLICY IF EXISTS "meetings_select" ON public.meetings;
DROP POLICY IF EXISTS "meetings_insert" ON public.meetings;
DROP POLICY IF EXISTS "meetings_update" ON public.meetings;
DROP POLICY IF EXISTS "meetings_delete" ON public.meetings;

-- ─── meeting_participants ───
DROP POLICY IF EXISTS "Meeting participants can view" ON public.meeting_participants;
DROP POLICY IF EXISTS "Users can manage participants" ON public.meeting_participants;
DROP POLICY IF EXISTS "Users can update own attendance" ON public.meeting_participants;
DROP POLICY IF EXISTS "Organizer can remove participants" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_select" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_insert" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_update" ON public.meeting_participants;
DROP POLICY IF EXISTS "mp_delete" ON public.meeting_participants;

-- ─── meeting_documents ───
DROP POLICY IF EXISTS "Project members can view documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "Users can upload documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "Uploader/organizer can update documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "Uploader/organizer can delete documents" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_select" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_insert" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_update" ON public.meeting_documents;
DROP POLICY IF EXISTS "md_delete" ON public.meeting_documents;

-- ─── meeting_agenda ───
DROP POLICY IF EXISTS "Project members can view agenda" ON public.meeting_agenda;
DROP POLICY IF EXISTS "Organizer can manage agenda" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_select" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_insert" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_update" ON public.meeting_agenda;
DROP POLICY IF EXISTS "ma_delete" ON public.meeting_agenda;

-- ─── meeting_timeline ───
DROP POLICY IF EXISTS "Project members can view timeline" ON public.meeting_timeline;
DROP POLICY IF EXISTS "Organizer can manage timeline" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_select" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_insert" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_update" ON public.meeting_timeline;
DROP POLICY IF EXISTS "mt_delete" ON public.meeting_timeline;

-- ─── memos ───
DROP POLICY IF EXISTS "memos_select" ON public.memos;
DROP POLICY IF EXISTS "memos_insert" ON public.memos;
DROP POLICY IF EXISTS "memos_update" ON public.memos;
DROP POLICY IF EXISTS "memos_delete" ON public.memos;

-- ─── file_attachments ───
DROP POLICY IF EXISTS "file_attachments_select" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_insert" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_update" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_delete" ON public.file_attachments;
DROP POLICY IF EXISTS "Authenticated users can view files" ON public.file_attachments;
DROP POLICY IF EXISTS "Authenticated users can upload files" ON public.file_attachments;
DROP POLICY IF EXISTS "Uploader or admin can update files" ON public.file_attachments;
DROP POLICY IF EXISTS "Uploader or admin can delete files" ON public.file_attachments;


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PART 3: 모든 RLS 정책 재생성                                 ║
-- ╚══════════════════════════════════════════════════════════════╝


-- ━━━━━━━━━━ profiles ━━━━━━━━━━
-- SELECT: 모든 인증 사용자 (담당자 표시 등)
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (true);

-- INSERT: 본인 프로필만 (회원가입 트리거 보조)
CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- UPDATE: 본인 또는 admin
CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id OR public.is_admin());


-- ━━━━━━━━━━ project_members (재귀 방지: 서브쿼리 없이 단순화) ━━━━━━━━━━
-- SELECT: 본인 멤버십만 조회 (재귀 체인 차단!) + admin
CREATE POLICY "pm_select" ON public.project_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_admin()
  );

-- INSERT: 과제 소유자 또는 admin
CREATE POLICY "pm_insert" ON public.project_members
  FOR INSERT WITH CHECK (
    public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

-- DELETE: 본인 탈퇴 + 과제 소유자 + admin
CREATE POLICY "pm_delete" ON public.project_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );


-- ━━━━━━━━━━ projects ━━━━━━━━━━
-- SELECT: 소유자 + 멤버 + admin
CREATE POLICY "projects_select" ON public.projects
  FOR SELECT USING (
    public.is_admin()
    OR owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
  );

-- INSERT: 인증 사용자 (본인이 owner)
CREATE POLICY "projects_insert" ON public.projects
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- UPDATE: 소유자 + 과제 admin + 사이트 admin
CREATE POLICY "projects_update" ON public.projects
  FOR UPDATE USING (
    public.is_admin()
    OR owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

-- DELETE: 소유자 + 사이트 admin
CREATE POLICY "projects_delete" ON public.projects
  FOR DELETE USING (
    public.is_admin()
    OR owner_id = auth.uid()
  );


-- ━━━━━━━━━━ tasks (독립 태스크 완전 지원) ━━━━━━━━━━
-- SELECT: 과제 멤버 태스크 + 독립 태스크(본인) + admin
CREATE POLICY "tasks_select" ON public.tasks
  FOR SELECT USING (
    public.is_admin()
    OR (
      project_id IS NOT NULL AND (
        project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
      )
    )
    OR (project_id IS NULL AND assignee_id = auth.uid())
  );

-- INSERT: 과제 멤버 + 독립 태스크(본인) + admin
CREATE POLICY "tasks_insert" ON public.tasks
  FOR INSERT WITH CHECK (
    public.is_admin()
    OR (
      project_id IS NOT NULL AND (
        project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
      )
    )
    OR (project_id IS NULL AND assignee_id = auth.uid())
  );

-- UPDATE: 과제 멤버 + 독립 태스크(본인) + admin
CREATE POLICY "tasks_update" ON public.tasks
  FOR UPDATE USING (
    public.is_admin()
    OR (
      project_id IS NOT NULL AND (
        project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
      )
    )
    OR (project_id IS NULL AND assignee_id = auth.uid())
  );

-- DELETE: 과제 소유자/admin + 독립 태스크(본인) + admin
CREATE POLICY "tasks_delete" ON public.tasks
  FOR DELETE USING (
    public.is_admin()
    OR (
      project_id IS NOT NULL AND (
        project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
        OR project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
        )
      )
    )
    OR (project_id IS NULL AND assignee_id = auth.uid())
  );


-- ━━━━━━━━━━ daily_logs (독립 태스크 포함) ━━━━━━━━━━
-- SELECT: 과제 멤버 태스크 + 독립 태스크 본인 + admin
CREATE POLICY "daily_logs_select" ON public.daily_logs
  FOR SELECT USING (
    public.is_admin()
    OR author_id = auth.uid()
    OR task_id IN (
      SELECT id FROM public.tasks WHERE
        project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
    )
  );

CREATE POLICY "daily_logs_insert" ON public.daily_logs
  FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "daily_logs_update" ON public.daily_logs
  FOR UPDATE USING (public.is_admin() OR author_id = auth.uid());

CREATE POLICY "daily_logs_delete" ON public.daily_logs
  FOR DELETE USING (public.is_admin() OR author_id = auth.uid());


-- ━━━━━━━━━━ task_comments (독립 태스크 포함) ━━━━━━━━━━
CREATE POLICY "task_comments_select" ON public.task_comments
  FOR SELECT USING (
    public.is_admin()
    OR author_id = auth.uid()
    OR task_id IN (
      SELECT id FROM public.tasks WHERE
        project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
    )
  );

CREATE POLICY "task_comments_insert" ON public.task_comments
  FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY "task_comments_update" ON public.task_comments
  FOR UPDATE USING (public.is_admin() OR author_id = auth.uid());

CREATE POLICY "task_comments_delete" ON public.task_comments
  FOR DELETE USING (public.is_admin() OR author_id = auth.uid());


-- ━━━━━━━━━━ meetings ━━━━━━━━━━
-- SELECT: 생성자 + 과제 멤버 + admin
CREATE POLICY "meetings_select" ON public.meetings
  FOR SELECT USING (
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

-- INSERT: 인증 사용자 (본인이 creator)
CREATE POLICY "meetings_insert" ON public.meetings
  FOR INSERT WITH CHECK (
    public.is_admin() OR creator_id = auth.uid()
  );

-- UPDATE: 생성자 + 과제 소유자 + admin
CREATE POLICY "meetings_update" ON public.meetings
  FOR UPDATE USING (
    public.is_admin()
    OR creator_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

-- DELETE: 생성자 + 과제 소유자 + admin
CREATE POLICY "meetings_delete" ON public.meetings
  FOR DELETE USING (
    public.is_admin()
    OR creator_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );


-- ━━━━━━━━━━ meeting_participants ━━━━━━━━━━
CREATE POLICY "mp_select" ON public.meeting_participants
  FOR SELECT USING (
    public.is_admin()
    OR user_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        creator_id = auth.uid()
        OR project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
    )
  );

CREATE POLICY "mp_insert" ON public.meeting_participants
  FOR INSERT WITH CHECK (
    public.is_admin()
    OR user_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

CREATE POLICY "mp_update" ON public.meeting_participants
  FOR UPDATE USING (
    public.is_admin()
    OR user_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

CREATE POLICY "mp_delete" ON public.meeting_participants
  FOR DELETE USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );


-- ━━━━━━━━━━ meeting_documents ━━━━━━━━━━
CREATE POLICY "md_select" ON public.meeting_documents
  FOR SELECT USING (
    public.is_admin()
    OR uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        creator_id = auth.uid()
        OR project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
    )
  );

CREATE POLICY "md_insert" ON public.meeting_documents
  FOR INSERT WITH CHECK (
    public.is_admin() OR uploader_id = auth.uid()
  );

CREATE POLICY "md_update" ON public.meeting_documents
  FOR UPDATE USING (
    public.is_admin()
    OR uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

CREATE POLICY "md_delete" ON public.meeting_documents
  FOR DELETE USING (
    public.is_admin()
    OR uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );


-- ━━━━━━━━━━ meeting_agenda ━━━━━━━━━━
CREATE POLICY "ma_select" ON public.meeting_agenda
  FOR SELECT USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        creator_id = auth.uid()
        OR project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
    )
  );

CREATE POLICY "ma_insert" ON public.meeting_agenda
  FOR INSERT WITH CHECK (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
    )
  );

CREATE POLICY "ma_update" ON public.meeting_agenda
  FOR UPDATE USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
    )
  );

CREATE POLICY "ma_delete" ON public.meeting_agenda
  FOR DELETE USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
    )
  );


-- ━━━━━━━━━━ meeting_timeline ━━━━━━━━━━
CREATE POLICY "mt_select" ON public.meeting_timeline
  FOR SELECT USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        creator_id = auth.uid()
        OR project_id IN (
          SELECT project_id FROM public.project_members
          WHERE user_id = auth.uid()
        )
        OR project_id IN (
          SELECT id FROM public.projects WHERE owner_id = auth.uid()
        )
    )
  );

CREATE POLICY "mt_insert" ON public.meeting_timeline
  FOR INSERT WITH CHECK (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
    )
  );

CREATE POLICY "mt_update" ON public.meeting_timeline
  FOR UPDATE USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
    )
  );

CREATE POLICY "mt_delete" ON public.meeting_timeline
  FOR DELETE USING (
    public.is_admin()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE
        project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid())
    )
  );


-- ━━━━━━━━━━ memos (완전 개인 — admin도 타인 접근 불가) ━━━━━━━━━━
CREATE POLICY "memos_select" ON public.memos
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "memos_insert" ON public.memos
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "memos_update" ON public.memos
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "memos_delete" ON public.memos
  FOR DELETE USING (user_id = auth.uid());


-- ━━━━━━━━━━ file_attachments ━━━━━━━━━━
-- SELECT: 인증된 사용자 전부
CREATE POLICY "file_attachments_select" ON public.file_attachments
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- INSERT: 업로더 본인
CREATE POLICY "file_attachments_insert" ON public.file_attachments
  FOR INSERT WITH CHECK (auth.uid() = uploader_id);

-- UPDATE: 업로더 또는 admin
CREATE POLICY "file_attachments_update" ON public.file_attachments
  FOR UPDATE USING (
    auth.uid() = uploader_id OR public.is_admin()
  );

-- DELETE: 업로더 또는 admin
CREATE POLICY "file_attachments_delete" ON public.file_attachments
  FOR DELETE USING (
    auth.uid() = uploader_id OR public.is_admin()
  );


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  완료! 모든 테이블의 RLS가 정리되었습니다.                      ║
-- ╚══════════════════════════════════════════════════════════════╝
