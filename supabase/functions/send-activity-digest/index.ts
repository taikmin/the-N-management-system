// Supabase Edge Function: 3시간 활동 요약 이메일 (Resend)
// 설정: supabase secrets set RESEND_API_KEY=re_xxxxx DIGEST_EMAIL=YOUR_ADMIN_EMAIL@example.com

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const DIGEST_EMAIL = Deno.env.get("DIGEST_EMAIL") || "YOUR_ADMIN_EMAIL@example.com";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ActivityLog {
  id: string;
  user_name: string | null;
  action: string;
  entity_type: string;
  entity_title: string | null;
  created_at: string;
}

const ACTION_EMOJI: Record<string, string> = {
  create: "➕",
  update: "✏️",
  delete: "🗑️",
  complete: "✅",
};

const ENTITY_LABEL: Record<string, string> = {
  tasks: "업무",
  projects: "과제",
  meetings: "회의",
  memos: "메모",
  meeting_timeline: "타임라인",
};

const ENTITY_EMOJI: Record<string, string> = {
  tasks: "📋",
  projects: "📁",
  meetings: "🗓️",
  memos: "📝",
  meeting_timeline: "⏱️",
};

const ACTION_LABEL: Record<string, string> = {
  create: "생성",
  update: "수정",
  delete: "삭제",
  complete: "완료",
};

Deno.serve(async (_req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 미발송 활동 로그 조회
    const { data: logs, error } = await supabase
      .from("activity_logs")
      .select("*")
      .eq("notified", false)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("DB query error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
      });
    }

    if (!logs || logs.length === 0) {
      return new Response(
        JSON.stringify({ message: "No new activities", sent: false }),
        { status: 200 }
      );
    }

    // 엔티티별 그룹핑
    const grouped: Record<string, ActivityLog[]> = {};
    for (const log of logs as ActivityLog[]) {
      const key = log.entity_type;
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(log);
    }

    // HTML 이메일 본문 생성
    const now = new Date();
    const timeStr = `${now.getFullYear()}.${String(now.getMonth() + 1).padStart(2, "0")}.${String(now.getDate()).padStart(2, "0")} ${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;

    let htmlBody = `
      <div style="font-family: 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #1565C0; border-bottom: 2px solid #1565C0; padding-bottom: 8px;">
          R&D Task Manager - 활동 요약
        </h2>
        <p style="color: #666; font-size: 13px;">
          ${timeStr} 기준 · 총 ${logs.length}건
        </p>
    `;

    const entityOrder = [
      "tasks",
      "projects",
      "meetings",
      "memos",
      "meeting_timeline",
    ];

    for (const entityType of entityOrder) {
      const items = grouped[entityType];
      if (!items || items.length === 0) continue;

      const emoji = ENTITY_EMOJI[entityType] || "📌";
      const label = ENTITY_LABEL[entityType] || entityType;

      htmlBody += `
        <h3 style="color: #333; margin-top: 20px;">
          ${emoji} ${label} 변경 (${items.length}건)
        </h3>
        <ul style="list-style: none; padding: 0;">
      `;

      for (const item of items) {
        const userName = item.user_name || "알 수 없음";
        const title = item.entity_title || "(제목 없음)";
        const actionEmoji = ACTION_EMOJI[item.action] || "•";
        const actionLabel = ACTION_LABEL[item.action] || item.action;
        const time = new Date(item.created_at);
        const timeDisplay = `${String(time.getHours()).padStart(2, "0")}:${String(time.getMinutes()).padStart(2, "0")}`;

        htmlBody += `
          <li style="padding: 6px 0; border-bottom: 1px solid #f0f0f0; font-size: 14px;">
            ${actionEmoji} <strong>${userName}</strong>: "${title}" ${actionLabel}
            <span style="color: #999; font-size: 12px;">(${timeDisplay})</span>
          </li>
        `;
      }

      htmlBody += `</ul>`;
    }

    htmlBody += `
        <hr style="border: none; border-top: 1px solid #eee; margin-top: 24px;">
        <p style="color: #999; font-size: 11px;">
          이 이메일은 R&D Task Manager에서 자동 발송되었습니다.<br>
          <a href="https://rd-task-manager-coral.vercel.app" style="color: #1565C0;">앱 열기</a>
        </p>
      </div>
    `;

    // Resend로 이메일 발송
    const emailRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "R&D Task Manager <onboarding@resend.dev>",
        to: [DIGEST_EMAIL],
        subject: `[R&D Task Manager] 최근 활동 요약 (${logs.length}건)`,
        html: htmlBody,
      }),
    });

    if (!emailRes.ok) {
      const errBody = await emailRes.text();
      console.error("Resend error:", errBody);
      return new Response(
        JSON.stringify({ error: "Email send failed", details: errBody }),
        { status: 500 }
      );
    }

    // 발송 완료 → notified = true
    const ids = (logs as ActivityLog[]).map((l) => l.id);
    await supabase
      .from("activity_logs")
      .update({ notified: true })
      .in_("id", ids);

    return new Response(
      JSON.stringify({
        message: `Digest sent with ${logs.length} activities`,
        sent: true,
      }),
      { status: 200 }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});
