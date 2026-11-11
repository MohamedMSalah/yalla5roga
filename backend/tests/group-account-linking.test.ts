import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { Auth, DecodedIdToken, UserRecord } from "firebase-admin/auth";
import type { IUserRepository } from "../src/repositories/users/i-user.repository.js";
import type { User } from "../src/types/users/user.types.js";
import { FirebasePhoneIdentity } from "../src/services/phone/phone-identity.js";
import { hashPassword } from "../src/services/auth/password.js";
import { SignupUseCase } from "../src/usecases/auth/signup.usecase.js";
import { LoginUseCase } from "../src/usecases/auth/login.usecase.js";
import { SyncUserUseCase } from "../src/usecases/users/sync-user.usecase.js";
import { signupBodySchema } from "../src/validators/auth/auth.validator.js";
import { ConflictError, UnauthorizedError } from "../src/utils/errors.js";

const PHONE = "+201001234567";
const UID = "verified-otp-uid";
const session = async (uid: string) => ({uid, idToken: "id", customToken: "custom", refreshToken: "refresh", expiresIn: "3600"});

function fixture() {
  const rows = new Map<string, User>();
  const claimed: Array<{userId: string; verifiedPhone?: string | null}> = [];
  const users = {
    findById: async (id: string) => rows.get(id) ?? null,
    findByPhone: async (phone: string) => [...rows.values()].find(u => u.phone === phone) ?? null,
    create: async (input: Partial<User> & { id: string }) => {
      const user = {name:"B", phone:PHONE, created_at:new Date(), updated_at:new Date(), image_url:null, password_hash:null, password_updated_at:null, ...input} as User;
      rows.set(user.id, user);
      return user;
    },
    update: async (id: string, patch: Partial<User>) => {
      const user = {...rows.get(id)!, ...patch}; rows.set(id, user); return user;
    },
  } as IUserRepository;
  const claims = {execute: async (input: {userId:string; verifiedPhone?:string|null}) => {claimed.push(input); return [];}};
  const phones = {verifyProof:async () => ({uid:UID, phone:PHONE}), verifiedPhone:async () => PHONE, bindPhone:async () => {}};
  return {users, rows, claims, claimed, phones};
}

describe("group membership identity across registration and login", () => {
  it("requires server-verifiable OTP proof in the signup contract", () => {
    assert.equal(signupBodySchema.safeParse({name:"B", phone:PHONE, password:"secret123"}).success, false);
  });
  it("retains the verified Firebase UID and claims pre-registration invitations before returning", async () => {
    const f = fixture();
    const result = await new SignupUseCase(f.users, f.phones, f.claims, session).execute({name:"B", phone:"01001234567", password:"secret123", phoneVerificationToken:"proof"});
    assert.equal(result.uid, UID);
    assert.equal(result.user?.id, UID);
    assert.equal(result.user?.phone, PHONE);
    assert.deepEqual(f.claimed, [{userId:UID, verifiedPhone:PHONE}]);
    assert.equal(f.rows.size, 1);
    assert.ok(f.rows.get(UID)?.password_hash);
  });
  it("rejects proof for a different phone without creating a user", async () => {
    const f = fixture();
    await assert.rejects(new SignupUseCase(f.users, f.phones, f.claims, session).execute({name:"B", phone:"01112345678", password:"secret123", phoneVerificationToken:"proof"}), UnauthorizedError);
    assert.equal(f.rows.size, 0);
    assert.equal(f.claimed.length, 0);
  });
  it("never overwrites an existing profile or password through OTP signup", async () => {
    const f = fixture(); await f.users.create({id:UID, name:"Original", phone:null});
    await assert.rejects(new SignupUseCase(f.users, f.phones, f.claims, session).execute({name:"B", phone:PHONE, password:"secret123", phoneVerificationToken:"proof"}), ConflictError);
    assert.equal(f.rows.get(UID)?.name, "Original");
  });
  it("claims invitations on password login for the same verified identity", async () => {
    const f = fixture(); await f.users.create({id:UID, name:"B", phone:PHONE, password_hash:await hashPassword("secret123")});
    await new LoginUseCase(f.users, f.phones, f.claims, session).execute({phone:"01001234567", password:"secret123"});
    assert.deepEqual(f.claimed, [{userId:UID, verifiedPhone:PHONE}]);
  });
  it("does not claim from an unverified profile phone on password login", async () => {
    const f = fixture(); await f.users.create({id:UID, name:"B", phone:PHONE, password_hash:await hashPassword("secret123")});
    const phones = {verifiedPhone:async () => null};
    await new LoginUseCase(f.users, phones, f.claims, session).execute({phone:PHONE, password:"secret123"});
    assert.deepEqual(f.claimed, []);
  });
  it("does not look up a phone or claim memberships for an incorrect password", async () => {
    const f = fixture(); await f.users.create({id:UID, name:"B", phone:PHONE, password_hash:await hashPassword("secret123")});
    await assert.rejects(new LoginUseCase(f.users, {verifiedPhone:async () => {throw Error("must not run");}}, f.claims, session).execute({phone:PHONE, password:"incorrect"}), UnauthorizedError);
    assert.equal(f.claimed.length, 0);
  });
  it("repairs an orphan OTP identity after fresh proof while preserving the account ID", async () => {
    const f = fixture(); await f.users.create({id:"canonical", name:"B", phone:PHONE});
    const bindings: unknown[] = [];
    const phones = {...f.phones, bindPhone:async (...args:unknown[]) => {bindings.push(args);}};
    const result = await new SyncUserUseCase(f.users, f.claims, phones).execute({id:"canonical", phoneVerificationToken:"proof"});
    assert.equal(result.user.id, "canonical");
    assert.deepEqual(bindings, [["canonical", {uid:UID, phone:PHONE}]]);
    assert.deepEqual(f.claimed, [{userId:"canonical", verifiedPhone:PHONE}]);
  });
  it("refuses to transfer a phone from another registered account", async () => {
    const f = fixture(); await f.users.create({id:UID, name:"Other", phone:null});
    await f.users.create({id:"canonical", name:"B", phone:PHONE});
    await assert.rejects(new SyncUserUseCase(f.users, f.claims, {...f.phones, bindPhone:async () => {throw Error("must not run");}}).execute({id:"canonical", phoneVerificationToken:"proof"}), ConflictError);
    assert.equal(f.claimed.length, 0);
  });
});

describe("Firebase phone ownership proof", () => {
  const now = 1_800_000_000_000;
  function identity(overrides: Partial<DecodedIdToken> = {}) {
    const records = new Map<string,string|null>([[UID, PHONE], ["canonical", null]]);
    const updates: unknown[] = [];
    const auth = {
      verifyIdToken:async (_token:string, revoked:boolean) => {
        assert.equal(revoked, true);
        return {uid:UID, phone_number:PHONE, auth_time:now/1000, firebase:{sign_in_provider:"phone", identities:{}}, ...overrides} as DecodedIdToken;
      },
      getUser:async (uid:string) => ({uid, phoneNumber:records.get(uid)}) as UserRecord,
      updateUser:async (uid:string, patch:{phoneNumber:string|null}) => {updates.push([uid,patch]); records.set(uid,patch.phoneNumber); return {uid} as UserRecord;},
    };
    return {service:new FirebasePhoneIdentity(() => auth as unknown as Auth, () => now), records, updates, auth};
  }
  it("checks a recent phone sign-in and the current Firebase phone record", async () => {
    const f = identity(); assert.deepEqual(await f.service.verifyProof("proof"), {uid:UID, phone:PHONE});
  });
  it("rejects stale phone proof", async () => {
    await assert.rejects(identity({auth_time:now/1000-601}).service.verifyProof("proof"), UnauthorizedError);
  });
  it("rejects a custom-token session presented as fresh OTP proof", async () => {
    await assert.rejects(identity({firebase:{sign_in_provider:"custom", identities:{}}}).service.verifyProof("proof"), UnauthorizedError);
  });
  it("rejects a token whose phone credential has since moved", async () => {
    const f = identity(); f.records.set(UID,null);
    await assert.rejects(f.service.verifyProof("proof"), UnauthorizedError);
  });
  it("moves only the phone credential and never deletes an identity", async () => {
    const f = identity(); await f.service.bindPhone("canonical", {uid:UID,phone:PHONE});
    assert.deepEqual(f.updates, [[UID,{phoneNumber:null}],["canonical",{phoneNumber:PHONE}]]);
  });
  it("restores the source phone if binding the canonical identity fails", async () => {
    const f = identity(); const update = f.auth.updateUser;
    f.auth.updateUser = async (uid, patch) => {if(uid === "canonical") throw Error("binding unavailable"); return update(uid,patch);};
    await assert.rejects(f.service.bindPhone("canonical", {uid:UID,phone:PHONE}), /binding unavailable/);
    assert.equal(f.records.get(UID), PHONE);
  });
});
