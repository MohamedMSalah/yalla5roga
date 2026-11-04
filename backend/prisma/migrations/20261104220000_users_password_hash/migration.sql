-- Neon-owned email/password credentials. Nullable so Google/Apple/phone users
-- remain valid without a local password.
ALTER TABLE "users" ADD COLUMN "password_hash" VARCHAR(255);
ALTER TABLE "users" ADD COLUMN "password_updated_at" TIMESTAMPTZ(6);
