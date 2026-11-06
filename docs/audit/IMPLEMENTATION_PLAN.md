# Implementation Plan — Product Scenario Compliance

Dependency order for remaining work after documentation SSoT and mock deletion.

## 1. Critical data integrity (backend)

1. Mandatory `vote_ends_at` on voting outings (validator + create datasource).
2. Explicit candidate replace/modify use case that deletes all outing votes in the same transaction, preserves deadline, notifies.
3. Block `location_*` / winning place changes after `confirmed`.
4. Normalize Guest → Member semantics: eligibility Owner + accepted members (+ group members of `outing.group_id`); deprecate Guest wording in APIs/docs; member leave remains forbidden.
5. Outing invitations with accept/decline where missing.

## 2. FCM infrastructure

1. Token register/delete APIs → `user_fcm_tokens`.
2. Firebase Admin Push channel registered in dispatcher.
3. Invalid token cleanup + outbox retries.
4. Flutter registers token after auth.

## 3. Flutter integration

1. Saved outings remote DS + repository (Neon SoT).
2. Saved places feature wiring.
3. Attendance not blocked by vote finalized.
4. Lifecycle refresh on countdown / after votes.
5. Owner cancel UI; cancelled badge; confirmed place lock in UI.
6. Candidate edit calling reset-aware API.
7. Outing invite deep-link accept/decline restore.

## 4. Testing

1. Backend unit/integration extensions.
2. Concurrency tests.
3. Flutter analyzer + unit tests.
4. Device E2E / FCM when available; else NOT RUN.

## 5. Final compliance report

Update PRODUCT_SCENARIOS “Current implementation”, API_CONTRACTS, DATABASE_ARCHITECTURE, and write `FINAL_COMPLIANCE_REPORT.md`.

## Safety

No destructive Neon ops without explicit approval. Prefer additive migrations.
