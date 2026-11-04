import "dotenv/config";
import { PrismaClient } from "@prisma/client";

const p = new PrismaClient();
const rows = await p.$queryRawUnsafe(
  `SELECT conname, pg_get_constraintdef(oid) AS def
   FROM pg_constraint
   WHERE conrelid = 'place_hours'::regclass AND contype = 'c'`,
);
console.log(JSON.stringify(rows, null, 2));
await p.$disconnect();
