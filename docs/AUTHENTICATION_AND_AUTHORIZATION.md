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


## Phase 6 client composition — 2026-11-14

Phone/password login, Firebase signup OTP proof, Neon synchronization, recovery request/proof/reset tokens and Firebase session restoration retain their existing contracts. Password confirmation adds local validation only. Optional signup media is uploaded after verified registration under the authenticated profile purpose and synced using the existing profile operation. No local image path is sent as profile data.

Delete Account invokes self-scoped DELETE `/api/users/cuser`. After a durable 202 response, Flutter clears the session and account cache. The backend blocks the UID as soon as the deletion transaction commits and disconnects its sockets. A worker disables the Firebase identity, waits out outstanding custom tokens, and then deletes it. An already-absent identity completes that phase successfully. First-run onboarding remains a local presentation preference. [Deletion flow and retention](SYSTEM_DESIGN.md#coordinated-account-deletion)

Production REST and all Socket.IO handshakes use Firebase Admin revocation checks. Established socket sessions recheck every 30 seconds with a five-second limit, and close at the token's expiry. A failed check closes the transport and its rooms. Reconnection must present a usable token. [Firebase session management](https://firebase.google.com/docs/auth/admin/manage-sessions)


## Android notification actions and account isolation — 2026-11-14

Background actions restore the existing Firebase session and use ApiClient/Dio AuthInterceptor with expectedFirebaseUserId. The dispatcher requires payload.recipientUserId to match the active Firebase UID, checks again after asynchronous work and never syncs/provisions a user for each event. Protected taps wait for the existing shared one-time restore synchronization before resource navigation. Action records, display metadata and deduplication are account-bound and cleared on logout/switch.

Reply/read/invitation decisions reuse existing authenticated and authorized endpoints. Backend UID selects the sender/reader/recipient; client routing IDs never confer access. Reply UUIDs provide retry idempotency. Membership and status decisions remain row-locked/transactional, with no preacceptance group access or membership-confirmation push. GET notification system-payload checks row ownership then current resource access/state/preferences, returning no content when unavailable.

Explicit logout best-effort unregisters the account's FCM token and deletes the installation token before Firebase signout; cleanup failure cannot prevent signout. Offline logout can leave a registration on the server until reassignment/cleanup, so recipient checks and session validation still apply on receipt. Invalid token deletion is restricted to definitive invalid/unregistered errors and the still-owning registration row. Preferences/read/history stay in Neon, never Firebase application storage.


## Places worker authorization — 2026-11-14

Existing public catalog reads stay public. Manual taxonomy/place metadata writes and sync administration reuse Firebase ID-token verification and the existing fail-closed `PLACES_CURATOR_UIDS` allowlist; there is no client/admin role flag. The external worker endpoint accepts only a distinct constant-time-compared `PLACES_SYNC_WORKER_SECRET` of at least 32 characters. The secret is server/scheduler-only, cannot authenticate as an app curator, and is never included in Flutter or response bodies. Requests to the external worker always use the persisted seven-day due gate. CLI workers use the backend database credential in the deployment environment. Source URLs are operator-configured HTTPS; user API requests cannot select arbitrary import endpoints. Imports cannot change source=manual or curator-managed places.


Sole-owner leave/deletion (2026-11-14): DELETE /api/groups/:id still verifies the Firebase caller and group owner role. The datasource rechecks that role under the group lock and permits deletion only when that caller is the sole active member and the group has no outings. Other members/outsiders cannot delete; the existing self-member removal API still rejects removing the last owner. Client roster inspection is a navigation decision, never authorization proof.


## Phase 7 repository cleanup — 2026-11-15

Flutter removes the unreferenced `_fromFirebaseCredential` and `_provisionBackendUser` helpers. Active phone/password/Firebase OTP/custom-token flows remain. Registration awaits its existing session result inside try/catch; password update awaits asynchronous local profile caching inside try/catch so cache exceptions become the existing typed failures. No auth contract, password authority, identity, token verification or resource authorization rule changes. The Phase 7 Swagger HTTP audit verifies missing/malformed-token rejection only; authenticated success and SMS are NOT RUN.

## Saved Locations ownership

Only the verified account can read or mutate its personal locations or starting preference. The backend ignores client identity as a source of authorization and rejects unexpected request fields. Reads and writes scope IDs to the verified UID. The database enforces that each default source belongs to that same UID. Coordinated account deletion removes both tables' account-owned records without removing catalog places.

Transportation settings are account-private. Authenticated writes derive the owner from the verified Firebase UID, and per-location writes use owner-scoped keys. The public routing capabilities response contains mode support only.

## Smart Meetup location authorization

The owner can retrieve the exact point through the existing account-scoped saved location API. The group area's audience requires a current membership row for both caller and subject. Exact internal use requires current membership, explicit consent to the current policy and no exclusion for each subject. A pending invitation or an exclusion row grants no planning privilege.

The internal authorization service checks the originating membership and participant revisions at calculation start and again when publishing or consuming protected work. A result reader must also hold current membership. Withdrawal, re-grant and exclusion changes cannot restore a previously invalidated authorization.

## Group Smart Meetup

The authenticated socket checks current accepted membership for each group Meetup join and before delivering outbox events. Quick Meetup joins require session ownership. Outing-linked sessions must still belong to their original group. Revoked viewers leave the Meetup room and receive only its ID in the access-loss message. Location consent controls inputs while current members retain permission to see freshly resolved group readiness.

Outing creation with Smart Meetup validates the current accepted membership of the selected group inside the create transaction. Group results can supply venues only for an outing in their own group. Quick Meetup results require session ownership and the same accepted membership if the planner associates the outing with a group.

Session initialization, reads and refresh require current accepted group membership. Shared preference changes and cancellation require that same membership and the session's creator UID. The group and optional existing outing define the planning scope. Readiness collapses absent points, absent consent and group exclusion into a single setup status. A nullable verified district respects area visibility. A missing district gives no reason code.

Quick Meetup requires the Firebase UID that created the standalone session on every operation. The owner's saved default is resolved only with current Smart Meetup consent. Its coordinates are returned through this owner-only projection. Guest identifiers are local to the session, and guest mutations cannot address owner records or registered profiles.

Preference reads follow the session's visibility. Preference replacement and reset require the active session creator and, for a Group meetup, current membership. The filter-options endpoint requires authentication and provides active catalog labels and supported values.

Recommendation reads, refresh and calculation lookup follow that same session visibility. An exact calculation lookup is scoped by both IDs, and the server checks the current input version and venue eligibility before releasing any places. The public API accepts no routing evidence or publication data.

## Temporary starting-location authorization

All override operations derive the owner from the verified identity. Group Smart Meetup uses current membership, Quick Meetup uses the session creator, and outing overrides require the outing creator, current group membership or an accepted guest invitation. Owners and creators can write only their own inputs. The current policy version authorizes one explicitly selected point for one context. Group exclusions and account-wide consent withdrawal revoke relevant overrides. A default requires either current Smart Meetup automatic authorization or contextual authorization for the individual plan. An individual outing uses contextual authorization only. Exact points and private labels are returned only in the caller's own response or private Quick Meetup.


## Place review authorization

Statistics reads are public. Review listings, ownership operations, reports and blocks use the authenticated Firebase UID. `PLACE_REVIEW_MODERATOR_UIDS` is a server-only, comma-separated allowlist that defaults to empty. Catalog curation and group or outing roles grant no review moderation privileges. Public review profiles contain only their display name. Coordinated user deletion removes authored reviews, submitted reports and reviewer blocks.


## Personal route preview

Use the Firebase subject for origin resolution and the existing contextual starting-location policy for consent and group exclusions. Quick Meetup previews require the session owner. Group Meetup previews require current membership. Outing previews require the creator, a current group member or an accepted registered outing guest. Client input cannot select a member or supply either endpoint's coordinates. The response is private and uses Cache-Control: private, no-store.


## Location requests and departure reminder access

A location request requires both sender and recipient to be current members of the active session's group. The policy rejects self-requests, standalone sessions and recipients who already have an eligible location or have excluded the group. Recipient push and group notification preferences must both permit the request. The worker checks these rules again before delivery.

Departure reminder APIs are caller-scoped. Current outing participation, a confirmed upcoming outing, Going RSVP, authorized starting location, a resolved transportation mode, account opt-in and push/reminder preferences are required for scheduling. The backend resolves these inputs and validates any trusted estimate against the current caller and outing.
