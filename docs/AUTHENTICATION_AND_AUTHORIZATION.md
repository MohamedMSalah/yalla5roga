# Yalla 5roga — Authentication and Authorization

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-08 |
| Documentation version | 1.0.0 |
| Needs verification | Apple Sign-In production entitlements on each store build |

## Authentication vs authorization

| Concept | Meaning in this project |
|---------|-------------------------|
| **Authentication** | Proving identity via Firebase ID token (or establishing that session via email/password custom-token exchange). |
| **Authorization** | Checking whether that Firebase UID may perform an action on a **specific resource** (outing Owner, group owner, eligible voter, etc.). |

There is **no** global app role of Admin/Guest for outings. Outing Owner is `outings.created_by` only.

## Current transition: phone/password

The app now uses phone and password for registration and login; Google and Apple buttons have been removed. Neon verifies the password and the backend issues a Firebase custom-token session. Registration OTP is currently checked only by the client, so the signup API must not be treated as proof of phone ownership. Existing social-only users need an account migration or recovery flow before this change is deployed. The historical descriptions below require reconciliation.

## Firebase Authentication (historical)

**Implemented client paths** (`FirebaseAuthService` / `AuthRepositoryImpl`):

- Google Sign-In
- Apple Sign-In
- Phone OTP
- Email/password via backend (`POST /api/auth/signup|login`) then `signInWithCustomToken`

Firebase Auth is **identity-only** (UID + ID tokens). It is **not** the application database — profiles, passwords, groups, outings, and related data live in Neon only. Neon `users.id` = Firebase UID.

## Email/password (backend-canonical)

1. Signup: store name/email/phone/`password_hash` in Neon; create a **bare** Firebase Auth UID (no email, displayName, or password written to Firebase); return `idToken` + `customToken`.
2. Login: verify Neon hash, mint Firebase session the same way.
3. Client stores Firebase session; Dio uses refreshed ID tokens.
4. Change password: the separate Flutter password form checks the new password confirmation before submitting. authenticated `POST /api/auth/change-password` verifies `currentPassword` against Neon and stores a new bcrypt hash (Firebase Auth is not updated).
5. Confirm password: authenticated `POST /api/auth/verify-password` checks the Neon hash without changing it (edit-profile confirmation).

Public user JSON exposes `has_password` (never the hash) so Flutter can show edit-password UI for Neon accounts. Phone verification for the settings chip is Firebase `phoneNumber` on the signed-in identity (OTP-linked), not merely a Neon `phone` profile value.

Google / Apple / phone skip password endpoints and call `POST /api/users/sync` after Firebase sign-in (Neon profile upsert).

## ID token verification

Socket.IO chat connections (`backend/src/realtime/socket-auth.ts`) verify the same Firebase ID token from handshake `auth.token` (or `Authorization` / `?token=`). Socket identity is always `decoded.uid`; `outing:join` still runs `assertChatParticipant`.

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
| Update/delete/cancel outing | Caller = `created_by` | `outing-access`, delete and cancel use cases |
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

### Settings account actions

Logout replaces the route stack with the login form and clears account-scoped providers. An unverified profile number can be verified with Firebase SMS from Settings. Changes to a different number still require current-password confirmation for password accounts. Flutter syncs the confirmed number to Neon after Firebase verification.

The verified chip reflects a Firebase phone matching the current Neon profile number. Firebase may reject linking a number that belongs to another Firebase UID, including a separate identity created by a prior signup OTP. That conflict requires identity reconciliation before linking.
