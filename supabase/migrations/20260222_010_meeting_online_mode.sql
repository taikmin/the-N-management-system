-- ============================================
-- 010: 회의 대면/비대면/하이브리드 모드
-- meetings 테이블에 온라인 관련 컬럼 추가
-- profiles 테이블에 Zoom 기본값 추가
-- ============================================

-- meetings 테이블에 온라인 모드 관련 컬럼 추가
ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS meeting_mode TEXT NOT NULL DEFAULT 'in_person'
    CHECK (meeting_mode IN ('in_person', 'online', 'hybrid'));

ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_platform TEXT;

ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_link TEXT;

ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_meeting_id TEXT;

ALTER TABLE public.meetings
  ADD COLUMN IF NOT EXISTS online_password TEXT;

-- profiles 테이블에 Zoom 기본값 추가
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS default_zoom_link TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS default_zoom_id TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS default_zoom_password TEXT;
