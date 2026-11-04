import "dotenv/config";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const email = "mm.6800771@gmail.com";

const user = await prisma.users.findUnique({
  where: { email },
  select: {
    id: true,
    email: true,
    name: true,
    phone: true,
    password_hash: true,
    password_updated_at: true,
    created_at: true,
  },
});

console.log(
  JSON.stringify(
    user
      ? {
          ...user,
          password_hash: user.password_hash
            ? `set(len=${user.password_hash.length})`
            : null,
        }
      : null,
    null,
    2,
  ),
);

await prisma.$disconnect();
