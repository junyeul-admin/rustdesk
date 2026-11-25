// OAMap add-on 0007: build .github/workflows/oamap-android.yml from the
// upstream .github/workflows/flutter-build.yml of the same tag, so the pinned
// tool versions (Flutter, NDK, vcpkg, actions) always match upstream.
//   node .github/oamap/make_android_workflow.cjs [flutter-build.yml] [out.yml]
// Keeps: env block, generate-bridge, build-rustdesk-android (aarch64 only).
// Adds: server-default step (secrets), add-on checks, dart-define input.
// Drops: release publishing (APK goes to the run's Artifacts only).
// Adds: security-scan / security-apk-permissions jobs (non-blocking).
'use strict';
const fs = require('fs');
const src = process.argv[2] || '.github/workflows/flutter-build.yml';
const out = process.argv[3] || '.github/workflows/oamap-android.yml';
const text = fs.readFileSync(src, 'utf8').replace(/\r\n/g, '\n');
const lines = text.split('\n');
const fail = (m) => { console.error('OAMap 0007: ' + m); process.exit(1); };

function block(startRe, endRe) {
  const s = lines.findIndex((l) => startRe.test(l));
  if (s < 0) return null;
  let e = s + 1;
  while (e < lines.length && !endRe.test(lines[e])) e++;
  return lines.slice(s, e);
}
const env = block(/^env:\s*$/, /^jobs:\s*$/);
if (!env) fail('env block not found');
const jobRe = /^  [A-Za-z0-9_-]+:\s*$/;
const bridge = block(/^  generate-bridge:\s*$/, jobRe);
const android = block(/^  build-rustdesk-android:\s*$/, jobRe);
if (!bridge || !android) fail('job generate-bridge / build-rustdesk-android not found');

const bridgeOut = bridge.filter((l) => !/^    needs:/.test(l));
let a = android.join('\n');

// matrix: aarch64 only
a = a.replace(/(\n          - \{[\s\S]*?\n            \})/g, (m) => (/arch: aarch64\b/.test(m) ? m : ''));
if (!/arch: aarch64/.test(a)) fail('aarch64 matrix entry not found');

// after checkout: server defaults + add-on checks
const checkout = /(\n      - name: Checkout source code\n(?:        .*\n)+?)(\n      - )/;
if (!checkout.test(a)) fail('checkout step not found');
a = a.replace(checkout, (m, step, next) => step +
  '\n      - name: OAMap add-on checks (hooks + input simulation)\n' +
  '        run: |\n' +
  '          node .github/oamap/check_hooks.cjs\n' +
  '          node .github/oamap/sim_input.cjs\n' +
  '\n      - name: OAMap server defaults (GitHub secrets, values never printed)\n' +
  '        env:\n' +
  '          OAMAP_ID_SERVER: ${{ secrets.OAMAP_ID_SERVER }}\n' +
  '          OAMAP_PUB_KEY: ${{ secrets.OAMAP_PUB_KEY }}\n' +
  '        run: python3 .github/oamap/set_server_defaults.py libs/hbb_common/src/config.rs\n' + next);

// after Flutter is installed (and patched): the real Dart test of the 0001
// Hangul input diff, 63 cases; a failure stops the build.
const flutterStep = /(\n      - name: Patch flutter\n(?:        .*\n)+?)(\n      - )/.test(a)
  ? /(\n      - name: Patch flutter\n(?:        .*\n)+?)(\n      - )/
  : /(\n      - name: Install flutter\n(?:        .*\n)+?)(\n      - )/;
if (!flutterStep.test(a)) fail('Install flutter step not found');
a = a.replace(flutterStep, (m, step, next) => step +
  '\n      - name: OAMap Hangul input test (real Dart)\n' +
  '        working-directory: flutter\n' +
  '        shell: bash\n' +
  '        run: |\n' +
  '          set +e\n' +
  '          flutter test test/oamap_input_test.dart test/oamap_compose_test.dart test/oamap_cursor_test.dart --reporter expanded 2>&1 | tee "$RUNNER_TEMP/oamap_input_test.log"\n' +
  '          rc=${PIPESTATUS[0]}\n' +
  '          last=$(grep -E "^[0-9:]+ \\+[0-9]+" "$RUNNER_TEMP/oamap_input_test.log" | tail -n 1)\n' +
  '          if [ "$rc" -eq 0 ]; then res=PASS; else res=FAIL; fi\n' +
  '          echo "OAMap Hangul input test (real Dart): $res - $last" >> "$GITHUB_STEP_SUMMARY"\n' +
  '          exit "$rc"\n' + next);

// dart-define flags through env (no ${{ }} inside the script)
if (!/--split-per-abi/.test(a)) fail('flutter build apk line not found');
a = a.replace(/--split-per-abi/g, '--split-per-abi $OAMAP_DART_DEFINES');
a = a.replace(/(      - name: Build rustdesk\n        shell: bash\n        env:\n)/, '$1          OAMAP_DART_DEFINES: ${{ inputs.dart_defines }}\n');
if (!/OAMAP_DART_DEFINES: \$\{\{ inputs.dart_defines \}\}/.test(a)) fail('Build rustdesk env not found');

// no release publishing: drop "Publish ..." steps, upload to Artifacts only
a = a.replace(/\n      - name: Publish[^\n]*\n(?:        [^\n]*\n|          [^\n]*\n)*/g, '\n');
a = a.replace(/if: env\.ANDROID_SIGNING_KEY != null && env\.UPLOAD_ARTIFACT == 'true'/g, 'if: env.ANDROID_SIGNING_KEY != null');
a = a.replace(/\s*$/, '\n') +
  '\n      - name: Upload unsigned apk (test only, no signing key secret)\n' +
  '        if: env.ANDROID_SIGNING_KEY == null\n' +
  '        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1\n' +
  '        with:\n' +
  '          name: oamap-remote-unsigned-${{ env.VERSION }}-${{ matrix.job.arch }}.apk\n' +
  '          path: signed-apk/*.apk\n';

// security checks: separate jobs, the build never needs them, so a finding
// cannot stop or change the apk; it marks the run red (GitHub mail) instead.
// Logic in .github/oamap/security_check.cjs; baselines = same upstream tag.
const raw = 'https://raw.githubusercontent.com/rustdesk/rustdesk/${VERSION}/';
const security = [
  '',
  '  # OAMap 0007: security checks (separate jobs: never block the apk build)',
  '  security-scan:',
  '    name: OAMap security scan (deps, manifest, secrets)',
  '    runs-on: ubuntu-24.04',
  '    steps:',
  '      - name: Checkout source code',
  '        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4',
  '',
  '      - name: Upstream baseline files (same RustDesk tag)',
  '        run: |',
  '          mkdir -p security-report',
  '          for f in Cargo.lock flutter/pubspec.lock flutter/android/app/src/main/AndroidManifest.xml; do',
  '            mkdir -p "base/$(dirname "$f")"',
  '            curl -fsSL --retry 3 -o "base/$f" "' + raw + '$f"',
  '          done',
  '',
  '      - name: Permissions and exported components vs upstream manifest',
  '        if: ${{ !cancelled() }}',
  '        run: node .github/oamap/security_check.cjs manifest flutter/android/app/src/main/AndroidManifest.xml base/flutter/android/app/src/main/AndroidManifest.xml',
  '',
  '      - name: Secrets never printed (workflow scripts)',
  '        if: ${{ !cancelled() }}',
  '        run: node .github/oamap/security_check.cjs secrets .github/workflows/oamap-android.yml .github/oamap/set_server_defaults.py',
  '',
  '      - name: Rust crates - cargo audit (RustSec), new vs upstream',
  '        if: ${{ !cancelled() }}',
  '        run: |',
  '          cargo install cargo-audit --locked --quiet',
  '          cargo audit --json --file Cargo.lock > security-report/cargo-audit-ours.json || true',
  '          cargo audit --json --no-fetch --file base/Cargo.lock > security-report/cargo-audit-upstream.json || true',
  '          node .github/oamap/security_check.cjs audit security-report/cargo-audit-ours.json security-report/cargo-audit-upstream.json',
  '',
  '      - name: Dart and Rust packages - OSV-Scanner, new vs upstream',
  '        if: ${{ !cancelled() }}',
  '        run: |',
  '          u=https://github.com/google/osv-scanner/releases/latest/download',
  '          curl -fsSL --retry 3 -o osv-scanner_linux_amd64 "$u/osv-scanner_linux_amd64"',
  '          curl -fsSL --retry 3 -o osv-sums "$u/osv-scanner_SHA256SUMS"',
  "          grep ' osv-scanner_linux_amd64$' osv-sums | sha256sum -c -",
  '          chmod +x osv-scanner_linux_amd64',
  '          ./osv-scanner_linux_amd64 --format json --lockfile flutter/pubspec.lock --lockfile Cargo.lock > security-report/osv-ours.json || true',
  '          ./osv-scanner_linux_amd64 --format json --lockfile base/flutter/pubspec.lock --lockfile base/Cargo.lock > security-report/osv-upstream.json || true',
  '          node .github/oamap/security_check.cjs osv security-report/osv-ours.json security-report/osv-upstream.json',
  '',
  '      - name: Newer RustDesk release (the app update check is off)',
  '        if: ${{ !cancelled() }}',
  '        env:',
  '          GH_TOKEN: ${{ github.token }}',
  '        run: |',
  '          latest=$(gh api repos/rustdesk/rustdesk/releases/latest --jq .tag_name || echo unknown)',
  '          node .github/oamap/security_check.cjs upstream "$latest"',
  '',
  '      - name: Upload security report',
  '        if: ${{ !cancelled() }}',
  '        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1',
  '        with:',
  '          name: oamap-security-report-scan',
  '          path: security-report/',
  '',
  '  security-apk-permissions:',
  '    name: OAMap security - apk permissions vs official apk',
  '    needs: [build-rustdesk-android]',
  '    runs-on: ubuntu-24.04',
  '    steps:',
  '      - name: Checkout source code',
  '        uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4',
  '',
  '      - name: Our apk (this run)',
  '        uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1',
  '        with:',
  '          pattern: "*.apk"',
  '          path: ours-apk',
  '',
  '      - name: Compare uses-permission with the official apk',
  '        run: |',
  '          mkdir -p security-report',
  '          sdk="${ANDROID_HOME:-/usr/local/lib/android/sdk}"',
  '          aapt2="$sdk/build-tools/$(ls "$sdk/build-tools" | sort -V | tail -n 1)/aapt2"',
  "          ours=$(find ours-apk -name '*.apk' -type f | head -n 1)",
  '          if [ -z "$ours" ]; then echo "::error::no apk artifact in this run"; exit 1; fi',
  '          "$aapt2" dump permissions "$ours" > security-report/apk-permissions-ours.txt',
  '          if curl -fsSL --retry 3 -o official.apk "https://github.com/rustdesk/rustdesk/releases/download/${VERSION}/rustdesk-${VERSION}-aarch64.apk"; then',
  '            "$aapt2" dump permissions official.apk > security-report/apk-permissions-official.txt',
  '            node .github/oamap/security_check.cjs apkperms security-report/apk-permissions-ours.txt security-report/apk-permissions-official.txt',
  '          else',
  '            curl -fsSL --retry 3 -o upstream-manifest.xml "' + raw + 'flutter/android/app/src/main/AndroidManifest.xml"',
  '            node .github/oamap/security_check.cjs apkperms security-report/apk-permissions-ours.txt upstream-manifest.xml --source',
  '          fi',
  '',
  '      - name: Upload security report',
  '        if: ${{ !cancelled() }}',
  '        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1',
  '        with:',
  '          name: oamap-security-report-apk',
  '          path: security-report/',
  '',
];

const head = [
  '# OAMap: generated by .github/oamap/make_android_workflow.cjs from',
  '# flutter-build.yml - do not edit by hand, re-run the generator instead.',
  'name: OAMap android apk (aarch64)',
  '',
  'on:',
  '  workflow_dispatch:',
  '    inputs:',
  '      dart_defines:',
  '        description: "Extra flags, e.g. --dart-define=OAMAP_NO_SHAKE=false"',
  '        type: string',
  '        default: ""',
  '',
  'permissions:',
  '  contents: read',
  '',
];
const body = head.concat(env, ['jobs:'], bridgeOut, [a], security).join('\n').replace(/\n{3,}/g, '\n\n');
fs.writeFileSync(out, body);
console.log('OAMap 0007: wrote ' + out + ' (' + body.split('\n').length + ' lines)');
