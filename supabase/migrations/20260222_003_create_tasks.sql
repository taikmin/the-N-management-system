-- ============================================================
-- Migration: tasks 테이블 (업무/태스크)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  parent_task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL, -- 자기참조 FK (하위태스크)
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned', 'in_progress', 'delayed', 'completed', 'blocked')),
  priority TEXT NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  plan_type TEXT NOT NULL DEFAULT 'A'
    CHECK (plan_type IN ('A', 'B', 'C')),            -- Plan 유형
  assignee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  planned_start DATE,
  planned_end DATE,
  actual_start DATE,
  actual_end DATE,
  order_index INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_project_id ON public.tasks(project_id);
CREATE INDEX idx_tasks_assignee_id ON public.tasks(assignee_id);
CREATE INDEX idx_tasks_status ON public.tasks(status);
CREATE INDEX idx_tasks_parent_task_id ON public.tasks(parent_task_id);
CREATE INDEX idx_tasks_plan_type ON public.tasks(plan_type);

CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- RLS
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- 태스크 조회: 과제 멤버
CREATE POLICY "Project members can view tasks"
  ON public.tasks FOR SELECT
  USING (
    project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
    OR project_id IN (
      SELECT id FROM public.projects
      WHERE owner_id = auth.uid()
    )
  );

-- 태스크 생성: 과제 멤버
CREATE POLICY "Project members can create tasks"
  ON public.tasks FOR INSERT
  WITH CHECK (
    project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
    OR project_id IN (
      SELECT id FROM public.projects
      WHERE owner_id = auth.uid()
    )
  );

-- 태스크 수정: 과제 멤버
CREATE POLICY "Project members can update tasks"
  ON public.tasks FOR UPDATE
  USING (
    project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
    OR project_id IN (
      SELECT id FROM public.projects
      WHERE owner_id = auth.uid()
    )
  );

-- 태스크 삭제: owner/admin 또는 생성자
CREATE POLICY "Project owner/admin can delete tasks"
  ON public.tasks FOR DELETE
  USING (
    project_id IN (
      SELECT id FROM public.projects
      WHERE owner_id = auth.uid()
    )
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );
