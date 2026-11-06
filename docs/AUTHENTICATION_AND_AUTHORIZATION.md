# Yalla 5roga — Authentication and Authorization

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-07 |
| Documentation version | 1.0.0 |
| Needs verification | Apple Sign-In production entitlements on each store build |

## Authentication vs authorization

| Concept | Meaning in this project |
|---------|-------------------------|
| **Authentication** | Proving identity via Firebase ID token (or establishing that session via email/password custom-token exchange). |
| **Authorization** | Checking whether that Firebase UID may perform an action on a **specific resource** (outing Owner, group owner, eligible voter, etc.). |

There is **no** global app role of Admin/Guest for outings. Outing Owner is `outings.created_by` only.

## Firebase Authentication

**Implemented client paths** (`FirebaseAuthService` / `AuthRepositoryImpl`):

- Google Sign-In
- Apple Sign-In
- Phone OTP
- Email/password via backend (`POST /api/auth/signup|login`) then `signInWithCustomToken`

Firebase holds identities. Neon `users.id` = Firebase UID.

## Email/password (backend-canonical)

1. Signup: hash password into `users.password_hash`, create Firebase user **without** Firebase password, return `idToken` + `customToken`.
2. Login: verify Neon hash, mint Firebase session the same way.
3. Client stores Firebase session; Dio uses refreshed ID tokens.

Google / Apple / phone skip password endpoints and call `POST /api/users/sync` after Firebase sign-in.

## ID token verification

`authMiddleware` (`backend/src/middleware/auth.middleware.ts`):

1. Parse `Authorization: Bearer …`
2. `admin.auth().verifyIdToken(token)`
3. Attach `req.user.uid` (and claim fields)
4. Reject missing/invalid → 401

Does not create Neon rows by itself.

## User synchronization

`POST /api/users/sync` (authenticated) upserts Neon `users` from token + optional body (name/email/phone/image). Also used to claim pending group invitations by verified phone where implemented.

## Token handling (Flutter)

- `AuthInterceptor` calls `firebaseAuth.idToken(forceRefresh:)` for each request.
- Session restore via `AuthProvider.restoreSession()`.
- Prefs may cache user display data; Bearer token comes from Firebase SDK, not a long-lived prefs API key.

## Authorization rules (resource)

| Action | Rule | Code anchors |
|--------|------|--------------|
| Update/delete/cancel outing | Caller = `created_by` | `outing-access`, cancel use case |
| Add/replace/delete vote options | Owner + voting open + deadline not passed | `voting.usecase` |
| Cast/change vote | Eligible voter + voting open | `assertEligibleVoter`, `assertVotingOpen` |
| Tie-break | Owner only + unresolved tie | `breakTieRandomly` |
| Attendance upsert | Participant; Owner forced Going | `attendance.usecase` |
| Accept/decline outing invite | Invitee | guests use cases |
| Remove member from outing | Owner; member self-remove forbidden | RemoveGuest |
| Chat send/list | Participant + open status | `chat-access` |
| Group mutate | Group owner/member rules | `group-access` |

## Eligible voters

Owner ∪ accepted `outing_guests` ∪ `group_members` of `outing.group_id`. Pending invites excluded. Attendance ignored.

## Security boundaries

- Flutter UI hiding buttons ≠ authorization.
- Confirmed winning place cannot be patched to a different location (`UpdateOutingUseCase` lock).
- Never trust client-sent `userId` for acting as another user when token UID is available.
- Places list GET may be public; mutations require auth.

## Deep links and auth

Unauthenticated invite open → auth → restore pending invite destination (`InviteDeepLinkProvider`). Opening link alone must not create membership without accept.

## Related

- [`PRODUCT_SCENARIOS.md`](PRODUCT_SCENARIOS.md) §§2–3, 16
- [`API_CONTRACTS.md`](API_CONTRACTS.md)
- [`SYSTEM_DESIGN.md`](SYSTEM_DESIGN.md)
