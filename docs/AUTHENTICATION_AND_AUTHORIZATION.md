# Yalla 5roga — Authentication and Authorization

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-10 |
| Documentation version | 1.0.0 |
| Needs verification | Recovery for historical accounts without a usable phone and password |

## Authentication vs authorization

| Concept | Meaning in this project |
|---------|-------------------------|
| **Authentication** | Proving identity via Firebase ID token (or establishing that session via phone/password custom-token exchange). |
| **Authorization** | Checking whether that Firebase UID may perform an action on a **specific resource** (outing Owner, group owner, eligible voter, etc.). |

There is **no** global app role of Admin/Guest for outings. Outing Owner is `outings.created_by` only.

## Firebase Authentication

Firebase provides the UID, phone OTP proof, ID tokens and refresh sessions. Neon stores application profiles and bcrypt hashes. The Firebase UID is the stable Neon primary key and the E.164 phone is the unique lookup address.

Signup requires an ID token from a phone OTP sign-in within ten minutes. The backend verifies revocation, provider, the current Firebase phone record and normalized phone equality. It retains the verified UID and links pending invitation identities without membership before returning. Retrying with the same verified UID, phone and password preserves the original profile and hash. An already registered UID or phone cannot be claimed with OTP alone.

## Phone/password (backend-canonical)

1. Signup: store name/phone/`password_hash` in Neon under the OTP-verified Firebase UID; return the existing `idToken` + `customToken` session. Firebase retains the verified phone credential for identity proof, never the application password or profile.
2. Login: verify the Neon hash and mint the Firebase session without OTP. Signup and login share a per-process, per-IP attempt limit.
3. Client stores Firebase session; Dio uses refreshed ID tokens.
4. Change password: the separate Flutter password form checks the new password confirmation before submitting. authenticated `POST /api/auth/change-password` verifies `currentPassword` against Neon and stores a new bcrypt hash (Firebase Auth is not updated).
5. Confirm password: authenticated `POST /api/auth/verify-password` checks the Neon hash without changing it (edit-profile confirmation).

Public user JSON exposes `has_password` (never the hash) so Flutter can show edit-password UI for Neon accounts. Phone verification for the settings chip is Firebase `phoneNumber` on the signed-in identity (OTP-linked), not merely a Neon `phone` profile value.

New passwords are limited to 72 UTF-8 bytes to avoid bcrypt truncation.

## ID token verification

Socket.IO chat connections (`backend/src/realtime/socket-auth.ts`) verify the same Firebase ID token from handshake `auth.token` (or `Authorization` / `?token=`). Socket identity is always `decoded.uid`; `outing:join` still runs `assertChatParticipant`.

`authMiddleware` (`backend/src/middleware/auth.middleware.ts`):

1. Parse `Authorization: Bearer …`
2. Verify the Firebase ID token and require the `phone` or `custom` sign-in provider for application REST and Socket.IO sessions.
3. Attach `req.user.uid` (and claim fields)
4. Reject missing/invalid → 401

Does not create Neon rows by itself.

## User synchronization

`POST /api/users/sync` provisions or synchronizes the Neon user under the Firebase UID. Automatic membership linking requires the token phone to match the current Firebase phone credential. Signup verifies fresh OTP proof and login checks the canonical UID’s Firebase credential before linking pending memberships. If OTP sync creates the profile first, signup can enroll the initial password with a conditional write that preserves the profile and any concurrently set password. Session restore exposes the matching cached profile immediately. The coordinator performs one deferred account sync after cached shell hydration and before online group revalidation; ordinary profile reads use GET /api/users/cuser.

For legacy signup identities, Settings OTP can return an optional `phoneVerificationToken` to sync while preserving the original Bearer session. After fresh proof, the backend moves the phone credential only if the OTP UID has no separate Neon account and the phone is available to the caller. It does not merge accounts, delete identities, or change PostgreSQL primary keys. If the Firebase target update fails, it restores the source phone credential. Existing affected users must verify once in Settings; a matching unverified Neon profile phone never silently grants membership.

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
| Arrival list / self check-in | Owner, accepted outing members, or group members. Check-in identity comes from Firebase UID. | `arrivals.usecase` |
| Special-event phone invitation | Authenticated event creator attests WhatsApp recipient agreement. Phone recipients receive event details without membership. | `CreateOutingUseCase` |
| Accept/decline outing invite | Invitee | guests use cases |
| Remove member from outing | Owner; member self-remove forbidden | RemoveGuest |
| Chat send/list | Participant + open status | `chat-access` |
| Group mutate | Group owner/member rules | `group-access` |
| Place catalog mutate (place, hours, images, prices) | Firebase UID listed in server-only `PLACES_CURATOR_UIDS`; fails closed when unset | `place-curator.middleware.ts` |
| User directory lookup | Authenticated; requires explicit `ids` (max 100) or exact `phone`; response omits phone/credential fields | `listUsersQuerySchema`, `toUserSummary` |
| Media upload intent | Authenticated; profile=self, group/outing with entity = owner/creator, chat = participant, place = catalog mutation APIs | `services/media/media-access.ts` |
| Media confirm/delete | Asset `owner_id` = Bearer UID (other users get `404`) | `media.service.ts` |
| Media view | Owner; profile = any authenticated; place/public = any authenticated; group/outing/chat = membership/participant eligibility | `canViewMedia` |

## Eligible voters

Owner ∪ accepted `outing_guests` ∪ `group_members` of `outing.group_id`. Pending invites excluded. Attendance ignored.

## Security boundaries

- Flutter UI hiding buttons ≠ authorization.
- Confirmed winning place cannot be patched to a different location (`UpdateOutingUseCase` lock).
- Never trust client-sent `userId` for acting as another user when token UID is available.
- Places list GET may be public; catalog mutations require a bearer token whose UID is listed in `PLACES_CURATOR_UIDS`. This is server configuration, not a new product role; the allowlist fails closed when the variable is missing.
- Media assets are keyed by object key and owned by the Bearer UID. Signed delivery URLs are short-lived and issued only after the same authorization checks as the entity read; clients must not persist them as entity data or share them across accounts.

## Deep links and auth

Unauthenticated invite open → auth → restore pending invite destination (`InviteDeepLinkProvider`). Opening link alone must not create membership without accept.

Notification taps wait for session restoration or sign-in and the authenticated shell. Push payloads with a recipient are scoped to that signed-in account. Group, outing, and message reads enforce membership on the backend, and the inbox read endpoint checks ownership.

## Related

- [`PRODUCT_SCENARIOS.md`](PRODUCT_SCENARIOS.md) §§2–3, 16
- [`API_CONTRACTS.md`](API_CONTRACTS.md)
- [`SYSTEM_DESIGN.md`](SYSTEM_DESIGN.md)

### Settings account actions

Logout replaces the route stack with the login form and clears account-scoped providers. An unverified profile number can be verified with Firebase SMS from Settings. Changes to a different number still require current-password confirmation for password accounts. Flutter syncs the confirmed number to Neon after Firebase verification.

The verified chip reflects a Firebase phone matching the current Neon profile number. A credential conflict from an unused legacy OTP UID is repaired through the verified sync flow above; conflicts with another registered identity remain rejected. Successful verification refreshes groups once to show newly claimed memberships.

RSVP reads and writes require current participation. GPS arrival requires current group membership on group outings, including for the creator. The backend derives the subject UID from the authenticated Firebase token and accepts only a bounded location sample for that user. Roster invalidations are routed to authenticated participant user rooms. Client coordinates remain client-reported evidence. Group pending associations continue to link only through verified phone ownership and transactionally link invitation identity without accepting.


## Account synchronization versus data reads — 2026-11-11

Session restoration first exposes the matching cached account. After cached shell hydration, one deferred authenticated account sync links pending invitation identities before online group-list revalidation. A successful sync is not repeated by general refresh/resume. Offline/failed synchronization remains pending for recovery. Profile refresh uses GET `/api/users/cuser`; it does not call users/sync or force ID-token refresh. Sync remains available for OTP provisioning and explicit verified-phone/account changes. Concurrent identical syncs and profile refreshes are coalesced. Firebase remains the identity provider; Neon owns profiles and membership.


### Authentication request reliability

Flutter applies default 15-second connection, send and receive limits, and bounds Firebase sign-in and token calls. OTP requests use one 75-second deadline for Firebase native invocation/callbacks, allowing the SDK’s 60-second retrieval window; normal API/token deadlines remain 15 seconds. Invocation failures are observed immediately and late callbacks are ignored. Authentication failures preserve network and timeout classifications for localized snackbar feedback. Login, signup and user sync do not use the interceptor’s automatic 401 retry; sync remains deduplicated. Firebase UID and Neon account ownership remain unchanged. Firebase SDK operations cannot be cancelled by Dart timeouts, so a timed-out operation can still complete in the SDK.


## Realtime room authorization — 2026-11-11

The same verified session socket owns `user:{decoded.uid}`, authorized `group:{UUID}` subscriptions and participant-authorized `outing:{UUID}` chat rooms. Group joins validate UUIDs and query current Neon membership; client-provided identities or room names cannot grant access. Message and read-receipt delivery both filter the current outing audience even when removed users remain in old rooms. Complete attendance events use owner/accepted-guest/group-member eligibility, excluding pending-only guests. Historical attendance replay carries only identifiers and obtains fresh REST authorization. Client session generations discard old callbacks and cursors on logout/account switches. No new authentication method is introduced.

## Forgot password — 2026-11-11

Audit confirmed that `LoginUseCase` and `ChangePasswordUseCase` use Neon `users.password_hash` (bcrypt cost 12). Firebase is the identity/session and phone-proof provider; setting a Firebase password would not update the credential consumed by phone/password login. Recovery therefore updates the existing Neon hash, without introducing a second authority.

1. `POST /api/auth/recovery/start` normalizes the registered phone, requires an existing password and the same current enabled Firebase phone on the canonical UID, then creates a ten-minute request secret.
2. Flutter reuses Firebase SMS sending. OTP credential verification happens in an ephemeral secondary Firebase Auth instance, signs out/deletes that instance, and never syncs/provisions a Neon profile or changes the primary session.
3. `POST /api/auth/recovery/verify` accepts only the request secret and Firebase phone ID token. Admin verifies signature/project/expiry/revocation, phone sign-in provider, current phone credential and exact UID/phone equality. `auth_time` must be at/after request creation (second precision), no later than server time and at most five minutes old. A unique digest of UID + auth_time prevents proof replay, including refreshed ID tokens. A random 256-bit reset secret is issued for five minutes.
4. `POST /api/auth/recovery/reset` accepts the reset secret and matching passwords. Passwords require at least eight characters, upper/lowercase, number and symbol, and at most 72 UTF-8 bytes. The current UID, phone, Firebase binding and original password-version digest must still match. Grant consumption and a conditional password update share one PostgreSQL transaction; all other outstanding grants for that UID are consumed. Concurrent reuse loses with 401. Login then uses the new password against the same account.

Only SHA-256 digests of random request/reset secrets and phone sign-in replay keys persist. Passwords remain bcrypt; OTPs, plaintext passwords, Firebase proof tokens and raw recovery secrets are never stored in Neon. Responses use `Cache-Control: no-store`; Flutter keeps secrets in route-local memory. Existing sessions are preserved, with no reset-triggered token revocation.

Limits are shared in PostgreSQL: 30 recovery API attempts/IP/minute, five starts/phone/hour, one start/phone/minute, five verification attempts/request and five reset attempts/secret per ten minutes. SMS sending is direct to Firebase: these API limits cannot prevent a modified client from calling Firebase directly. Firebase quotas, app verification and SMS region policies must remain configured. Resend starts a new request; earlier valid requests expire normally or are invalidated by a successful reset. Old proof markers remain beyond accepted proof lifetime and are cleaned opportunistically after a day; expired rate-limit buckets are also removed.

Unsupported legacy identities fail closed with recovery unavailable. No account transfer/merge or Firebase password-provider migration is attempted. Migration `20261111180000_password_recovery` was applied to the configured Neon schema on 2026-11-11. A real eligible-account start succeeded afterward; Firebase SMS delivery remains a device check. See [verification and limits](audit/PASSWORD_RECOVERY_REPORT.md).

## Confirmed authorization corrections — 2026-11-13

The invitation inbox uses the authenticated UID for account-linked history plus current Firebase Admin verified-phone ownership for pending unlinked rows. Typed body/query values and stored profile phones are not identity proof. Accept/decline use the same trusted source, serialize decisions and return persisted status. Signup/login/sync only link pending identity and never accept invitations. Direct member creation remains owner-authorized and refuses owner assignment in the use case.

User directory reads require exact IDs (up to the existing limit) or exact phone within a shared group; unscoped requests return 400 and summaries exclude phones/auth state. Self-profile and authorized rosters keep legitimate fields. Catalog writes require the existing server PLACES_CURATOR_UIDS allowlist; missing configuration means authenticated ordinary users receive 403. No global role field was introduced.

A dedicated outing-read check permits creator, current group member or pending/accepted outing invitee; chat operations retain chat-specific checks. Update/cancel/guest removal stay creator-only. Group deletion stays owner-only and preserves the existing 409 restriction for groups with outings. Arrival validation checks server-owned identity/access/venue/time/distance; is_mocked=false is not attestation. Global `/api` HTTP limiting returns 429 with Retry-After and does not replace stricter auth/recovery limits.

## Phase 2 presentation and history — 2026-11-13

The additive roster invitation history uses the existing active-group-member check. Pending invitees cannot read a group's roster/history before accepting. Group Info exposes invitation creation to active group members, consistent with the existing invite operation; direct member-add is not used by these screens. Name/cover/bio changes, removal/revocation and deletion retain owner-only authorization. The inbox retains accepted/declined history but only pending rows expose decision actions. Verified-phone matching, explicit acceptance and WhatsApp delivery remain backend-owned and unchanged.

## Phase 4 optional special-event groups — 2026-11-14

All four special occasions may carry group_id. POST creation and PATCH group association use the existing assertGroupMember check, backed by actual group_members, never a pending group invitation. Existing creator-only writes and participant read rules remain: creator, current group members, or pending/accepted outing guests for reads; accepted guests/group members for eligible participation. Independent events retain their invitation-based access. Firebase token verification and Socket.IO authorization are unchanged. OpenAPI fixtures cover accepted-member creation, pending-only/outsider denial, group association/removal and independent-event privacy.


## Phase 5 chat authorization — 2026-11-14

Editing/deletion require the existing Firebase bearer identity, current chat participation and ownership of the stored sender_id. Cross-outing message IDs return 404, other senders 403, and past/cancelled/two-hour-closed mutations 409. Own-message editing additionally requires the server send timestamp to be less than one minute old, including at persistence; expired edits return 409 MESSAGE_EDIT_WINDOW_EXPIRED. Deletion retains its existing own-sender/open-chat guard without an edit-age restriction. History/read authorization stays participant-scoped. Native actions validate recipient identity before processing; reply/read requests use expectedUserId to prevent account-switch token substitution. iOS actions require foreground authentication; Android local actions open the app. No authorization bypass or global role is introduced.
