// OAMap 0007: security checks for the android build (run by the jobs
// security-scan / security-apk-permissions in oamap-android.yml).
// Every check compares OUR tree with the SAME upstream RustDesk tag, so only
// what our add-ons change can turn a check red; what upstream already has is
// listed as the baseline ("기준 목록") and never fails the job.
//
//   node security_check.cjs manifest <ours.xml> <upstream.xml>
//   node security_check.cjs secrets  <workflow.yml> [script.py ...]
//   node security_check.cjs audit    <cargo-audit-ours.json> <cargo-audit-upstream.json>
//   node security_check.cjs osv      <osv-ours.json> <osv-upstream.json>
//   node security_check.cjs apkperms <aapt2-ours.txt> <aapt2-official.txt | upstream.xml --source>
//   node security_check.cjs upstream <latest-release-tag>        (warning only)
//
// Output: markdown to $GITHUB_STEP_SUMMARY and security-report/<check>.md,
// ::error:: / ::warning:: annotations, exit code 1 when a check fails.
// The build job does not depend on these jobs: a red check never stops or
// changes the apk, it only marks the run as failed (GitHub sends a mail).
'use strict';
const fs = require('fs');
const path = require('path');

const [cmd, ...args] = process.argv.slice(2);
const out = [];
let failed = false;
const md = (s) => out.push(s);
const err = (s) => { failed = true; console.log('::error title=OAMap security::' + s); };
const warn = (s) => console.log('::warning title=OAMap security::' + s);
const read = (f) => { try { return fs.readFileSync(f, 'utf8'); } catch (e) { return null; } };
const esc = (s) => String(s == null ? '' : s).replace(/\|/g, '/').replace(/\r?\n/g, ' ');

function finish(name) {
  md('');
  md(failed ? '**결과: 실패 (위 빨간 줄 확인)**' : '**결과: 통과**');
  md('');
  const text = out.join('\n') + '\n';
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  fs.mkdirSync('security-report', { recursive: true });
  fs.writeFileSync(path.join('security-report', name + '.md'), text);
  console.log(text);
  process.exitCode = failed ? 1 : 0;
}

// ------------------------------------------------------------ CVSS 3.x score
function cvss3(vector) {
  if (!/^CVSS:3\.[01]\//.test(vector || '')) return null;
  const m = {};
  for (const p of vector.split('/').slice(1)) { const [k, v] = p.split(':'); m[k] = v; }
  const changed = m.S === 'C';
  const AV = { N: 0.85, A: 0.62, L: 0.55, P: 0.2 }[m.AV];
  const AC = { L: 0.77, H: 0.44 }[m.AC];
  const PR = { N: 0.85, L: changed ? 0.68 : 0.62, H: changed ? 0.5 : 0.27 }[m.PR];
  const UI = { N: 0.85, R: 0.62 }[m.UI];
  const cia = (x) => ({ H: 0.56, L: 0.22, N: 0 }[x]);
  const C = cia(m.C), I = cia(m.I), A = cia(m.A);
  if ([AV, AC, PR, UI, C, I, A].some((x) => x === undefined)) return null;
  const iss = 1 - (1 - C) * (1 - I) * (1 - A);
  const impact = changed ? 7.52 * (iss - 0.029) - 3.25 * Math.pow(iss - 0.02, 15) : 6.42 * iss;
  if (impact <= 0) return 0;
  const expl = 8.22 * AV * AC * PR * UI;
  const raw = changed ? Math.min(1.08 * (impact + expl), 10) : Math.min(impact + expl, 10);
  return Math.ceil(raw * 10 - 1e-9) / 10;
}
// High = CVSS >= 7, or no usable score (unknown counts as high: be careful).
const isHigh = (score) => score == null || score >= 7;
const scoreText = (score) => (score == null ? '점수 없음(높음으로 봄)' : String(score));

// ------------------------------------------------------------ manifest
function manifestInfo(xml) {
  const perms = new Set();
  const removed = new Set();
  for (const m of xml.matchAll(/<uses-permission(?:-sdk-23)?\b[^>]*>/g)) {
    const name = (m[0].match(/android:name="([^"]+)"/) || [])[1];
    if (!name) continue;
    if (/tools:node="remove"/.test(m[0])) removed.add(name); else perms.add(name);
  }
  const exported = new Set();
  const fgsTypes = new Map();
  for (const m of xml.matchAll(/<(activity|activity-alias|service|receiver|provider)\b[^>]*>/g)) {
    const name = (m[0].match(/android:name="([^"]+)"/) || [])[1] || '?';
    if (/android:exported="true"/.test(m[0])) exported.add(m[1] + ' ' + name);
    const t = (m[0].match(/android:foregroundServiceType="([^"]+)"/) || [])[1];
    if (t) fgsTypes.set(name, t.split('|'));
  }
  return { perms, removed, exported, fgsTypes };
}
const FGS_PERM = {
  camera: 'CAMERA', connectedDevice: 'CONNECTED_DEVICE', dataSync: 'DATA_SYNC', health: 'HEALTH',
  location: 'LOCATION', mediaPlayback: 'MEDIA_PLAYBACK', mediaProjection: 'MEDIA_PROJECTION',
  microphone: 'MICROPHONE', phoneCall: 'PHONE_CALL', remoteMessaging: 'REMOTE_MESSAGING',
  shortService: null, specialUse: 'SPECIAL_USE', systemExempted: 'SYSTEM_EXEMPTED',
  mediaProcessing: 'MEDIA_PROCESSING',
};

function cmdManifest(oursFile, baseFile) {
  md('## OAMap 보안: 권한·내보낸 부품 (원본 매니페스트 비교)');
  const ours = read(oursFile), base = read(baseFile);
  if (!ours || !base) { err('manifest file missing: ' + (!ours ? oursFile : baseFile)); return finish('manifest'); }
  const o = manifestInfo(ours), b = manifestInfo(base);
  const added = [...o.perms].filter((p) => !b.perms.has(p));
  const dropped = [...b.perms].filter((p) => !o.perms.has(p));
  md(`- 권한: 우리 ${o.perms.size} · 상류 ${b.perms.size} · **늘어난 것 ${added.length}** · 줄어든 것 ${dropped.length}`);
  if (added.length) {
    md('\n| 늘어난 권한 |\n|---|');
    for (const p of added) { md(`| ${p} |`); err('permission added by our patches: ' + p); }
  }
  const newExp = [...o.exported].filter((x) => !b.exported.has(x));
  md(`- 밖에서 부를 수 있는(exported=true) 부품: 우리 ${o.exported.size} · 상류 ${b.exported.size} · **새로 생긴 것 ${newExp.length}**`);
  for (const x of newExp) { md(`  - ${x}`); err('new exported component: ' + x); }
  // Every foreground service type must have its FOREGROUND_SERVICE_<TYPE>
  // permission, otherwise startForeground() throws on Android 14+.
  md('\n| 앞쪽 서비스 | 종류 | 필요한 권한 | 선언됨 | 상류에도 있던 권한 |\n|---|---|---|---|---|');
  for (const [svc, types] of o.fgsTypes) {
    for (const t of types) {
      const need = FGS_PERM[t] === undefined ? '?' : FGS_PERM[t];
      const perm = need ? 'android.permission.FOREGROUND_SERVICE_' + need : '(없음)';
      const ok = !need || o.perms.has(perm);
      md(`| ${svc} | ${t} | ${perm} | ${ok ? '예' : '아니오'} | ${!need || b.perms.has(perm) ? '예' : '아니오'} |`);
      if (!ok) err(`${svc} uses foregroundServiceType=${t} but ${perm} is not declared`);
    }
  }
  if (!o.perms.has('android.permission.FOREGROUND_SERVICE') && o.fgsTypes.size) err('FOREGROUND_SERVICE not declared');
  finish('manifest');
}

// ------------------------------------------------------------ secrets in workflow scripts
function runBlocks(yml) {
  const lines = yml.replace(/\r\n/g, '\n').split('\n');
  const blocks = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(\s*)(?:- )?run:\s?(.*)$/);
    if (!m) continue;
    const ind = m[1].length;
    const body = [{ n: i + 1, t: m[2] }];
    for (let j = i + 1; j < lines.length; j++) {
      const l = lines[j];
      if (l.trim() && l.match(/^(\s*)/)[1].length <= ind) break;
      body.push({ n: j + 1, t: l });
    }
    blocks.push(body);
  }
  return blocks;
}
function stripPyStrings(line) {
  return line.replace(/'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"/g, "''");
}
function cmdSecrets(wf, ...scripts) {
  md('## OAMap 보안: 비밀값이 기록에 안 찍히는지');
  const yml = read(wf);
  if (!yml) { err('workflow missing: ' + wf); return finish('secrets'); }
  let n = 0;
  // ${{ secrets.* }} / ${{ inputs.* }} / ${{ github.event.* }} pasted into a
  // shell script can leak (set -x, error echo) or inject commands: they must
  // go through env: instead.
  const risky = /\$\{\{\s*(secrets\.|inputs\.|github\.event\.|github\.head_ref)/;
  for (const b of runBlocks(yml)) {
    for (const { n: no, t } of b) {
      if (risky.test(t)) { n++; err(`${wf}:${no} \${{ }} with secrets/inputs/event inside run: (use env:)`); }
      if (/(^|\s)set\s+-[a-z]*x/.test(t)) { n++; err(`${wf}:${no} set -x in a script prints values`); }
    }
  }
  md(`- ${wf}: run 안에 비밀값·입력값 직접 넣은 곳 **${n}**`);
  const envSecrets = (yml.match(/\$\{\{\s*secrets\.[A-Za-z0-9_]+/g) || []).map((s) => s.replace(/.*secrets\./, ''));
  md(`- 쓰는 비밀값(env:/with: 로만): ${[...new Set(envSecrets)].join(', ') || '없음'} · GitHub 가 기록에서 자동으로 가림`);
  for (const s of scripts) {
    const src = read(s);
    if (!src) { err('script missing: ' + s); continue; }
    let bad = 0;
    src.split('\n').forEach((l, i) => {
      if (l.includes('::add-mask::')) return;
      const code = stripPyStrings(l);
      if (/\bprint\s*\(/.test(code) && /\b(server|key|src|v|m)\b/.test(code.replace(/^[^(]*\(/, ''))) {
        bad++; err(`${s}:${i + 1} print() may show a secret value`);
      }
    });
    md(`- ${s}: 값을 찍는 print **${bad}** · \`::add-mask::\` ${/::add-mask::/.test(src) ? '있음' : '없음'}`);
    if (!/::add-mask::/.test(src)) err(`${s}: no ::add-mask:: for derived values (host part)`);
  }
  finish('secrets');
}

// ------------------------------------------------------------ cargo audit
function auditList(file) {
  const t = read(file);
  if (!t || !t.trim()) return null;
  let j;
  try { j = JSON.parse(t); } catch (e) { return null; }
  const list = ((j.vulnerabilities || {}).list || []).map((v) => {
    const a = v.advisory || {};
    const score = cvss3(a.cvss);
    return { key: `${a.id} ${(v.package || {}).name}`, id: a.id, pkg: `${(v.package || {}).name} ${(v.package || {}).version}`,
      title: a.title, score, cvss: a.cvss };
  });
  let warnings = 0;
  for (const k of Object.keys(j.warnings || {})) warnings += (j.warnings[k] || []).length;
  return { list, warnings };
}
function diffReport(title, ours, base, name) {
  md(`## OAMap 보안: ${title}`);
  if (!ours) { err(`${title}: our report missing or not JSON (tool failed?)`); return finish(name); }
  if (!base) warn(`${title}: upstream baseline report missing - every finding counts as new`);
  const baseKeys = new Set((base ? base.list : []).map((x) => x.key));
  const fresh = ours.list.filter((x) => !baseKeys.has(x.key));
  const known = ours.list.filter((x) => baseKeys.has(x.key));
  const freshHigh = fresh.filter((x) => isHigh(x.score));
  md(`- 우리 ${ours.list.length} · 상류 기준 ${base ? base.list.length : '없음'} · **새로 생긴 것 ${fresh.length} (높은 위험 ${freshHigh.length})**`);
  if (fresh.length) {
    md('\n### 새로 생긴 것 (우리 묶음 탓)\n| 위험 | ID | 부품 | 점수 | 내용 |\n|---|---|---|---|---|');
    for (const x of fresh) {
      const high = isHigh(x.score);
      md(`| ${high ? '**높음**' : '낮음'} | ${esc(x.id)} | ${esc(x.pkg)} | ${scoreText(x.score)} | ${esc(x.title)} |`);
      if (high) err(`NEW high-risk advisory ${x.id} in ${x.pkg}: ${x.title}`);
      else warn(`new advisory ${x.id} in ${x.pkg} (score ${x.score})`);
    }
  }
  if (known.length) {
    md(`\n<details><summary>기준 목록: 상류 RustDesk 에 이미 있는 것 ${known.length} (실패 아님)</summary>\n`);
    md('| ID | 부품 | 점수 | 내용 |\n|---|---|---|---|');
    for (const x of known) md(`| ${esc(x.id)} | ${esc(x.pkg)} | ${x.score == null ? '-' : x.score} | ${esc(x.title)} |`);
    md('\n</details>');
  }
  if (ours.warnings) md(`- 참고 경고(관리 중단·회수된 판 등): ${ours.warnings}`);
  finish(name);
}
function osvList(file) {
  const t = read(file);
  if (!t || !t.trim()) return null;
  let j;
  try { j = JSON.parse(t.slice(t.indexOf('{'))); } catch (e) { return null; }
  const list = [];
  for (const r of j.results || []) {
    for (const p of r.packages || []) {
      const pk = p.package || {};
      const vulns = new Map((p.vulnerabilities || []).map((v) => [v.id, v]));
      const groups = p.groups && p.groups.length ? p.groups : [...vulns.keys()].map((id) => ({ ids: [id] }));
      for (const g of groups) {
        const id = (g.ids || [])[0];
        const v = vulns.get(id) || {};
        let score = parseFloat(g.max_severity);
        if (isNaN(score)) {
          const vec = ((v.severity || []).find((s) => /^CVSS_V3/.test(s.type)) || {}).score;
          score = cvss3(vec);
        }
        list.push({ key: `${pk.ecosystem}/${pk.name}/${id}`, id: (g.ids || []).join(' '),
          pkg: `${pk.ecosystem} ${pk.name} ${pk.version}`, title: v.summary || '', score });
      }
    }
  }
  return { list, warnings: 0 };
}

// ------------------------------------------------------------ apk permissions
function aaptInfo(txt) {
  const pkg = ((txt.match(/^package:\s*(\S+)/m) || [])[1]) || '';
  const norm = (n) => {
    if (pkg && n.startsWith(pkg + '.')) return '<pkg>' + n.slice(pkg.length);
    return n.replace(/^[A-Za-z0-9_.]+(\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION)$/, '<pkg>$1');
  };
  const uses = new Set();
  for (const m of txt.matchAll(/^uses-permission(?:-sdk-23)?:\s*name='([^']+)'/gm)) uses.add(norm(m[1]));
  const declared = new Set();
  for (const m of txt.matchAll(/^permission:\s*(\S+)/gm)) declared.add(norm(m[1]));
  return { pkg, uses, declared };
}
function cmdApkPerms(oursFile, baseFile, mode) {
  md('## OAMap 보안: 빌드된 apk 권한 비교');
  const ours = read(oursFile), base = read(baseFile);
  if (!ours || !base) { err('apk permission dump missing: ' + (!ours ? oursFile : baseFile)); return finish('apk-permissions'); }
  const o = aaptInfo(ours);
  if (!o.uses.size) { err('no uses-permission found in our apk dump (aapt2 failed?)'); return finish('apk-permissions'); }
  let baseUses, baseDecl, label;
  if (mode === '--source') {
    const b = manifestInfo(base);
    baseUses = b.perms; baseDecl = new Set(); label = '상류 원본 매니페스트(공식 apk 못 받음)';
  } else {
    const b = aaptInfo(base);
    baseUses = b.uses; baseDecl = b.declared; label = '공식 apk';
  }
  const added = [...o.uses].filter((p) => !baseUses.has(p));
  md(`- 비교 기준: ${label} · 우리 apk 패키지 ${o.pkg || '?'}`);
  md(`- uses-permission: 우리 ${o.uses.size} · 기준 ${baseUses.size} · **늘어난 것 ${added.length}**`);
  md('\n| 권한 | 우리 | 기준 |\n|---|---|---|');
  for (const p of [...new Set([...o.uses, ...baseUses])].sort()) {
    md(`| ${p} | ${o.uses.has(p) ? '있음' : '-'} | ${baseUses.has(p) ? '있음' : '-'} |`);
  }
  for (const p of added) {
    // Against the source manifest, library-merged permissions look "added":
    // report them as warnings only; against the official apk they fail.
    if (mode === '--source') warn('permission not in upstream source manifest (may come from a library): ' + p);
    else err('permission added compared with the official apk: ' + p);
  }
  const newDecl = [...o.declared].filter((p) => mode !== '--source' && !baseDecl.has(p));
  for (const p of newDecl) err('new <permission> declared by our apk: ' + p);
  finish('apk-permissions');
}

// ------------------------------------------------------------ newer upstream release
function cmdUpstream(latest) {
  md('## OAMap 보안: RustDesk 새 판 확인 (앱의 업데이트 알림은 꺼 둠)');
  const cur = process.env.VERSION || '?';
  const v = (s) => String(s || '').replace(/^v/, '').split(/[.-]/).map((x) => parseInt(x, 10) || 0);
  const newer = (a, b) => { const x = v(a), y = v(b); for (let i = 0; i < 3; i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0); } return false; };
  if (!latest || latest === 'unknown') { md('- 최신 판을 못 읽음(나중에 다시)'); warn('could not read latest RustDesk release'); }
  else if (newer(latest, cur)) {
    md(`- **새 판 ${latest} 있음** (지금 ${cur}) → Actions "OAMap upstream update" 를 tag=${latest} 로 손 실행`);
    warn(`RustDesk ${latest} is out (this build: ${cur}) - run "OAMap upstream update"`);
  } else md(`- 최신 ${latest} · 지금 ${cur} · 새 판 없음`);
  finish('upstream');
}

switch (cmd) {
  case 'manifest': cmdManifest(args[0], args[1]); break;
  case 'secrets': cmdSecrets(...args); break;
  case 'audit': diffReport('Rust 부품 취약점 (cargo audit · RustSec)', auditList(args[0]), auditList(args[1]), 'cargo-audit'); break;
  case 'osv': diffReport('Dart·Rust 부품 취약점 (OSV-Scanner · pubspec.lock + Cargo.lock)', osvList(args[0]), osvList(args[1]), 'osv'); break;
  case 'apkperms': cmdApkPerms(args[0], args[1], args[2]); break;
  case 'upstream': cmdUpstream(args[0]); break;
  default:
    console.error('usage: security_check.cjs manifest|secrets|audit|osv|apkperms|upstream ...');
    process.exitCode = 2;
}
