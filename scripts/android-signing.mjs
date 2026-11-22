import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { rootPath } from "./environment.mjs";

export function validateReleaseSigning() {
  const path = rootPath("flutter/android/key.properties");
  if (!existsSync(path)) throw new Error("Configure release signing in ignored flutter/android/key.properties (both release flavors require it).");
  // Java Properties escaping, including Windows paths and unicode escapes.
  const unescape = value => value.replace(/\\u([0-9a-fA-F]{4})|\\(.)/g,
    (_, unicode, char) => unicode ? String.fromCharCode(parseInt(unicode, 16)) : ({ n: "\n", r: "\r", t: "\t", f: "\f" }[char] ?? char));
  const values = {};
  const lines = readFileSync(path, "utf8").replace(/\\\r?\n\s*/g, "").split(/\r?\n/);
  for (const line of lines) {
    if (/^\s*[#!]/.test(line) || !line.trim()) continue;
    const match = line.match(/^\s*([^\s=:]+)\s*(?:[=:]\s*|\s+)(.*)$/);
    if (match) values[match[1]] = unescape(match[2]);
  }
  const missing = ["storeFile", "storePassword", "keyAlias", "keyPassword"].filter(key => !values[key]);
  if (missing.length) throw new Error(`Missing release signing properties: ${missing.join(", ")}.`);
  if (!existsSync(resolve(dirname(path), values.storeFile))) throw new Error("Release signing keystore does not exist at the configured storeFile.");
  return true;
}
