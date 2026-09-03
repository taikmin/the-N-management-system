-- 019: 캘린더 표시 기본값 false로 변경 + 기존 데이터 초기화
-- tasks: show_in_calendar DEFAULT false로 변경 + 기존 모두 false
ALTER TABLE public.tasks ALTER COLUMN show_in_calendar SET DEFAULT false;
UPDATE public.tasks SET show_in_calendar = false WHERE show_in_calendar = true;

-- projects: show_in_calendar 컬럼 추가 (DEFAULT false)
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS show_in_calendar BOOLEAN DEFAULT false;
