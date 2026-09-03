-- =====================================================================
-- Migration 026: projects 테이블에 assignee_id + show_in_calendar 추가
--
-- 배경:
--   Flutter 코드(lib/features/projects/data/repositories/project_repository.dart)는
--   projects.assignee_id (FK to profiles) 및 projects.show_in_calendar 컬럼을
--   기대하지만 원본 마이그레이션 001~025에는 정의가 없어 다음 에러 발생:
--     PostgrestException: Could not find a relationship between 'projects'
--     and 'profiles' in the schema cache (hint: 'projects_assignee_id_fkey')
--
-- 변경:
--   - assignee_id UUID (FK to profiles, ON DELETE SET NULL)
--   - show_in_calendar BOOLEAN NOT NULL DEFAULT false
--   - assignee_id 인덱스 추가
--   - PostgREST 스키마 캐시 재로딩
-- =====================================================================

ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS assignee_id UUID
    REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS show_in_calendar BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_projects_assignee_id
  ON public.projects(assignee_id);

NOTIFY pgrst, 'reload schema';
