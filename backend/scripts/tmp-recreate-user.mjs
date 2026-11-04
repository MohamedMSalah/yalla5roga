import "dotenv/config";
import { PrismaClient } from "@prisma/client";
import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const email = "mm.6800771@gmail.com";
const password = "M0h@med74#";
const name = "MESO";
const phone = "+201552257207";

const prisma = new PrismaClient();

if (getApps().length === 0) {
  initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID,
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
  });
}

const auth = getAuth();
const existing = await prisma.users.findUnique({ where: { email } });

if (existing) {
  await prisma.users.delete({ where: { id: existing.id } });
  console.log("Deleted Neon user:", existing.id);
  try {
    await auth.deleteUser(existing.id);
    console.log("Deleted Firebase user:", existing.id);
  } catch (error) {
    console.log(
      "Firebase delete:",
      error instanceof Error ? error.message : String(error),
    );
  }
} else {
  console.log("No Neon user for", email);
  try {
    const byEmail = await auth.getUserByEmail(email);
    await auth.deleteUser(byEmail.uid);
    console.log("Deleted orphan Firebase user:", byEmail.uid);
  } catch (error) {
    console.log(
      "Firebase lookup/delete:",
      error instanceof Error ? error.message : String(error),
    );
  }
}

await prisma.$disconnect();

const signup = await fetch("http://localhost:3000/api/auth/signup", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ name, email, password, phone }),
});
const signupBody = await signup.json();
console.log("SIGNUP_STATUS:", signup.status);
console.log(
  JSON.stringify(
    {
      success: signupBody.success,
      message: signupBody.message,
      uid: signupBody.data?.uid,
      hasIdToken: Boolean(signupBody.data?.idToken),
      user: signupBody.data?.user,
    },
    null,
    2,
  ),
);

if (!signup.ok) process.exit(1);

const login = await fetch("http://localhost:3000/api/auth/login", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email, password }),
});
const loginBody = await login.json();
console.log("LOGIN_STATUS:", login.status);
console.log(
  JSON.stringify(
    {
      success: loginBody.success,
      message: loginBody.message,
      uid: loginBody.data?.uid,
      hasIdToken: Boolean(loginBody.data?.idToken),
      user: loginBody.data?.user,
    },
    null,
    2,
  ),
);
