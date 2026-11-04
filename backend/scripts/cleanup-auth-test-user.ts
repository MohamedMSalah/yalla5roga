import "dotenv/config";
import { getFirebaseAuth } from "../src/config/firebase.js";
import { prisma } from "../src/config/database.js";

const uid = process.argv[2];
if (!uid) {
  console.error("Usage: tsx scripts/cleanup-auth-test-user.ts <uid>");
  process.exit(1);
}

await getFirebaseAuth().deleteUser(uid);
await prisma.users.delete({ where: { id: uid } }).catch(() => null);
await prisma.$disconnect();
console.log("cleaned", uid);
