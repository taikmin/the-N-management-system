-- ============================================================
-- Hotel Migration 004: 앱 설정 + 다이제스트 수신자
-- ============================================================

-- 1. app_settings (singleton)
CREATE TABLE IF NOT EXISTS public.app_settings (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  digest_send_hour INT NOT NULL DEFAULT 18 CHECK (digest_send_hour BETWEEN 0 AND 23),
  -- 정시 단위(0~23시). Cron이 매시간 정각 실행되며 이 시각과 일치할 때만 발송
  digest_timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- 초기 row 삽입 (id=1 하나만 존재)
INSERT INTO public.app_settings (id, digest_send_hour, digest_timezone)
VALUES (1, 18, 'Asia/Seoul')
ON CONFLICT (id) DO NOTHING;

-- 2. digest_recipients
CREATE TABLE IF NOT EXISTS public.digest_recipients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  label TEXT,  -- 예: '대표', '경영지원팀장'
  is_active BOOL NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_digest_recipients_active
  ON public.digest_recipients(is_active) WHERE is_active = true;

-- 3. updated_at 트리거
DROP TRIGGER IF EXISTS app_settings_updated_at ON public.app_settings;
CREATE TRIGGER app_settings_updated_at
  BEFORE UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS digest_recipients_updated_at ON public.digest_recipients;
CREATE TRIGGER digest_recipients_updated_at
  BEFORE UPDATE ON public.digest_recipients
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 4. 초기 수신자 (원한다면 관리자 이메일 하나 seed)
-- INSERT INTO public.digest_recipients (email, label, is_active)
-- VALUES ('YOUR_CEO_EMAIL@example.com', '대표', true)
-- ON CONFLICT (email) DO NOTHING;
-- ↑ 위 라인은 사용자가 실제 대표 이메일로 교체 후 주석 해제하여 실행

-- ============================================================
-- ROLLBACK
-- ============================================================
-- DROP TABLE IF EXISTS public.digest_recipients CASCADE;
-- DROP TABLE IF EXISTS public.app_settings CASCADE;
