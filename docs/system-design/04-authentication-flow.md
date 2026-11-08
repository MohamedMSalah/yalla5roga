# 2.4 Authentication Flow

Sources:  
Flutter — `firebase_auth_service.dart`, `auth_repository_impl.dart`, `auth_remote_datasource.dart`, `dio_interceptors.dart`  
Backend — `auth.middleware.ts`, `signup.usecase.ts`, `login.usecase.ts`, `sync-user.usecase.ts`, `firebase-identity.ts`

## Important: two competing models exist today

| Concern | Flutter (implemented) | Backend (implemented) |
|---------|----------------------|------------------------|
| Email/password storage | Firebase Auth | Neon `users.password_hash` (bcrypt) |
| Signup API | `POST /auth/register` with Bearer + profile fields | `POST /api/auth/signup` with name/email/password/phone — creates Firebase user **without** Firebase password |
| Login API | Firebase `signInWithEmailAndPassword` only | `POST /api/auth/login` verifies Neon hash → Firebase custom token → ID token |
| Social / phone provisioning | After Firebase → `POST /auth/register` | Documented as `POST /api/users/sync` |
| Comments in Flutter `ApiConstants` | “no passwords in PostgreSQL” | Backend stores passwords in PostgreSQL |

These are **confirmed divergences**, not documentation drift alone.

---

## A. Flutter-intended flow (Firebase-first)

```mermaid
sequenceDiagram
  autonumber
  participant U as User
  participant App as Flutter
  participant FA as Firebase Auth
  participant API as Backend (expected by Flutter)
  participant DB as PostgreSQL

  alt Phone + email signup
    U->>App: Enter Egyptian phone
    App->>FA: verifyPhoneNumber / OTP
    FA-->>App: Phone credential
    App->>FA: link email/password
    FA-->>App: Firebase user + ID token
  else Google
    App->>FA: GoogleSignIn credential
    FA-->>App: ID token
  else Apple
    App->>FA: SignInWithApple + nonce
    FA-->>App: ID token
  else Email login
    App->>FA: signInWithEmailAndPassword
    FA-->>App: ID token
  end

  App->>API: POST /auth/register<br/>Authorization: Bearer ID token<br/>body: name, email?, phone?, imageUrl?
  Note over API,DB: Backend has no /auth/register — mismatch
  API-->>App: UserModel (expected)
  App->>App: Cache user + token in SharedPreferences

  App->>API: Subsequent APIs with AuthInterceptor Bearer token
```

---

## B. Backend email/password flow (Neon credential store)

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant API as Express AuthController
  participant UC as Signup/Login UseCase
  participant Neon as PostgreSQL
  participant Admin as Firebase Admin
  participant ClientSDK as Firebase Client REST

  rect rgb(240,248,255)
    Note over C,ClientSDK: Signup — POST /api/auth/signup
    C->>API: {name, email, password, phone}
    API->>UC: SignupUseCase
    UC->>Neon: ensure email/phone unique
    UC->>UC: bcrypt hashPassword
    UC->>Admin: createUser {} (bare UID only — no email/displayName/password)
    UC->>Neon: insert users row with name/email/phone/password_hash
    UC->>Admin: createCustomToken(uid)
    UC->>ClientSDK: signInWithCustomToken → idToken
    API-->>C: {idToken, refreshToken, expiresIn, uid, user}
  end

  rect rgb(255,248,240)
    Note over C,ClientSDK: Login — POST /api/auth/login
    C->>API: {email, password}
    UC->>Neon: findByEmail + verifyPassword
    UC->>Admin: createCustomToken
    UC->>ClientSDK: exchange → idToken
    API-->>C: AuthSession
  end
```

---

## C. Backend sync flow (intended for Google / Apple / phone)

```mermaid
sequenceDiagram
  autonumber
  participant App as Flutter after Firebase sign-in
  participant FA as Firebase
  participant API as POST /api/users/sync
  participant UC as SyncUserUseCase
  participant Neon as PostgreSQL

  App->>FA: Obtain ID token
  App->>API: Bearer token (+ optional body name/email/phone)
  API->>API: authMiddleware verifyIdToken
  API->>UC: uid from token only
  alt First call
    UC->>Neon: create minimal users row
  else Existing
    UC->>Neon: apply verified phone / fill missing email only
  end
  opt phone verified on token
    UC->>Neon: claim pending group_invitations
  end
  API-->>App: {success, data: user, invitations: {...}}
```

Flutter currently calls `POST /auth/register`, **not** `/api/users/sync`.

---

## D. Authorized API access (shared once a valid ID token exists)

```mermaid
flowchart LR
  App["Flutter Dio"] -->|"Authorization: Bearer ID token"| MW["authMiddleware"]
  MW -->|"verifyIdToken"| Admin["Firebase Admin"]
  MW -->|"req.user = {uid, email?, phone?, ...}"| Handler["Controller / UseCase"]
  Handler --> Neon[("PostgreSQL")]
```

`optionalAuthMiddleware` exists but is unused on current routers.

## Google / Apple

| Layer | Status |
|-------|--------|
| Flutter Google Sign-In | Implemented via Firebase credential |
| Flutter Apple Sign-In | Implemented via Firebase OAuth provider |
| Backend dedicated Google/Apple endpoints | **None** — expect `POST /api/users/sync` after Firebase |
| Flutter post-social provisioning | `_provisionBackendUser` → `POST /auth/register` (path/contract mismatch) |
