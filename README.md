# Partner Program Demo

A small partner program built on Supabase. It covers the three things a partnerships team needs from day one:

1. **Intake.** Companies apply to become partners through a public form.
2. **Triage.** Every application is scored automatically on arrival, so the team reviews the best ones first.
3. **Attribution.** Every referred signup is tracked from signup to activation, paid conversion and MRR, per partner.

All companies and numbers in the demo are fictional.

**Live demo:** https://nicolasmiodownik.github.io/partner-program-demo/

## Why I built it

Partner programs often get measured by volume: how many signups a partner sends. But volume and value are not the same thing. In the demo data, the partner that sends the most signups is not the one that brings the most revenue per signup. The dashboard is built to make that visible, because that is where a partner team should decide where to spend its time.

## How it works

Everything runs on Supabase, with no backend server:

| Piece | What it does |
| --- | --- |
| `partners`, `referrals`, `partner_applications` | Core tables in Postgres |
| `score_application()` trigger | Scores each new application on partner type, expected volume and use case |
| `partner_performance` view | Funnel per partner: signups, activation, paid, MRR |
| `program_monthly` view | Monthly trend for the whole program |
| `application_queue` view | Review queue without contact details |
| Row Level Security | The browser can read metrics and submit applications, but cannot edit or delete anything, and never sees applicants' emails |

The front end is plain HTML and JavaScript using `supabase-js`.

## Run it yourself

1. Create a Supabase project.
2. In the SQL editor, run `supabase/schema.sql` and then `supabase/seed.sql`.
3. Copy the project URL and anon key into `config.js`.
4. Open `index.html` with any static server, or publish the repo with GitHub Pages.

## Built by

Nicolás Miodownik. Growth and operations, 10+ years scaling commercial operations in Latin America and the US. I like building the tools I need. This project was built with AI coding tools, which is how I prototype most of my ideas.
