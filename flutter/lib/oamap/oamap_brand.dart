// OAMap add-on 0006: our build is not the official app.
// - No "new version" button pointing to the official download page
//   (main.dart runMobileApp -> checkUpdate()).
// App id / name / icon are in android build.gradle (gradle properties
// oamapAppId / oamapAppLabel), the server default in
// .github/oamap/set_server_defaults.py (GitHub secrets).
//
// Turn the update check back on: --dart-define=OAMAP_UPDATE_CHECK=true

const bool kOamapUpdateCheck =
    bool.fromEnvironment('OAMAP_UPDATE_CHECK', defaultValue: false);

// OAMap 0008: title on the phone home page (upstream shows the app name,
// "RustDesk"). The internal app name (config folders, protocol) is unchanged.
// Change at build time: --dart-define=OAMAP_APP_TITLE=...
const String kOamapAppTitle =
    String.fromEnvironment('OAMAP_APP_TITLE', defaultValue: 'OAMap 원격');

String oamapAppTitle(String upstream) =>
    kOamapAppTitle.isEmpty ? upstream : kOamapAppTitle;
