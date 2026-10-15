import fs from "node:fs";

const file = new URL("../src/routes/outings/outing.routes.ts", import.meta.url);
const text = fs.readFileSync(file, "utf8");
const marker = "export default router;";
const cut = text.indexOf(marker);
if (cut < 0) {
  throw new Error("marker missing");
}
const next = text.slice(0, cut + marker.length) + "\n";
fs.writeFileSync(file, next);
