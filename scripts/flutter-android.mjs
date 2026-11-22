import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, writeFileSync, unlinkSync, rmdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { readClientBuild } from "./flutter-config.mjs";
import { rootPath } from "./environment.mjs";
import { validateReleaseSigning } from "./android-signing.mjs";

let temporaryDirectory;
try {
  const [mode, command, deviceId, ...extra] = process.argv.slice(2);
  if (!["apk", "run"].includes(command) || (command === "run" &&
    (mode !== "device" || !/^[\w.:\-]+$/.test(deviceId ?? ""))) ||
    (command === "apk" && deviceId) || extra.length) {
    throw new Error("Use device apk, production apk, or device run <device-id>.");
  }
  const { values, excluded } = readClientBuild(mode);
  if (command === "apk") validateReleaseSigning();
  temporaryDirectory = mkdtempSync(join(tmpdir(), "yalla-client-"));
  const defines = join(temporaryDirectory, "client.json");
  writeFileSync(defines, JSON.stringify(values), { mode: 0o600 });
  const flutterArgs = command === "run" ? ["run", "-d", deviceId, "--debug"] :
    ["build", "apk", "--release", "--split-per-abi"];
  flutterArgs.push("--flavor", mode, `--dart-define-from-file=${defines}`);
  const env = { ...process.env };
  for (const key of excluded) delete env[key];
  let executable = "flutter";
  if (process.platform === "win32") {
    // Pass argv directly to Dart. Invoking flutter.bat through cmd would reparse
    // define values as shell syntax (for example & in an attribution URL).
    const candidates = [process.env.FLUTTER_ROOT && join(process.env.FLUTTER_ROOT, "bin"),
      ...(process.env.Path ?? process.env.PATH ?? "").split(delimiter)].filter(Boolean);
    const bin = candidates.find(dir => existsSync(join(dir, "flutter.bat")));
    if (!bin) throw new Error("Add the Flutter SDK to PATH or set FLUTTER_ROOT.");
    env.FLUTTER_ROOT = join(bin, "..");
    executable = join(bin, "cache", "dart-sdk", "bin", "dart.exe");
    const snapshot = join(bin, "cache", "flutter_tools.snapshot");
    if (!existsSync(executable) || !existsSync(snapshot)) throw new Error("Initialize the Flutter SDK with flutter --version first.");
    flutterArgs.unshift(snapshot);
  }
  const result = spawnSync(executable, flutterArgs, { env, cwd: rootPath("flutter/"), stdio: "inherit" });
  if (result.error) throw new Error("Could not start Flutter.");
  process.exitCode = result.status ?? 1;
  if (result.status === 0 && command === "apk") {
    for (const abi of ["armeabi-v7a", "arm64-v8a", "x86_64"]) {
      const apk = rootPath(`flutter/build/app/outputs/flutter-apk/app-${mode}-${abi}-release.apk`);
      if (!existsSync(apk)) throw new Error("Flutter exited successfully but an expected split APK is missing.");
      console.log(apk);
    }
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (temporaryDirectory) {
    const defines = join(temporaryDirectory, "client.json");
    if (existsSync(defines)) unlinkSync(defines);
    rmdirSync(temporaryDirectory);
  }
}
