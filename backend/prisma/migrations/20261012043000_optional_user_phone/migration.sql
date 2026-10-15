-- Google and Apple accounts can register before a phone number is verified.
-- Widening the column lets a later verified E.164 number be stored.
ALTER TABLE "users" ALTER COLUMN "phone" DROP NOT NULL;
ALTER TABLE "users" ALTER COLUMN "phone" SET DATA TYPE VARCHAR(16);
