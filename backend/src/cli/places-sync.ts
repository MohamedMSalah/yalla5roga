import "dotenv/config";
import { prisma } from "../config/database.js";
import {
  synchronizePlaces,
  syncStatus,
} from "../services/places/places-sync.js";
const args = process.argv.slice(2);
try {
  const limitArg = args.indexOf("--limit");
  if (
    args.some(
      (a) =>
        ![
          "--dry-run",
          "--due-only",
          "--status",
          "--limit",
          "--initial",
        ].includes(a) && !(limitArg >= 0 && a === args[limitArg + 1]),
    )
  )
    throw new Error(
      "Usage: places:sync [--dry-run] [--initial | --limit N] [--due-only] [--status]",
    );
  console.log(
    JSON.stringify(
      args.includes("--status")
        ? await syncStatus()
        : await synchronizePlaces({
            dryRun: args.includes("--dry-run"),
            dueOnly: args.includes("--due-only"),
            limit:
              limitArg >= 0
                ? Number(args[limitArg + 1])
                : args.includes("--initial")
                  ? Number(process.env.PLACES_INITIAL_IMPORT_LIMIT ?? 1000)
                  : undefined,
          }),
      null,
      2,
    ),
  );
} catch (error) {
  console.error(error instanceof Error ? error.message : "Sync failed");
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
