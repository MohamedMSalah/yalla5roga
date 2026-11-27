// Offline configuration inspection only: no server, cloud requests, or builds.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { networkInterfaces } from "node:os";
import { readEnvironment, rootPath } from "./environment.mjs";
import { clientValues, readClientBuild } from "./flutter-config.mjs";
import { validateReleaseSigning } from "./android-signing.mjs";

const device = readEnvironment("device");
const production = readEnvironment("production");
const differences = new Set(["NODE_ENV", "APP_ENV", "API_BASE_URL", "DEPLOYMENT_ENV", "CORS_ORIGINS", "TRUST_PROXY"]);
assert.deepEqual(Object.keys(device).sort(), Object.keys(production).sort(), "Profile variable names must match");
assert.ok(Object.keys(device).every(key => differences.has(key) || device[key] === production[key]), "Shared configuration must match");
assert.ok(device.NODE_ENV === "development" && device.APP_ENV === "development" && device.HOST === "0.0.0.0" && device.PORT === "3000", "Device mode/bind settings");
assert.ok(production.NODE_ENV === "production" && production.APP_ENV === "production", "Production mode settings");
assert.equal(device.SHARED_PRODUCTION_SERVICES, "true", "Shared services must be deliberate");
const addresses = Object.values(networkInterfaces()).flat().filter(entry => entry.family === "IPv4" && !entry.internal).map(entry => entry.address);
assert.ok(addresses.includes(new URL(device.API_BASE_URL).hostname), "Device API host must be a current LAN address");
const { values } = readClientBuild("device");
const serverKeys = /^(DATABASE_URL|DIRECT_URL|MONITORING_TOKEN|GRAFANA_ADMIN_PASSWORD|FIREBASE_PRIVATE_KEY|FIREBASE_CLIENT_EMAIL|FIREBASE_API_KEY|R2_.*|WHATSAPP_.*)$/;
assert.ok(Object.keys(values).every(key => !serverKeys.test(key)), "Client file must exclude backend credentials");
const assetManifest = readFileSync(rootPath("flutter/pubspec.yaml"), "utf8");
assert.ok(!/^\s*-\s*.*(?:\.env|\.configuration-backups)/m.test(assetManifest), "Profiles must not be Flutter assets");
const mainManifest = readFileSync(rootPath("flutter/android/app/src/main/AndroidManifest.xml"), "utf8");
const deviceManifest = readFileSync(rootPath("flutter/android/app/src/device/AndroidManifest.xml"), "utf8");
const debugManifest = readFileSync(rootPath("flutter/android/app/src/debug/AndroidManifest.xml"), "utf8");
assert.ok(mainManifest.includes('android:usesCleartextTraffic="false"'), "Android must deny HTTP by default");
assert.ok(deviceManifest.includes('android:usesCleartextTraffic="true"') && !debugManifest.includes('android:usesCleartextTraffic="true"'), "HTTP exception must be confined to the device flavor");
const gradle = readFileSync(rootPath("flutter/android/app/build.gradle.kts"), "utf8");
assert.ok(gradle.includes('create("device")') && gradle.includes('create("production")') &&
  gradle.includes('applicationId = "com.example.yalla_5roga"') && !gradle.includes('applicationIdSuffix') &&
  /create\("device"\)\s*\{[^}]*signingConfig = signingConfigs\.getByName\("debug"\)/s.test(gradle) &&
  /create\("production"\)\s*\{[^}]*signingConfig = signingConfigs\.getByName\("release"\)/s.test(gradle) &&
  !/buildTypes\s*\{[\s\S]*?release\s*\{[^}]*signingConfig\s*=/.test(gradle),
  "Both flavors must retain the registered application ID and their distinct release signers");
for (const api of ["", "http://api.example.org", "https://127.0.0.1:3000"]) {
  assert.throws(() => clientValues("production", { ...production, API_BASE_URL: api }), undefined, "Production must reject missing or unsafe API origins");
}
const missing = ["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET_NAME", "WHATSAPP_ACCESS_TOKEN", "WHATSAPP_PHONE_NUMBER_ID"].filter(key => !production[key]);
let signing = "configured (file inspection only; signer and Firebase fingerprints require release verification)";
try { validateReleaseSigning(); } catch (error) { signing = error.message; }
console.log(JSON.stringify({ checks: "passed", variablesPerProfile: Object.keys(device).length, sharedSettingsMatch: true,
  deviceOrigin: device.API_BASE_URL, firebaseAndroidApplicationId: "com.example.yalla_5roga", safeClientVariables: Object.keys(values).length,
  productionApiConfigured: Boolean(production.API_BASE_URL), missingServiceSettings: missing, releaseSigning: signing,
  verification: "offline configuration only; service connectivity and APK contents are unverified" }, null, 2));
