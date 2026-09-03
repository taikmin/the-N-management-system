-- ============================================================
-- Hotel Migration 006: R&D 레거시 테이블/함수/트리거 삭제
-- ============================================================
-- 위험: 실행 전 백업 권장. 다음 테이블의 데이터가 영구 삭제됨.
-- ============================================================

-- 1. 레거시 트리거 삭제 (테이블 삭제 전에)
DROP TRIGGER IF EXISTS log_activity_meetings ON public.meetings;
DROP TRIGGER IF EXISTS log_activity_projects ON public.projects;
DROP TRIGGER IF EXISTS log_activity_meeting_timeline ON public.meeting_timeline;

-- 2. 레거시 함수 삭제 (호텔용으로 재작성 예정)
DROP FUNCTION IF EXISTS public.send_activity_digest() CASCADE;

-- 3. 레거시 pg_cron 잡 삭제
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE command LIKE '%send_activity_digest%'
       OR jobname LIKE '%activity_digest%';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unschedule skipped: %', SQLERRM;
END$$;

-- 4. 레거시 테이블 DROP (외래 키 CASCADE)
DROP TABLE IF EXISTS public.meeting_timeline CASCADE;
DROP TABLE IF EXISTS public.meeting_agenda CASCADE;
DROP TABLE IF EXISTS public.meeting_documents CASCADE;
DROP TABLE IF EXISTS public.meeting_participants CASCADE;
DROP TABLE IF EXISTS public.meetings CASCADE;

DROP TABLE IF EXISTS public.task_updates CASCADE;
DROP TABLE IF EXISTS public.task_comments CASCADE;
DROP TABLE IF EXISTS public.daily_logs CASCADE;

DROP TABLE IF EXISTS public.project_members CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;

-- 5. profiles의 기존 department 문자열 컬럼 삭제
--    (hotel_001에서 department_id로 대체하기로 함)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS department;

-- ============================================================
-- ROLLBACK 불가 — 이 마이그레이션은 되돌릴 수 없음.
-- 반드시 실행 전 pg_dump로 백업.
-- ============================================================
