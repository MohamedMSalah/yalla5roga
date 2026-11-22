BEGIN;

CREATE TABLE "account_deletions" (
  "account_key" CHAR(64) PRIMARY KEY,
  "firebase_uid" VARCHAR(128),
  "firebase_disabled_at" TIMESTAMPTZ(6),
  "requested_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "retry_after" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" TIMESTAMPTZ(6)
);

CREATE INDEX "idx_account_deletions_pending"
  ON "account_deletions" ("completed_at", "retry_after");

CREATE TABLE "account_deletion_media" (
  "account_key" CHAR(64) NOT NULL,
  "object_key" VARCHAR(512) NOT NULL,
  "bucket" VARCHAR(255) NOT NULL,
  "purpose" "media_purpose" NOT NULL,
  "visibility" "media_visibility" NOT NULL,
  "purge_after" TIMESTAMPTZ(6) NOT NULL,
  PRIMARY KEY ("account_key", "object_key"),
  CONSTRAINT "account_deletion_media_account_key_fkey" FOREIGN KEY ("account_key")
    REFERENCES "account_deletions" ("account_key") ON DELETE CASCADE ON UPDATE NO ACTION
);

ALTER TABLE "users" DROP CONSTRAINT "users_phone_e164";
ALTER TABLE "users" ADD CONSTRAINT "users_phone_e164" CHECK (
  ("id" = 'system:deleted-account' AND "phone" = '+0' AND "password_hash" IS NULL)
  OR ("id" <> 'system:deleted-account' AND "phone" ~ '^[+][1-9][0-9]{1,14}$')
);

-- Firebase custom tokens minted before deletion can otherwise recreate a UID.
CREATE FUNCTION reject_deleted_account() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "account_deletions"
    WHERE "account_key" = encode(sha256(convert_to(NEW."id", 'UTF8')), 'hex')
  ) THEN
    RAISE EXCEPTION 'Account deleted' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER "users_reject_deleted_account"
  BEFORE INSERT OR UPDATE OF "id" ON "users"
  FOR EACH ROW EXECUTE FUNCTION reject_deleted_account();

COMMIT;
