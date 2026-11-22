import { Resolver } from "node:dns/promises";
import https from "node:https";
import { BlockList, isIP } from "node:net";
import { ValidationError } from "../../utils/errors.js";

const blocked = new BlockList();
for (const [address, bits] of [
  ["0.0.0.0", 8], ["10.0.0.0", 8], ["100.64.0.0", 10], ["127.0.0.0", 8],
  ["169.254.0.0", 16], ["172.16.0.0", 12], ["192.0.0.0", 24], ["192.0.2.0", 24],
  ["192.88.99.0", 24], ["192.168.0.0", 16], ["198.18.0.0", 15], ["198.51.100.0", 24],
  ["203.0.113.0", 24], ["224.0.0.0", 3],
] as const) blocked.addSubnet(address, bits, "ipv4");

export async function downloadCatalogImage(source: string, maxBytes: number) {
  const url = URL.parse(source);
  const allowed = (process.env.PLACE_IMAGE_SOURCE_HOSTS ?? "").split(",").map(host => host.trim().toLowerCase());
  if (!url || url.protocol !== "https:" || url.username || url.password || url.port ||
    isIP(url.hostname) || !allowed.includes(url.hostname)) {
    throw new ValidationError("Catalog image origin is outside PLACE_IMAGE_SOURCE_HOSTS");
  }
  const resolver = new Resolver({ timeout: 3000, tries: 1 });
  const addresses = await resolver.resolve4(url.hostname);
  if (!addresses.length || addresses.some(address => blocked.check(address, "ipv4"))) {
    throw new ValidationError("Catalog image origin did not resolve to a public address");
  }
  // Pin a public IPv4 answer and retain certificate validation against the URL's
  // hostname. The transport does not follow redirects or use a shared agent.
  return new Promise<{ bytes: Buffer; mimeType: string }>((resolve, reject) => {
    const request = https.get(url, {
      agent: false, family: 4, signal: AbortSignal.timeout(10000),
      lookup: (_hostname, _options, callback) => callback(null, addresses[0], 4),
      headers: { Accept: "image/webp,image/jpeg,image/png,image/gif" },
    }, response => {
      const mimeType = response.headers["content-type"]?.split(";")[0].trim().toLowerCase();
      if (response.statusCode !== 200 || !mimeType ||
        (response.headers["content-encoding"] && response.headers["content-encoding"] !== "identity") ||
        Number(response.headers["content-length"]) > maxBytes) {
        response.destroy();
        reject(new ValidationError("Catalog image source response was rejected"));
        return;
      }
      const chunks: Buffer[] = [];
      let bytes = 0;
      response.on("error", reject);
      response.on("data", (chunk: Buffer) => {
        bytes += chunk.length;
        if (bytes > maxBytes) {
          reject(new ValidationError("Catalog image exceeds the allowed size"));
          response.destroy();
        } else chunks.push(chunk);
      });
      response.once("end", () => resolve({ bytes: Buffer.concat(chunks), mimeType }));
    });
    request.once("error", reject);
  });
}
