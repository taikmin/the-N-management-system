-- Rollback 024: 활동 요약 이메일 cron 제거
SELECT cron.unschedule('activity-digest')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'activity-digest'
);
DROP FUNCTION IF EXISTS send_activity_digest();
