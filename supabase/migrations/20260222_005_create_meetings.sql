-- ============================================================
-- Migration: meetings 관련 테이블 (회의 관리 시스템)
-- ============================================================

-- 1. meetings (회의)
CREATE TABLE IF NOT EXISTS public.meetings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  meeting_type TEXT NOT NULL DEFAULT 'progress_check'
    CHECK (meeting_type IN (
      'progress_check', 'kickoff', 'mid_presentation',
      'final_presentation', 'other'
    )),
  meeting_date TIMESTAMPTZ NOT NULL,
  location TEXT,
  room_name TEXT,
  status TEXT NOT NULL DEFAULT 'preparing'
    CHECK (status IN ('preparing', 'notified', 'in_progress', 'completed')),
  meal_reservation BOOLEAN DEFAULT FALSE,
  meal_location TEXT,
  expected_attendees INT DEFAULT 0,
  description TEXT,
  creator_id UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meetings_project_id ON public.meetings(project_id);
CREATE INDEX idx_meetings_date ON public.meetings(meeting_date);
CREATE INDEX idx_meetings_status ON public.meetings(status);

CREATE TRIGGER meetings_updated_at
  BEFORE UPDATE ON public.meetings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 2. meeting_participants (회의 참석자)
CREATE TABLE IF NOT EXISTS public.meeting_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  institution TEXT,
  attendance TEXT NOT NULL DEFAULT 'pending'
    CHECK (attendance IN ('pending', 'confirmed', 'declined')),
  role TEXT NOT NULL DEFAULT 'attendee'
    CHECK (role IN ('organizer', 'presenter', 'attendee')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(meeting_id, user_id)
);

CREATE INDEX idx_meeting_participants_meeting ON public.meeting_participants(meeting_id);
CREATE INDEX idx_meeting_participants_user ON public.meeting_participants(user_id);

-- 3. meeting_documents (회의 문서)
CREATE TABLE IF NOT EXISTS public.meeting_documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL DEFAULT 'other'
    CHECK (doc_type IN (
      'template', 'submission', 'compiled', 'minutes', 'other'
    )),
  title TEXT NOT NULL,
  file_url TEXT,
  file_name TEXT,
  file_size BIGINT DEFAULT 0,
  uploader_id UUID NOT NULL REFERENCES public.profiles(id),
  target_user_id UUID REFERENCES public.profiles(id),
  due_date TIMESTAMPTZ,
  submit_status TEXT NOT NULL DEFAULT 'not_submitted'
    CHECK (submit_status IN ('not_submitted', 'submitted', 'revision_requested')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meeting_documents_meeting ON public.meeting_documents(meeting_id);
CREATE INDEX idx_meeting_documents_target ON public.meeting_documents(target_user_id);

CREATE TRIGGER meeting_documents_updated_at
  BEFORE UPDATE ON public.meeting_documents
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 4. meeting_agenda (회의 안건)
CREATE TABLE IF NOT EXISTS public.meeting_agenda (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  order_index INT NOT NULL DEFAULT 0,
  title TEXT NOT NULL,
  presenter_id UUID REFERENCES public.profiles(id),
  duration_minutes INT DEFAULT 10,
  related_project_id UUID REFERENCES public.projects(id),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meeting_agenda_meeting ON public.meeting_agenda(meeting_id);

CREATE TRIGGER meeting_agenda_updated_at
  BEFORE UPDATE ON public.meeting_agenda
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 5. meeting_timeline (회의 준비 타임라인)
CREATE TABLE IF NOT EXISTS public.meeting_timeline (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  milestone TEXT NOT NULL,
  label TEXT NOT NULL,
  due_date TIMESTAMPTZ NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  notification_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meeting_timeline_meeting ON public.meeting_timeline(meeting_id);
CREATE INDEX idx_meeting_timeline_due ON public.meeting_timeline(due_date);

-- ============================================================
-- RLS Policies
-- ============================================================

ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_agenda ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_timeline ENABLE ROW LEVEL SECURITY;

-- meetings: 과제 멤버만 조회
CREATE POLICY "Project members can view meetings"
  ON public.meetings FOR SELECT
  USING (
    project_id IN (
      SELECT project_id FROM public.project_members WHERE user_id = auth.uid()
    )
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Project members can create meetings"
  ON public.meetings FOR INSERT
  WITH CHECK (creator_id = auth.uid());

CREATE POLICY "Meeting creator/project owner can update"
  ON public.meetings FOR UPDATE
  USING (
    creator_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Meeting creator/project owner can delete"
  ON public.meetings FOR DELETE
  USING (
    creator_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

-- meeting_participants: 같은 회의 참석자만 조회
CREATE POLICY "Meeting participants can view"
  ON public.meeting_participants FOR SELECT
  USING (
    meeting_id IN (
      SELECT id FROM public.meetings WHERE project_id IN (
        SELECT project_id FROM public.project_members WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects WHERE owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can manage participants"
  ON public.meeting_participants FOR INSERT
  WITH CHECK (TRUE);

CREATE POLICY "Users can update own attendance"
  ON public.meeting_participants FOR UPDATE
  USING (user_id = auth.uid() OR meeting_id IN (
    SELECT id FROM public.meetings WHERE creator_id = auth.uid()
  ));

CREATE POLICY "Organizer can remove participants"
  ON public.meeting_participants FOR DELETE
  USING (meeting_id IN (
    SELECT id FROM public.meetings WHERE creator_id = auth.uid()
  ));

-- meeting_documents: 과제 멤버
CREATE POLICY "Project members can view documents"
  ON public.meeting_documents FOR SELECT
  USING (
    meeting_id IN (
      SELECT id FROM public.meetings WHERE project_id IN (
        SELECT project_id FROM public.project_members WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects WHERE owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can upload documents"
  ON public.meeting_documents FOR INSERT
  WITH CHECK (uploader_id = auth.uid());

CREATE POLICY "Uploader/organizer can update documents"
  ON public.meeting_documents FOR UPDATE
  USING (
    uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

CREATE POLICY "Uploader/organizer can delete documents"
  ON public.meeting_documents FOR DELETE
  USING (
    uploader_id = auth.uid()
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
  );

-- meeting_agenda: 과제 멤버
CREATE POLICY "Project members can view agenda"
  ON public.meeting_agenda FOR SELECT
  USING (
    meeting_id IN (
      SELECT id FROM public.meetings WHERE project_id IN (
        SELECT project_id FROM public.project_members WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects WHERE owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "Organizer can manage agenda"
  ON public.meeting_agenda FOR ALL
  USING (
    meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE project_id IN (
        SELECT id FROM public.projects WHERE owner_id = auth.uid()
      )
    )
  );

-- meeting_timeline: 과제 멤버
CREATE POLICY "Project members can view timeline"
  ON public.meeting_timeline FOR SELECT
  USING (
    meeting_id IN (
      SELECT id FROM public.meetings WHERE project_id IN (
        SELECT project_id FROM public.project_members WHERE user_id = auth.uid()
      )
      OR project_id IN (
        SELECT id FROM public.projects WHERE owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "Organizer can manage timeline"
  ON public.meeting_timeline FOR ALL
  USING (
    meeting_id IN (
      SELECT id FROM public.meetings WHERE creator_id = auth.uid()
    )
    OR meeting_id IN (
      SELECT id FROM public.meetings WHERE project_id IN (
        SELECT id FROM public.projects WHERE owner_id = auth.uid()
      )
    )
  );
