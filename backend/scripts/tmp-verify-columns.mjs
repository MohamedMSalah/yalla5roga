import "dotenv/config";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const rows = await prisma.$queryRawUnsafe(`
  SELECT column_name, data_type, character_maximum_length, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name IN ('password_hash', 'password_updated_at')
  ORDER BY column_name
`);
console.log(JSON.stringify(rows, null, 2));
await prisma.$disconnect();
