-- Migration 024: 활동 요약 이메일 (pg_net + pg_cron)
-- Edge Function 없이 PostgreSQL에서 직접 Resend API 호출
--
-- 사전 조건:
--   1. Supabase Dashboard → Database → Extensions → pg_cron 활성화
--   2. Supabase Dashboard → Database → Extensions → pg_net 활성화
--   3. Migration 023 (activity_logs 테이블 + 트리거) 실행 완료

-- ============================================================
-- 1. 이메일 발송 함수
-- ============================================================
CREATE OR REPLACE FUNCTION send_activity_digest()
RETURNS void AS $$
DECLARE
  v_count INT;
  v_html TEXT;
  v_section TEXT;
  v_items TEXT;
  v_rec RECORD;
  v_entity_types TEXT[] := ARRAY['tasks','projects','meetings','memos','meeting_timeline'];
  v_entity_labels TEXT[] := ARRAY['업무','과제','회의','메모','타임라인'];
  v_entity_emojis TEXT[] := ARRAY['📋','📁','🗓️','📝','⏱️'];
  v_action_emoji TEXT;
  v_action_label TEXT;
  v_time_str TEXT;
  v_now_str TEXT;
  v_idx INT;
  v_type TEXT;
  v_type_count INT;
  v_ids UUID[];
  v_parent_label TEXT;
BEGIN
  -- 미발송 레코드 수 확인
  SELECT count(*) INTO v_count
  FROM public.activity_logs
  WHERE notified = false;

  -- 변경사항 없으면 종료
  IF v_count = 0 THEN
    RAISE NOTICE 'No pending activities. Skipping digest.';
    RETURN;
  END IF;

  -- 현재 시간 (KST)
  v_now_str := to_char(now() AT TIME ZONE 'Asia/Seoul', 'YYYY.MM.DD HH24:MI');

  -- HTML 헤더
  v_html := '<div style="font-family:''Apple SD Gothic Neo'',''Malgun Gothic'',sans-serif;max-width:600px;margin:0 auto;padding:20px;">'
    || '<h2 style="color:#1565C0;border-bottom:2px solid #1565C0;padding-bottom:8px;">'
    || 'R&D Task Manager - 활동 요약</h2>'
    || '<p style="color:#666;font-size:13px;">'
    || v_now_str || ' 기준 · 총 ' || v_count || '건</p>';

  -- 엔티티별 섹션 생성
  FOR v_idx IN 1..array_length(v_entity_types, 1) LOOP
    v_type := v_entity_types[v_idx];

    SELECT count(*) INTO v_type_count
    FROM public.activity_logs
    WHERE notified = false AND entity_type = v_type;

    IF v_type_count = 0 THEN
      CONTINUE;
    END IF;

    v_section := '<h3 style="color:#333;margin-top:20px;">'
      || v_entity_emojis[v_idx] || ' ' || v_entity_labels[v_idx]
      || ' 변경 (' || v_type_count || '건)</h3>'
      || '<ul style="list-style:none;padding:0;">';

    FOR v_rec IN
      SELECT user_name, action, entity_title, details, created_at
      FROM public.activity_logs
      WHERE notified = false AND entity_type = v_type
      ORDER BY created_at DESC
    LOOP
      -- 액션 이모지
      CASE v_rec.action
        WHEN 'create' THEN v_action_emoji := '➕'; v_action_label := '생성';
        WHEN 'update' THEN v_action_emoji := '✏️'; v_action_label := '수정';
        WHEN 'delete' THEN v_action_emoji := '🗑️'; v_action_label := '삭제';
        WHEN 'complete' THEN v_action_emoji := '✅'; v_action_label := '완료';
        ELSE v_action_emoji := '•'; v_action_label := v_rec.action;
      END CASE;

      v_time_str := to_char(
        v_rec.created_at AT TIME ZONE 'Asia/Seoul',
        'HH24:MI'
      );

      -- 연계업무 부모 표시
      v_parent_label := '';
      IF v_rec.details IS NOT NULL AND v_rec.details ? 'parent_task_title' THEN
        v_parent_label := ' <span style="color:#1565C0;font-size:12px;">(상위: '
          || (v_rec.details->>'parent_task_title')
          || ')</span>';
      END IF;

      v_section := v_section
        || '<li style="padding:6px 0;border-bottom:1px solid #f0f0f0;font-size:14px;">'
        || v_action_emoji || ' <strong>'
        || coalesce(v_rec.user_name, '알 수 없음')
        || '</strong>: "'
        || coalesce(v_rec.entity_title, '(제목 없음)')
        || '" ' || v_action_label
        || v_parent_label
        || ' <span style="color:#999;font-size:12px;">('
        || v_time_str || ')</span></li>';
    END LOOP;

    v_section := v_section || '</ul>';
    v_html := v_html || v_section;
  END LOOP;

  -- HTML 푸터
  v_html := v_html
    || '<hr style="border:none;border-top:1px solid #eee;margin-top:24px;">'
    || '<p style="color:#999;font-size:11px;">'
    || '이 이메일은 R&D Task Manager에서 자동 발송되었습니다.<br>'
    || '<a href="https://rd-task-manager-coral.vercel.app" style="color:#1565C0;">앱 열기</a>'
    || '</p></div>';

  -- 미발송 레코드 ID 수집 (발송 전에 고정)
  SELECT array_agg(id) INTO v_ids
  FROM public.activity_logs
  WHERE notified = false;

  -- Resend API로 이메일 발송
  PERFORM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR_RESEND_API_KEY_HERE',
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', 'R&D Task Manager <noreply@sartexo.com>',
      'to', jsonb_build_array('YOUR_ADMIN_EMAIL@example.com'),
      'subject', '[R&D Task Manager] 최근 활동 요약 (' || v_count || '건)',
      'html', v_html
    )
  );

  -- 발송 완료 표시
  UPDATE public.activity_logs
  SET notified = true
  WHERE id = ANY(v_ids);

  RAISE NOTICE 'Digest sent: % activities', v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. pg_cron 스케줄 등록 (3시간마다)
-- ============================================================
-- 기존 스케줄이 있으면 제거
SELECT cron.unschedule('activity-digest')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'activity-digest'
);

-- 3시간마다 실행
SELECT cron.schedule(
  'activity-digest',
  '0 */3 * * *',
  'SELECT send_activity_digest()'
);
