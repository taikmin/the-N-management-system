-- Migration 016: 연계 업무 (task_updates) 테이블 + 색상 태그 (color_tag)
-- 실행: Supabase Dashboard → SQL Editor

-- ─── 1. tasks 테이블에 color_tag 컬럼 추가 ───
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS color_tag TEXT NOT NULL DEFAULT 'none'
  CHECK (color_tag IN ('red', 'yellow', 'blue', 'none'));

-- ─── 2. task_updates 테이블 생성 ───
CREATE TABLE IF NOT EXISTS public.task_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_task_updates_task_id
  ON public.task_updates(task_id);
CREATE INDEX IF NOT EXISTS idx_task_updates_created_at
  ON public.task_updates(task_id, created_at);

-- ─── 3. task_updates RLS ───
ALTER TABLE public.task_updates ENABLE ROW LEVEL SECURITY;

-- SELECT: 인증 사용자 전체
CREATE POLICY "task_updates_select" ON public.task_updates
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- INSERT: 인증 사용자
CREATE POLICY "task_updates_insert" ON public.task_updates
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- UPDATE: 인증 사용자
CREATE POLICY "task_updates_update" ON public.task_updates
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- DELETE: Admin만
CREATE POLICY "task_updates_delete" ON public.task_updates
  FOR DELETE USING (public.is_admin());

-- ─── 4. updated_at 트리거 (task_updates는 수정 불가이므로 생략) ───
