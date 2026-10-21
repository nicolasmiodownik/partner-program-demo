import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const int = new Intl.NumberFormat('en-US');
const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
const pct = (v) => (v == null ? '–' : `${Number(v).toFixed(1)}%`);

let rows = [];
let sort = { key: 'mrr_usd', dir: 'desc' };

async function loadPerformance() {
  const { data, error } = await supabase.from('partner_performance').select('*');
  if (error) throw error;
  rows = data.map((r) => ({
    ...r,
    mrr_usd: Number(r.mrr_usd),
    mrr_per_signup: r.signups ? Number(r.mrr_usd) / r.signups : 0,
  }));

  const t = rows.reduce((a, r) => ({ s: a.s + r.signups, a: a.a + r.activated, p: a.p + r.paid, m: a.m + r.mrr_usd }), { s: 0, a: 0, p: 0, m: 0 });
  $('[data-kpi="signups"]').textContent = int.format(t.s);
  $('[data-kpi="activation"]').textContent = pct((100 * t.a) / t.s);
  $('[data-kpi="paid"]').textContent = pct((100 * t.p) / t.s);
  $('[data-kpi="mrr"]').textContent = usd.format(t.m);

  const active = rows.filter((r) => r.signups >= 30);
  const byVolume = [...active].sort((a, b) => b.signups - a.signups)[0];
  const byValue = [...active].sort((a, b) => b.mrr_per_signup - a.mrr_per_signup)[0];
  if (byVolume && byValue && byVolume.id !== byValue.id) {
    const x = (byValue.mrr_per_signup / byVolume.mrr_per_signup).toFixed(1);
    $('#insight').textContent = `${byVolume.name} brings the most signups, but each ${byValue.name} signup is worth ${x}x more in MRR. That is where a partner team should spend extra time.`;
    $('#insight').hidden = false;
  }
  renderTable();
}

function renderTable() {
  const { key, dir } = sort;
  const sorted = [...rows].sort((a, b) => {
    const va = a[key] ?? -1, vb = b[key] ?? -1;
    const c = typeof va === 'string' ? va.localeCompare(vb) : va - vb;
    return dir === 'asc' ? c : -c;
  });
  $('#perf tbody').innerHTML = sorted.map((r) => `
    <tr>
      <td>${esc(r.name)} ${r.status !== 'active' ? `<span class="pill ${esc(r.status)}">${esc(r.status)}</span>` : ''}</td>
      <td><span class="pill">${esc(r.type)}</span></td>
      <td class="num">${int.format(r.signups)}</td>
      <td class="num">${pct(r.activation_rate)}</td>
      <td class="num">${pct(r.paid_rate)}</td>
      <td class="num">${usd.format(r.mrr_usd)}</td>
      <td class="num">${r.signups ? '$' + r.mrr_per_signup.toFixed(2) : '–'}</td>
    </tr>`).join('');
  document.querySelectorAll('#perf th').forEach((th) => {
    if (th.dataset.sort === key) th.setAttribute('aria-sort', dir === 'asc' ? 'ascending' : 'descending');
    else th.removeAttribute('aria-sort');
  });
}

document.querySelectorAll('#perf th').forEach((th) => {
  th.addEventListener('click', () => {
    const key = th.dataset.sort;
    sort = { key, dir: sort.key === key && sort.dir === 'desc' ? 'asc' : 'desc' };
    renderTable();
  });
});

async function loadTrend() {
  const { data, error } = await supabase.from('program_monthly').select('*');
  if (error) throw error;
  const max = Math.max(...data.map((d) => d.signups), 1);
  $('#bars').innerHTML = data.map((d) => {
    const label = new Date(d.month + 'T12:00:00').toLocaleDateString('en-US', { month: 'short' });
    const h = Math.max(2, Math.round((d.signups / max) * 100));
    return `<div class="bar" title="${esc(label)}: ${int.format(d.signups)} signups, ${usd.format(d.new_mrr_usd)} new MRR">
      <span class="bar-val">${usd.format(d.new_mrr_usd)}</span>
      <div class="bar-fill" style="height:${h}%"></div>
      <span class="bar-label">${esc(label)}</span>
    </div>`;
  }).join('');
}

async function loadQueue() {
  const { data, error } = await supabase.from('application_queue').select('*').limit(8);
  if (error) throw error;
  $('#queue').innerHTML = data.map((a) => `
    <li>
      <span class="score" title="Fit score">${esc(a.fit_score)}</span>
      <div><div class="q-name">${esc(a.company_name)}</div>
      <div class="q-meta">${esc(a.type)} · ~${int.format(a.expected_referrals_month)} referrals/month</div></div>
      <span class="pill">${esc(a.status)}</span>
    </li>`).join('');
}

$('#apply-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.currentTarget;
  const msg = $('#form-msg');
  if (!form.checkValidity()) { form.reportValidity(); return; }
  const f = Object.fromEntries(new FormData(form));
  const btn = form.querySelector('button');
  btn.disabled = true; msg.textContent = 'Sending…';
  const { error } = await supabase.from('partner_applications').insert({
    company_name: f.company_name.trim(),
    contact_name: f.contact_name.trim(),
    contact_email: f.contact_email.trim(),
    website: f.website.trim() || null,
    type: f.type,
    use_case: f.use_case.trim(),
    expected_referrals_month: Number(f.expected_referrals_month) || 0,
  });
  btn.disabled = false;
  if (error) { msg.textContent = 'Could not submit. Check the fields and try again.'; return; }
  msg.textContent = 'Thanks! Your application is in the review queue.';
  form.reset();
  loadQueue();
});

Promise.all([loadPerformance(), loadTrend(), loadQueue()]).catch((err) => {
  console.error(err);
  document.querySelector('main').insertAdjacentHTML('afterbegin', '<p class="insight">Could not load data. Check the Supabase settings in config.js.</p>');
});
