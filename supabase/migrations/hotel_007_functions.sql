-- ============================================================
-- Hotel Migration 007: 함수 및 트리거
-- ============================================================
-- - handle_new_user() : 가입 시 profiles 자동 생성 (기본 role='staff')
-- - is_admin() : RLS 헬퍼 (관리자 또는 대표 판정)
-- - log_activity() : tasks/departments/memos 변경 시 로깅
-- - send_daily_digest() : 매일 지정 시각에 대표에게 요약 이메일
-- - generate_recurring_tasks() : 매일 자정, 반복 템플릿에서 인스턴스 생성
-- ============================================================

-- ============================================================
-- 1. handle_new_user — auth.users 가입 시 profiles 생성
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_admin)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    'staff',
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. is_admin — RLS에서 사용할 헬퍼
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin OR role IN ('ceo', 'manager')
     FROM public.profiles WHERE id = user_id),
    false
  );
$$;

-- ============================================================
-- 3. log_activity — 트리거로 변경 시 activity_logs에 기록
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_name TEXT;
  v_action TEXT;
  v_entity_id UUID;
  v_entity_title TEXT;
  v_details JSONB;
BEGIN
  v_user_id := auth.uid();
  SELECT full_name INTO v_user_name FROM public.profiles WHERE id = v_user_id;

  IF TG_OP = 'INSERT' THEN
    v_action := 'create';
    v_entity_id := NEW.id;
    v_entity_title := COALESCE(NEW.title, '(제목 없음)');
  ELSIF TG_OP = 'UPDATE' THEN
    -- status가 completed로 변경된 경우 'complete'로 로깅
    IF TG_TABLE_NAME = 'tasks' AND NEW.status = 'completed' AND OLD.status != 'completed' THEN
      v_action := 'complete';
    ELSE
      v_action := 'update';
    END IF;
    v_entity_id := NEW.id;
    v_entity_title := COALESCE(NEW.title, '(제목 없음)');
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'delete';
    v_entity_id := OLD.id;
    v_entity_title := COALESCE(OLD.title, '(제목 없음)');
  END IF;

  -- 부서명 등 부가 정보
  IF TG_TABLE_NAME = 'tasks' AND TG_OP != 'DELETE' AND NEW.department_id IS NOT NULL THEN
    v_details := jsonb_build_object(
      'department_name',
      (SELECT name FROM public.departments WHERE id = NEW.department_id)
    );
  END IF;

  INSERT INTO public.activity_logs (
    user_id, user_name, action, entity_type, entity_id, entity_title, details
  )
  VALUES (
    v_user_id, v_user_name, v_action, TG_TABLE_NAME, v_entity_id, v_entity_title, v_details
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- 트리거 부착
DROP TRIGGER IF EXISTS log_activity_tasks ON public.tasks;
CREATE TRIGGER log_activity_tasks
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

DROP TRIGGER IF EXISTS log_activity_departments ON public.departments;
CREATE TRIGGER log_activity_departments
  AFTER INSERT OR UPDATE OR DELETE ON public.departments
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

DROP TRIGGER IF EXISTS log_activity_memos ON public.memos;
CREATE TRIGGER log_activity_memos
  AFTER INSERT OR UPDATE OR DELETE ON public.memos
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

-- ============================================================
-- 4. send_daily_digest — 매일 지정 시각에 대표에게 이메일
-- ============================================================
-- cron은 매시 정각(0 * * * *)에 실행 → 함수가 현재 시각과 app_settings의
-- digest_send_hour(KST)를 비교해 일치할 때만 실제 발송.
-- ============================================================
CREATE OR REPLACE FUNCTION public.send_daily_digest()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_settings RECORD;
  v_current_hour INT;
  v_recipients JSONB;
  v_html TEXT;
  v_completed_count INT;
  v_incomplete_count INT;
  v_delayed_count INT;
  v_pending_count INT;
  v_today DATE;
  v_dept RECORD;
  v_task RECORD;
  v_dept_section TEXT;
  v_incomplete_section TEXT;
BEGIN
  -- 설정 조회
  SELECT * INTO v_settings FROM public.app_settings WHERE id = 1;
  IF v_settings IS NULL THEN
    RAISE NOTICE 'No app_settings row.';
    RETURN;
  END IF;

  -- 현재 KST 시각의 시(hour)
  v_current_hour := EXTRACT(HOUR FROM (NOW() AT TIME ZONE v_settings.digest_timezone));

  -- 발송 시각과 일치하지 않으면 스킵
  IF v_current_hour != v_settings.digest_send_hour THEN
    RETURN;
  END IF;

  -- 수신자 조회
  SELECT jsonb_agg(email) INTO v_recipients
  FROM public.digest_recipients
  WHERE is_active = true;

  IF v_recipients IS NULL OR jsonb_array_length(v_recipients) = 0 THEN
    RAISE NOTICE 'No active digest recipients.';
    RETURN;
  END IF;

  v_today := (NOW() AT TIME ZONE v_settings.digest_timezone)::DATE;

  -- 오늘의 통계
  SELECT count(*) INTO v_completed_count
    FROM public.tasks
    WHERE (completed_at AT TIME ZONE v_settings.digest_timezone)::DATE = v_today;

  SELECT count(*) INTO v_incomplete_count
    FROM public.tasks
    WHERE status = 'incomplete'
      AND due_date = v_today;

  SELECT count(*) INTO v_delayed_count
    FROM public.tasks
    WHERE status = 'delayed'
      AND due_date <= v_today;

  SELECT count(*) INTO v_pending_count
    FROM public.tasks
    WHERE status IN ('assigned', 'in_progress')
      AND due_date = v_today;

  -- HTML 조립
  v_html := '<div style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:20px;">'
    || '<h2 style="color:#0ABAB5;border-bottom:2px solid #0ABAB5;padding-bottom:8px;">The N Resort 일일 업무 요약</h2>'
    || '<p style="color:#666;font-size:13px;">'
    || to_char(v_today, 'YYYY.MM.DD') || ' 기준</p>'
    || '<div style="display:flex;gap:12px;flex-wrap:wrap;margin:16px 0;">'
    || '<div style="flex:1;min-width:120px;padding:12px;background:#E0F7F5;border-radius:8px;">'
    ||   '<div style="font-size:24px;font-weight:bold;color:#0ABAB5;">' || v_completed_count || '</div>'
    ||   '<div style="font-size:12px;color:#555;">✅ 완료</div>'
    || '</div>'
    || '<div style="flex:1;min-width:120px;padding:12px;background:#FFF3E0;border-radius:8px;">'
    ||   '<div style="font-size:24px;font-weight:bold;color:#FF9800;">' || v_pending_count || '</div>'
    ||   '<div style="font-size:12px;color:#555;">⏳ 진행 중</div>'
    || '</div>'
    || '<div style="flex:1;min-width:120px;padding:12px;background:#FFEBEE;border-radius:8px;">'
    ||   '<div style="font-size:24px;font-weight:bold;color:#E53935;">' || v_incomplete_count || '</div>'
    ||   '<div style="font-size:12px;color:#555;">❌ 미완료</div>'
    || '</div>'
    || '<div style="flex:1;min-width:120px;padding:12px;background:#FFEBEE;border-radius:8px;">'
    ||   '<div style="font-size:24px;font-weight:bold;color:#E53935;">' || v_delayed_count || '</div>'
    ||   '<div style="font-size:12px;color:#555;">🕒 지연</div>'
    || '</div>'
    || '</div>';

  -- 부서별 완료율
  v_dept_section := '<h3 style="margin-top:24px;color:#333;">부서별 오늘 완료율</h3>'
    || '<table style="width:100%;border-collapse:collapse;font-size:14px;">'
    || '<thead><tr style="background:#F5F5F5;">'
    || '<th style="text-align:left;padding:8px;border-bottom:1px solid #DDD;">부서</th>'
    || '<th style="text-align:right;padding:8px;border-bottom:1px solid #DDD;">전체</th>'
    || '<th style="text-align:right;padding:8px;border-bottom:1px solid #DDD;">완료</th>'
    || '<th style="text-align:right;padding:8px;border-bottom:1px solid #DDD;">완료율</th>'
    || '</tr></thead><tbody>';

  FOR v_dept IN
    SELECT
      d.name,
      count(t.id) AS total,
      count(t.id) FILTER (WHERE t.status = 'completed') AS completed
    FROM public.departments d
    LEFT JOIN public.tasks t ON t.department_id = d.id AND t.due_date = v_today
    GROUP BY d.id, d.name
    ORDER BY d.sort_order
  LOOP
    v_dept_section := v_dept_section
      || '<tr>'
      || '<td style="padding:8px;border-bottom:1px solid #EEE;">' || v_dept.name || '</td>'
      || '<td style="text-align:right;padding:8px;border-bottom:1px solid #EEE;">' || v_dept.total || '</td>'
      || '<td style="text-align:right;padding:8px;border-bottom:1px solid #EEE;">' || v_dept.completed || '</td>'
      || '<td style="text-align:right;padding:8px;border-bottom:1px solid #EEE;">'
      ||   CASE WHEN v_dept.total > 0
             THEN round((v_dept.completed::numeric / v_dept.total) * 100) || '%'
             ELSE '-' END
      || '</td>'
      || '</tr>';
  END LOOP;
  v_dept_section := v_dept_section || '</tbody></table>';
  v_html := v_html || v_dept_section;

  -- 미완료/지연 업무 상세
  IF (v_incomplete_count + v_delayed_count) > 0 THEN
    v_incomplete_section := '<h3 style="margin-top:24px;color:#E53935;">주의: 미완료/지연 업무</h3><ul style="padding-left:20px;font-size:14px;">';
    FOR v_task IN
      SELECT
        t.title, t.status, t.delay_reason,
        p.full_name AS assignee_name,
        d.name AS department_name
      FROM public.tasks t
      LEFT JOIN public.profiles p ON p.id = t.assignee_id
      LEFT JOIN public.departments d ON d.id = t.department_id
      WHERE (t.status = 'incomplete' AND t.due_date = v_today)
         OR (t.status = 'delayed' AND t.due_date <= v_today)
      ORDER BY t.due_date, t.priority DESC
      LIMIT 20
    LOOP
      v_incomplete_section := v_incomplete_section
        || '<li style="margin-bottom:6px;"><strong>' || v_task.title || '</strong>'
        || ' — ' || COALESCE(v_task.department_name, '(부서 없음)')
        || ' / ' || COALESCE(v_task.assignee_name, '(담당자 없음)')
        || ' <span style="color:#999;font-size:12px;">(' || v_task.status || ')</span>'
        || CASE WHEN v_task.delay_reason IS NOT NULL
             THEN '<br><span style="color:#666;font-size:13px;">사유: ' || v_task.delay_reason || '</span>'
             ELSE '' END
        || '</li>';
    END LOOP;
    v_incomplete_section := v_incomplete_section || '</ul>';
    v_html := v_html || v_incomplete_section;
  END IF;

  v_html := v_html
    || '<hr style="border:none;border-top:1px solid #EEE;margin-top:32px;">'
    || '<p style="color:#999;font-size:11px;">The N Resort Management · 자동 발송</p>'
    || '</div>';

  -- Resend API 호출
  PERFORM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR_RESEND_API_KEY_HERE',
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', 'The N Resort <onboarding@resend.dev>',
      'to', v_recipients,
      'subject', '[The N Resort] ' || to_char(v_today, 'MM.DD') || ' 일일 요약',
      'html', v_html
    )
  );
END;
$$;

-- ============================================================
-- 5. generate_recurring_tasks — 반복 템플릿에서 오늘자 인스턴스 생성
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_recurring_tasks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE;
  v_dow TEXT;  -- day of week 소문자 3자
  v_dom INT;   -- day of month
  v_template RECORD;
  v_should_create BOOLEAN;
  v_parts TEXT[];
  v_pattern_type TEXT;
  v_pattern_arg TEXT;
BEGIN
  v_today := (NOW() AT TIME ZONE 'Asia/Seoul')::DATE;
  v_dow := lower(to_char(v_today, 'dy'));  -- mon, tue, wed, ...
  v_dom := EXTRACT(DAY FROM v_today);

  FOR v_template IN
    SELECT * FROM public.tasks
    WHERE recurrence_pattern IS NOT NULL
      AND recurrence_template_id IS NULL  -- 템플릿만
  LOOP
    v_should_create := false;

    -- 패턴 파싱
    v_parts := string_to_array(v_template.recurrence_pattern, ':');
    v_pattern_type := v_parts[1];
    v_pattern_arg := COALESCE(v_parts[2], '');

    IF v_pattern_type = 'daily' THEN
      v_should_create := true;
    ELSIF v_pattern_type = 'weekly' THEN
      -- v_pattern_arg 예: 'mon,wed,fri'
      IF v_dow = ANY(string_to_array(v_pattern_arg, ',')) THEN
        v_should_create := true;
      END IF;
    ELSIF v_pattern_type = 'monthly' THEN
      -- v_pattern_arg 예: '1,15'
      IF v_dom::TEXT = ANY(string_to_array(v_pattern_arg, ',')) THEN
        v_should_create := true;
      END IF;
    END IF;

    IF v_should_create THEN
      -- 오늘 이미 생성되었는지 확인
      IF NOT EXISTS (
        SELECT 1 FROM public.tasks
        WHERE recurrence_template_id = v_template.id
          AND due_date = v_today
      ) THEN
        INSERT INTO public.tasks (
          title, description, department_id, assigner_id, assignee_id,
          category, priority, status, due_date, due_time, show_in_calendar,
          recurrence_template_id
        )
        VALUES (
          v_template.title,
          v_template.description,
          v_template.department_id,
          v_template.assigner_id,
          v_template.assignee_id,
          v_template.category,
          v_template.priority,
          'assigned',
          v_today,
          v_template.due_time,
          v_template.show_in_calendar,
          v_template.id
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- ============================================================
-- ⚠️ 실행 후 필수: send_daily_digest 함수의 Resend 키 교체
-- ============================================================
-- 함수 정의 안의 'Bearer YOUR_RESEND_API_KEY_HERE' 부분을
-- Supabase Dashboard → Database → Functions → send_daily_digest → Edit
-- 에서 실제 키로 치환하거나, 아래 스크립트 사용:
--
-- Supabase SQL Editor에서:
--   ALTER FUNCTION public.send_daily_digest() ... (재정의)
-- 또는 Dashboard UI에서 함수 body의 해당 부분만 수정.
--
-- 더 안전한 방법: Supabase Vault 또는 pg_settings 사용 (향후 개선 항목)
-- ============================================================
