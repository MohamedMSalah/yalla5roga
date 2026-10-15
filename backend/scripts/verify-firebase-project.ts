import "dotenv/config";
import { getApp, getApps } from "firebase-admin/app";
import { getFirebaseAuth } from "../src/config/firebase.js";

const certs = (await fetch(
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com",
).then((response) => response.json())) as Record<string, string>;
const kid = Object.keys(certs)[0];
if (!kid) throw new Error("No public key ids returned");

const header = Buffer.from(JSON.stringify({ alg: "RS256", kid })).toString(
  "base64url",
);
const payload = Buffer.from(
  JSON.stringify({
    aud: "yalla-5roga",
    iss: "https://securetoken.google.com/yalla-5roga",
    iat: 1,
    exp: 2,
    email: "hidden@example.com",
    sub: "uid",
  }),
).toString("base64url");
const token = `${header}.${payload}.sig`;

const auth = getFirebaseAuth();

auth
  .verifyIdToken(token)
  .then(() => {
    console.log("unexpected-success");
  })
  .catch((error: { code?: string; message?: string }) => {
    const message = error.message ?? "";
    console.log(
      JSON.stringify({
        projectId: getApp().options.projectId ?? null,
        appCount: getApps().length,
        errorCode: error.code ?? null,
        incorrectAudience: message.includes("incorrect"),
        invalidSignature: message.includes("invalid signature"),
        unknownKid: message.includes("does not"),
      }),
    );
  });
