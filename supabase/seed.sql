-- Partner Program Demo: sample data
-- All companies and numbers are fictional.

insert into partners (name, website, type, tier, status, joined_at) values
  ('Launchpad AI',      'https://example.com/launchpad',   'marketplace', 'strategic', 'active',  current_date - 270),
  ('Stackforge',        'https://example.com/stackforge',  'integration', 'strategic', 'active',  current_date - 250),
  ('ShipFast Studio',   'https://example.com/shipfast',    'agency',      'growth',    'active',  current_date - 230),
  ('DevLoop Weekly',    'https://example.com/devloop',     'referral',    'growth',    'active',  current_date - 210),
  ('CloudNest',         'https://example.com/cloudnest',   'marketplace', 'growth',    'active',  current_date - 190),
  ('Buildkit Academy',  'https://example.com/buildkit',    'referral',    'standard',  'active',  current_date - 170),
  ('Formwise',          'https://example.com/formwise',    'integration', 'growth',    'active',  current_date - 150),
  ('Nomad Devs',        'https://example.com/nomad',       'agency',      'standard',  'active',  current_date - 130),
  ('Prompt Lab',        'https://example.com/promptlab',   'referral',    'standard',  'paused',  current_date - 120),
  ('Edgeworks',         'https://example.com/edgeworks',   'integration', 'standard',  'active',  current_date - 90),
  ('Startup Bench',     'https://example.com/startupbench','marketplace', 'standard',  'active',  current_date - 60),
  ('Pixel & Query',     'https://example.com/pixelquery',  'agency',      'standard',  'churned', current_date - 240);

-- Each partner gets its own volume and quality profile, so the dashboard
-- shows a realistic spread: big but low-quality channels, small but great ones.
with profile(name, monthly_signups, p_activate, p_paid, avg_mrr) as (
  values
    ('Launchpad AI',     120, 0.55, 0.12, 45.0),
    ('Stackforge',        60, 0.70, 0.25, 95.0),
    ('ShipFast Studio',   25, 0.80, 0.40, 140.0),
    ('DevLoop Weekly',    90, 0.35, 0.06, 30.0),
    ('CloudNest',         70, 0.50, 0.10, 50.0),
    ('Buildkit Academy',  40, 0.45, 0.05, 25.0),
    ('Formwise',          30, 0.65, 0.22, 80.0),
    ('Nomad Devs',        12, 0.75, 0.35, 120.0),
    ('Prompt Lab',        35, 0.25, 0.03, 25.0),
    ('Edgeworks',         18, 0.60, 0.20, 70.0),
    ('Startup Bench',     45, 0.50, 0.09, 40.0),
    ('Pixel & Query',      8, 0.40, 0.10, 60.0)
),
days as (
  select p.id as partner_id, pr.*, d::date as day, random() as day_noise, random() as day_noise2
  from partners p
  join profile pr on pr.name = p.name
  cross join generate_series(greatest(p.joined_at, current_date - 270), current_date - 1, interval '1 day') d
),
signups as (
  select d.*, gs as n
  from days d
  cross join lateral generate_series(1, greatest(0, floor((d.monthly_signups / 30.0) * (0.3 + 1.4 * d.day_noise) + d.day_noise2)::int)) gs
),
rolled as (
  select s.*, random() as r_act, random() as r_paid, random() as r_mrr
  from signups s
)
insert into referrals (partner_id, signed_up_at, activated_at, converted_at, mrr_usd)
select
  partner_id,
  day + (random() * interval '20 hours'),
  case when r_act < p_activate then day + interval '1 day' * (1 + floor(random() * 5)) end,
  case when r_act < p_activate and r_paid < (p_paid / p_activate) then day + interval '1 day' * (7 + floor(random() * 20)) end,
  case when r_act < p_activate and r_paid < (p_paid / p_activate) then round((avg_mrr * (0.5 + r_mrr))::numeric, 2) else 0 end
from rolled;

-- A few sample applications waiting in the review queue (scored by the trigger).
insert into partner_applications (company_name, contact_name, contact_email, website, type, use_case, expected_referrals_month) values
  ('Northwind Templates', 'Ana Ruiz',     'ana@example.com',   'https://example.com/northwind', 'marketplace', 'We sell starter templates for SaaS founders and want to ship every template with a ready-to-use backend, so buyers can go live the same day.', 400),
  ('Bootcamp Sur',        'Diego Paz',    'diego@example.com', 'https://example.com/bootcamp',  'referral',    'Our full-stack bootcamp teaches 300 students per cohort and we want to standardize on one backend for final projects.', 120),
  ('Agencia Delta',       'Lucía Gómez',  'lucia@example.com', 'https://example.com/delta',     'agency',      'We build MVPs for startups in LATAM and want certified partner status and a referral link.', 15),
  ('Formula Bots',        'Tom Becker',   'tom@example.com',   null,                            'integration', 'Native connector for our workflow automation tool.', 60),
  ('Indie Hackers BA',    'Sofía Lima',   'sofia@example.com', 'https://example.com/ihba',      'referral',    'Community of 2,000 indie makers in Buenos Aires, monthly meetups and a newsletter where we would feature the platform.', 40);

update partner_applications set status = 'reviewing' where company_name in ('Bootcamp Sur');
update partner_applications set status = 'approved'  where company_name in ('Formula Bots');
