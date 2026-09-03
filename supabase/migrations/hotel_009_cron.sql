-- ============================================================
-- Hotel Migration 009: pg_cron 잡 등록
-- ============================================================
-- 필요 확장: pg_cron, pg_net
-- ============================================================

-- 확장 활성화 (이미 있으면 스킵)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 기존 잡 삭제 (재실행 시 중복 방지)
DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'hotel_daily_digest';
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'hotel_generate_recurring';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'unschedule skipped: %', SQLERRM;
END$$;

-- 1. 매시간 정각: send_daily_digest 체크
--    함수 내부에서 설정된 시각과 일치할 때만 실제 발송
SELECT cron.schedule(
  'hotel_daily_digest',
  '0 * * * *',
  $$SELECT public.send_daily_digest();$$
);

-- 2. 매일 KST 자정: 반복 업무 인스턴스 생성
--    UTC 15:00 = KST 00:00
SELECT cron.schedule(
  'hotel_generate_recurring',
  '0 15 * * *',
  $$SELECT public.generate_recurring_tasks();$$
);

-- 확인:
--   SELECT jobname, schedule, command FROM cron.job WHERE jobname LIKE 'hotel_%';

-- ============================================================
-- ROLLBACK
-- ============================================================
-- SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname IN ('hotel_daily_digest', 'hotel_generate_recurring');
