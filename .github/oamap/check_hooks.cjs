// OAMap 0007: every add-on hook line is still in the upstream files.
// A missing line means a patch was applied partly or upstream moved code.
'use strict';
const fs = require('fs');
const need = [
  ['0001', 'flutter/lib/mobile/pages/remote_page.dart', 'oamapSoftKeyboardDiff(oldValue, newValue,'],
  ['0002', 'flutter/lib/mobile/pages/remote_page.dart', '...oamapImeKeys(wrap, inputModel, isMac),'],
  ['0003', 'flutter/lib/mobile/pages/remote_page.dart', '_oamapKeeper.open();'],
  ['0003', 'flutter/lib/mobile/pages/remote_page.dart', '_oamapKeeper.close();'],
  ['0003', 'flutter/lib/mobile/pages/remote_page.dart', '_oamapKeeper.onLifecycle(state);'],
  ['0003', 'flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainActivity.kt', '"client_session_fgs" ->'],
  ['0003', 'flutter/android/app/src/main/AndroidManifest.xml', 'android:name=".ClientSessionService"'],
  ['0004', 'flutter/lib/mobile/pages/remote_page.dart', 'resizeToAvoidBottomInset: oamapResizeToAvoidBottomInset,'],
  ['0004', 'flutter/lib/mobile/pages/remote_page.dart', '_oamapKbCanvas'],
  ['0005', 'flutter/lib/models/model.dart', 'var cx = oamapPanEdgeX(r, dx);'],
  ['0005', 'flutter/lib/mobile/pages/remote_page.dart', 'oamapIsRealRotation(ctx, orientation)'],
  ['0006', 'flutter/lib/main.dart', 'if (kOamapUpdateCheck) checkUpdate();'],
  ['0006', 'flutter/android/app/build.gradle', 'project.findProperty("oamapAppId")'],
  ['0006', 'flutter/android/app/src/main/AndroidManifest.xml', 'android:label="@string/oamap_app_label"'],
];
let bad = 0;
for (const [no, file, text] of need) {
  let s = '';
  try { s = fs.readFileSync(file, 'utf8'); } catch (e) { /* missing file */ }
  if (!s.includes(text)) { bad++; console.log(`MISSING ${no} ${file}: ${text}`); }
}
console.log(bad ? `OAMap hooks: ${bad} missing` : `OAMap hooks: all ${need.length} present`);
process.exitCode = bad ? 1 : 0;
