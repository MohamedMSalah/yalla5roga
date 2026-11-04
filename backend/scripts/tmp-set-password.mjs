import "dotenv/config";
import bcrypt from "bcrypt";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const email = "mm.6800771@gmail.com";
const password = "M0h@med74#";

const hash = await bcrypt.hash(password, 12);
const updated = await prisma.users.update({
  where: { email },
  data: {
    password_hash: hash,
    password_updated_at: new Date(),
  },
  select: {
    id: true,
    email: true,
    password_updated_at: true,
  },
});

console.log(JSON.stringify(updated, null, 2));
await prisma.$disconnect();
