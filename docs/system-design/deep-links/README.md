# Invite deep links (hosting)

Flutter handles these URLs in-app via `app_links`:

- Custom scheme: `yalla5roga://invite?invitationId={id}&groupId={groupId}`
- HTTPS: `https://yalla5roga.com/invite/{invitationId}?groupId={groupId}`

HTTPS App Links / Universal Links only auto-open the app after you host the
verification files at the domain apex (and `www` if used):

| Platform | Path |
|----------|------|
| Android | `https://yalla5roga.com/.well-known/assetlinks.json` |
| iOS | `https://yalla5roga.com/.well-known/apple-app-site-association` (no `.json` extension; `application/json`) |

Templates live next to this README. Replace:

- Android `sha256_cert_fingerprints` with your upload/signing key SHA-256
- iOS `appID` team prefix (`ABCDEF1234`) with your Apple Team ID

Until those files are live, use the custom scheme for manual testing:

```text
adb shell am start -a android.intent.action.VIEW -d "yalla5roga://invite?invitationId=TEST&groupId=GROUP_UUID"
xcrun simctl openurl booted "yalla5roga://invite?invitationId=TEST&groupId=GROUP_UUID"
```
