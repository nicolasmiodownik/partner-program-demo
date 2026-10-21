-- Partner Program Demo: schema
-- A small partner program on Supabase: intake of new partner requests,
-- a partner directory, and referral attribution down to revenue.

-- Types ---------------------------------------------------------------
create type partner_type as enum ('marketplace', 'referral', 'integration', 'agency');
create type partner_status as enum ('active', 'paused', 'churned');
create type application_status as enum ('new', 'reviewing', 'approved', 'rejected');

-- Partners ------------------------------------------------------------
create table partners (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  website     text,
  type        partner_type not null,
  tier        text not null default 'standard' check (tier in ('strategic', 'growth', 'standard')),
  status      partner_status not null default 'active',
  joined_at   date not null default current_date,
  created_at  timestamptz not null default now()
);

-- Intake: requests from companies that want to join the program ----------
create table partner_applications (
  id                         uuid primary key default gen_random_uuid(),
  company_name               text not null,
  contact_name               text not null,
  contact_email              text not null check (contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  website                    text,
  type                       partner_type not null,
  use_case                   text not null check (char_length(use_case) between 20 and 1000),
  expected_referrals_month   int  not null default 0 check (expected_referrals_month between 0 and 100000),
  fit_score                  int,
  status                     application_status not null default 'new',
  created_at                 timestamptz not null default now()
);

-- Referrals: every signup attributed to a partner, and how far it got ----
create table referrals (
  id               uuid primary key default gen_random_uuid(),
  partner_id       uuid not null references partners(id) on delete cascade,
  signed_up_at     timestamptz not null,
  activated_at     timestamptz,
  converted_at     timestamptz,
  mrr_usd          numeric(10,2) not null default 0,
  check (activated_at is null or activated_at >= signed_up_at),
  check (converted_at is null or activated_at is not null)
);
create index referrals_partner_idx on referrals(partner_id);
create index referrals_signed_up_idx on referrals(signed_up_at);

-- Auto-triage: score every new application so the team reviews the best first.
-- Simple, explainable rules: partner type + expected volume + a real use case.
create or replace function score_application()
returns trigger language plpgsql as $$
begin
  new.fit_score :=
      case new.type
        when 'marketplace' then 35
        when 'integration' then 30
        when 'referral'    then 20
        when 'agency'      then 15
      end
    + case
        when new.expected_referrals_month >= 500 then 40
        when new.expected_referrals_month >= 100 then 30
        when new.expected_referrals_month >= 20  then 15
        else 5
      end
    + case when char_length(new.use_case) >= 120 then 15 else 5 end
    + case when new.website is not null and new.website <> '' then 10 else 0 end;
  return new;
end $$;

create trigger trg_score_application
before insert on partner_applications
for each row execute function score_application();

-- Views ---------------------------------------------------------------
-- Funnel and revenue per partner: signups -> activated -> paid -> MRR.
create or replace view partner_performance with (security_invoker = true) as
select
  p.id,
  p.name,
  p.type,
  p.tier,
  p.status,
  count(r.id)                                    as signups,
  count(r.activated_at)                          as activated,
  count(r.converted_at)                          as paid,
  round(100.0 * count(r.activated_at) / nullif(count(r.id), 0), 1) as activation_rate,
  round(100.0 * count(r.converted_at) / nullif(count(r.id), 0), 1) as paid_rate,
  coalesce(sum(r.mrr_usd), 0)                    as mrr_usd
from partners p
left join referrals r on r.partner_id = p.id
group by p.id;

-- Monthly trend for the whole program.
create or replace view program_monthly with (security_invoker = true) as
select
  date_trunc('month', signed_up_at)::date as month,
  count(*)                                as signups,
  count(activated_at)                     as activated,
  count(converted_at)                     as paid,
  coalesce(sum(mrr_usd), 0)               as new_mrr_usd
from referrals
group by 1
order by 1;

-- Review queue without personal data (no contact names or emails).
create or replace view application_queue as
select id, company_name, type, expected_referrals_month, fit_score, status, created_at
from partner_applications
order by status = 'new' desc, fit_score desc, created_at desc;

-- Security (Row Level Security) -----------------------------------------
-- This is a public demo: anyone can read the program metrics and submit an
-- application, but nobody can edit or delete data, and contact details of
-- applicants are never readable from the browser.
alter table partners             enable row level security;
alter table referrals            enable row level security;
alter table partner_applications enable row level security;

create policy "public read partners"  on partners  for select to anon, authenticated using (true);
create policy "public read referrals" on referrals for select to anon, authenticated using (true);
create policy "public can apply" on partner_applications for insert to anon, authenticated
  with check (status = 'new');

revoke all on partners, referrals, partner_applications from anon, authenticated;
grant select on partners, referrals to anon, authenticated;
grant insert (company_name, contact_name, contact_email, website, type, use_case, expected_referrals_month)
  on partner_applications to anon, authenticated;

-- Views are read-only for the browser (application_queue is not updatable through the API).
revoke all on partner_performance, program_monthly, application_queue from anon, authenticated;
grant select on partner_performance, program_monthly, application_queue to anon, authenticated;
