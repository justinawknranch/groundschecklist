-- =====================================================
-- Grounds checklist: editable by admins
-- =====================================================
-- Adds a single-row jsonb config so admins can edit the
-- daily grounds checklist (sections + items) from the
-- public /groundskeeper/ page. Read is public (anyone can
-- view the live checklist), write is admin-only via RLS.
--
-- Also seeds rodney@awknranch.com, justin@within.center,
-- and justin@awknranch.com as admins so they get admin
-- access the first time they sign in with Google.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.grounds_checklist_config (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  sections jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.app_users(id)
);

ALTER TABLE public.grounds_checklist_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS grounds_checklist_public_read ON public.grounds_checklist_config;
CREATE POLICY grounds_checklist_public_read ON public.grounds_checklist_config
  FOR SELECT USING (true);

DROP POLICY IF EXISTS grounds_checklist_admin_write ON public.grounds_checklist_config;
CREATE POLICY grounds_checklist_admin_write ON public.grounds_checklist_config
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.app_users WHERE auth_user_id = auth.uid() AND role IN ('admin', 'oracle'))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.app_users WHERE auth_user_id = auth.uid() AND role IN ('admin', 'oracle'))
  );

DROP POLICY IF EXISTS grounds_checklist_service ON public.grounds_checklist_config;
CREATE POLICY grounds_checklist_service ON public.grounds_checklist_config
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Seed initial config from the existing hardcoded checklist
INSERT INTO public.grounds_checklist_config (id, sections) VALUES (1, $json$
[
  {"section": "Main House", "items": [
    "Empty all garbages (inside & around house)",
    "Leaf blow exterior areas",
    "Remove leaves from pool",
    "Fill pool — turn on for 30 min",
    "Water jets",
    "Wipe off outdoor furniture (porch / temple area)",
    "Wash off dome exterior",
    "Collect, wash, and restock towels",
    "Check yurts (A/C vs. heat functioning properly)",
    "Check on Heather"
  ]},
  {"section": "Wellness Area", "items": [
    "Leaf blow surrounding areas",
    "Empty garbages",
    "Check cold plunge & hot tub",
    "Add chlorine / water as needed",
    "Clean plunge / tub as needed",
    "Wash and refill towels",
    "Clean bathroom as needed — restock, spot clean, fill soaps",
    "Restock toiletries (soap, shampoo, etc.)",
    "Clean up patio furniture",
    "Check on hot water heater",
    "Water"
  ]},
  {"section": "Temple", "items": [
    "Leaf blow exterior",
    "Empty garbages",
    "Clean sauna",
    "Clean cold plunge",
    "Restock bathrooms",
    "Sweep floors",
    "Tidy up from the day before",
    "Check behind the bar for any loose items",
    "Tidy up furniture",
    "Water"
  ]},
  {"section": "Yurts", "items": [
    "Tidy up",
    "Empty trash",
    "Make any beds / mats that are in"
  ]},
  {"section": "End of Day", "items": [
    "Empty garbages",
    "Water jugs",
    "Bring in umbrellas"
  ]},
  {"section": "Once a Week", "items": [
    "Water plants in wellness ranch"
  ]}
]
$json$::jsonb)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- Seed admin access for the three named groundskeeper admins.
-- If the user already exists in app_users (e.g. signed in
-- previously as 'public'), upgrade to admin. Otherwise drop
-- a pending invitation so their first Google sign-in lands
-- them straight into admin role (see shared/auth.js).
-- =====================================================

WITH admin_emails(email) AS (
  VALUES
    ('justin@within.center'),
    ('justin@awknranch.com'),
    ('rodney@awknranch.com')
)
UPDATE public.app_users
   SET role = 'admin'
 WHERE lower(email) IN (SELECT email FROM admin_emails)
   AND role NOT IN ('admin', 'oracle');

INSERT INTO public.user_invitations (email, role, status, invited_at, expires_at)
SELECT email, 'admin', 'pending', now(), now() + interval '10 years'
  FROM (VALUES
    ('justin@within.center'),
    ('justin@awknranch.com'),
    ('rodney@awknranch.com')
  ) AS new_admins(email)
 WHERE NOT EXISTS (
   SELECT 1 FROM public.app_users a WHERE lower(a.email) = new_admins.email
 )
 AND NOT EXISTS (
   SELECT 1 FROM public.user_invitations i
    WHERE lower(i.email) = new_admins.email
      AND i.status = 'pending'
 );
