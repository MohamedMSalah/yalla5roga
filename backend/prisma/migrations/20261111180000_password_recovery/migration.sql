CREATE TABLE "password_recoveries" (
 "request_hash" CHAR(64) PRIMARY KEY,
 "user_id" VARCHAR(128) NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
 "phone" VARCHAR(16) NOT NULL,
 "password_version" CHAR(64) NOT NULL,
 "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "expires_at" TIMESTAMPTZ(6) NOT NULL,
 "proof_hash" CHAR(64) UNIQUE,
 "reset_hash" CHAR(64) UNIQUE,
 "consumed_at" TIMESTAMPTZ(6)
);
CREATE INDEX "password_recoveries_expires_at_idx" ON "password_recoveries"("expires_at");
CREATE TABLE "password_recovery_limits" (
 "key" CHAR(64) PRIMARY KEY,
 "attempts" INTEGER NOT NULL,
 "expires_at" TIMESTAMPTZ(6) NOT NULL
);
CREATE INDEX "password_recovery_limits_expires_at_idx" ON "password_recovery_limits"("expires_at");
