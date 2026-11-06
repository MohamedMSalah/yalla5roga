# Baseline Audit — Product Scenario Compliance

**Date:** 2026-11-07  
**Method:** Documentation + selective source inspection + prior lifecycle test evidence. Device E2E / FCM delivery / concurrency harness were **NOT RUN** at baseline.

Legend: **PASS** | **PARTIAL** | **FAIL** | **NOT RUN** | **OPEN DECISION**

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Owner / Member only (no Guest role) | FAIL | `outing_guests` model + `/guests` APIs; eligibility includes guests |
| Invitation Pending/Accepted/Declined ≠ roles | PARTIAL | Group invitations have statuses; outing guest path lacks full invite lifecycle UI |
| Outing invite deep-link + post-auth restore | PARTIAL | Group invite deep links work; outing-level accept/decline incomplete |
| Group + Special Event shared features | PASS | Shared create/vote/attendance/chat paths |
| Lifecycle draft/voting/confirmed/cancelled | PASS | Prisma enum + Flutter enums aligned |
| Confirmed never → Voting; Cancelled locked | PARTIAL | Vote options blocked when closed; location PATCH still allowed after confirmed |
| Mandatory voting deadline | FAIL | Zod optional; nullable `vote_ends_at` |
| Server closes voting (deadline / all voted) | PASS | `vote-resolution.ts`, deadline job, lifecycle tests |
| Eligible = Owner + accepted Members | PARTIAL | Includes guests + group members; pending invites excluded |
| One vote per user upsert | PASS | PK `(outing_id, user_id)` + upsert |
| Tie-break owner RNG idempotent | PASS | `breakTieRandomly` + tests |
| Zero votes → cancel | PASS | Resolution path + tests |
| Candidate change resets all votes | FAIL | Option create/delete does not clear all votes |
| Confirmed place immutable | PARTIAL | Options locked; `UpdateOuting` can patch location |
| Attendance independent | PASS | Separate table/enum; owner Going |
| Chat draft/voting/confirmed only | PASS | `CHAT_OPEN_STATUSES` |
| Member cannot leave | PARTIAL | Self guest-remove forbidden |
| FCM token API + push sender | FAIL | Table exists; no token routes; dispatcher WhatsApp-only |
| Notification outbox | PARTIAL | Events written; push channel fails without sender |
| Saved outings Neon via Flutter | FAIL | Prefs-only repository |
| Saved places Flutter | FAIL | API constants only |
| Backend saved APIs | PASS | Routes + use cases exist |
| No Flutter mock stack | PASS (post Phase 2.5) | `lib/core/mock` deleted; `USE_MOCK_DATA` removed |
| Concurrency harness | NOT RUN | — |
| Flutter device E2E | NOT RUN | — |
| FCM device delivery | NOT RUN | — |

## Neon identity (pre-write check)

Verified without printing credentials:

- host: `ep-misty-glitter-av3zwlzf-pooler.c-11.us-east-1.aws.neon.tech`
- database: `neondb`
- protocol: `postgresql`
- matches authorized development target: **yes**
