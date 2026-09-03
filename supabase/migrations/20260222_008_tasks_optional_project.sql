-- ============================================================
-- Migration: tasks 테이블 - 독립 태스크 지원
-- project_id를 nullable로 변경, category 필드 추가
-- RLS 정책 재생성 (project_id IS NULL 케이스 포함)
-- ============================================================

-- 1. project_id를 nullable로 변경
ALTER TABLE public.tasks ALTER COLUMN project_id DROP NOT NULL;

-- 2. 독립 태스크 카테고리 필드 추가
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS category TEXT;

-- 3. 기존 RLS 정책 DROP
DROP POLICY IF EXISTS "Project members can view tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project members can create tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project members can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Project owner/admin can delete tasks" ON public.tasks;

-- admin 마이그레이션(006)에서 생성된 정책도 DROP
DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;

-- 4. 새 RLS 정책 생성 (독립 태스크 + 과제 태스크 + 관리자)

-- SELECT: 과제 멤버 OR 독립 태스크 본인 OR 관리자
CREATE POLICY "tasks_select" ON public.tasks FOR SELECT USING (
  -- 과제 태스크: 멤버 또는 소유자
  (
    project_id IS NOT NULL AND (
      project_id IN (
        SELECT project_id FROM public.project_members
        WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects
        WHERE owner_id = auth.uid()
      )
    )
  )
  -- 독립 태스크: 본인 할당
  OR (project_id IS NULL AND assignee_id = auth.uid())
  -- 관리자
  OR public.is_admin()
);

-- INSERT: 과제 멤버 OR 독립 태스크 본인 OR 관리자
CREATE POLICY "tasks_insert" ON public.tasks FOR INSERT WITH CHECK (
  (
    project_id IS NOT NULL AND (
      project_id IN (
        SELECT project_id FROM public.project_members
        WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects
        WHERE owner_id = auth.uid()
      )
    )
  )
  OR (project_id IS NULL AND assignee_id = auth.uid())
  OR public.is_admin()
);

-- UPDATE: 과제 멤버 OR 독립 태스크 본인 OR 관리자
CREATE POLICY "tasks_update" ON public.tasks FOR UPDATE USING (
  (
    project_id IS NOT NULL AND (
      project_id IN (
        SELECT project_id FROM public.project_members
        WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects
        WHERE owner_id = auth.uid()
      )
    )
  )
  OR (project_id IS NULL AND assignee_id = auth.uid())
  OR public.is_admin()
);

-- DELETE: 과제 소유자/admin OR 독립 태스크 본인 OR 관리자
CREATE POLICY "tasks_delete" ON public.tasks FOR DELETE USING (
  (
    project_id IS NOT NULL AND (
      project_id IN (
        SELECT id FROM public.projects
        WHERE owner_id = auth.uid()
      )
      OR project_id IN (
        SELECT project_id FROM public.project_members
        WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
      )
    )
  )
  OR (project_id IS NULL AND assignee_id = auth.uid())
  OR public.is_admin()
);
