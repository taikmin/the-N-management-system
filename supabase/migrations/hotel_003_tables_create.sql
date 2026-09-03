-- ============================================================
-- Hotel Migration 003 (CREATE 버전) — 누락된 테이블 신규 생성
-- ============================================================
-- 이 프로젝트는 새로 만든 빈 프로젝트라 tasks/memos/activity_logs/
-- file_attachments가 존재하지 않음. 호텔 스키마로 처음부터 생성.
--
-- 이 파일은 기존 hotel_003_tasks_rebuild.sql을 대체합니다.
-- ============================================================

-- ============================================================
-- 1. tasks — 호텔 업무
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  assigner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  assignee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  category TEXT,
  priority TEXT NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  status TEXT NOT NULL DEFAULT 'assigned'
    CHECK (status IN ('assigned', 'in_progress', 'completed', 'incomplete', 'delayed')),
  due_date DATE,
  due_time TIME,
  completed_at TIMESTAMPTZ,
  completion_note TEXT,
  delay_reason TEXT,
  show_in_calendar BOOL NOT NULL DEFAULT true,
  recurrence_pattern TEXT,
    -- 형식: 'daily' | 'weekly:mon,wed,fri' | 'monthly:1,15'
  recurrence_template_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT tasks_delay_reason_required CHECK (
    (status NOT IN ('incomplete', 'delayed'))
    OR (delay_reason IS NOT NULL AND length(trim(delay_reason)) > 0)
  )
);

CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id ON public.tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigner_id ON public.tasks(assigner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_department_id ON public.tasks(department_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_recurrence_template_id ON public.tasks(recurrence_template_id);

DROP TRIGGER IF EXISTS tasks_updated_at ON public.tasks;
CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 2. memos — 개인 메모
-- ============================================================
CREATE TABLE IF NOT EXISTS public.memos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  category TEXT,
  priority TEXT DEFAULT 'none'
    CHECK (priority IN ('none', 'low', 'medium', 'high')),
  status TEXT DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  is_pinned BOOL NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_memos_user_id ON public.memos(user_id);
CREATE INDEX IF NOT EXISTS idx_memos_pinned ON public.memos(user_id, is_pinned);

DROP TRIGGER IF EXISTS memos_updated_at ON public.memos;
CREATE TRIGGER memos_updated_at
  BEFORE UPDATE ON public.memos
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 3. activity_logs — 활동 로그
-- ============================================================
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete', 'complete')),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('tasks', 'departments', 'memos')),
  entity_id UUID,
  entity_title TEXT,
  details JSONB,
  notified BOOL NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity ON public.activity_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_notified ON public.activity_logs(notified) WHERE notified = false;

-- ============================================================
-- 4. file_attachments — 파일 첨부 (polymorphic)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.file_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_name TEXT NOT NULL,
  file_size BIGINT,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  bucket_name TEXT NOT NULL,
  entity_type TEXT NOT NULL,  -- 예: 'tasks'
  entity_id UUID NOT NULL,
  uploader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_file_attachments_entity ON public.file_attachments(entity_type, entity_id);

-- ============================================================
-- 완료
-- ============================================================
-- 다음 단계: hotel_004_settings.sql (그대로 실행)
--          hotel_005, hotel_006은 스킵 (지울 R&D 테이블 없음)
--          hotel_007, hotel_008, hotel_009는 그대로 실행
-- ============================================================
