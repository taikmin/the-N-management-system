-- ============================================
-- ROLLBACK: 010 회의 비대면/하이브리드 모드
-- 주의: 이 파일은 자동 실행되지 않습니다.
-- 롤백이 필요한 경우에만 수동으로 실행하세요.
-- ============================================

-- meetings 테이블 컬럼 제거
ALTER TABLE public.meetings DROP COLUMN IF EXISTS meeting_mode;
ALTER TABLE public.meetings DROP COLUMN IF EXISTS online_platform;
ALTER TABLE public.meetings DROP COLUMN IF EXISTS online_link;
ALTER TABLE public.meetings DROP COLUMN IF EXISTS online_meeting_id;
ALTER TABLE public.meetings DROP COLUMN IF EXISTS online_password;

-- profiles 테이블 Zoom 기본값 컬럼 제거
ALTER TABLE public.profiles DROP COLUMN IF EXISTS default_zoom_link;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS default_zoom_id;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS default_zoom_password;
