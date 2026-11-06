# 2.2 Backend Internal Architecture

Verified against `backend/src/routes/*`, `controllers/*`, `usecases/*`, `repositories/*`, `datasources/*`, `middleware/*`, `services/*`.

## Layered request flow

```mermaid
flowchart LR
  C["HTTP Client"] --> A["app.ts<br/>cors + express.json"]
  A --> R["routes/index.ts<br/>mount registry"]
  R --> MW1["authMiddleware<br/>optional per router"]
  MW1 --> MW2["validate middleware<br/>Zod schemas"]
  MW2 --> CTRL["controllers/*"]
  CTRL --> UC["usecases/*"]
  UC --> SVC["services/*<br/>auth, phone, chat-access, WhatsApp"]
  UC --> REPO["repositories/*"]
  REPO --> DS["datasources/*"]
  DS --> P["Prisma Client"]
  P --> DB[("PostgreSQL / Neon")]
  CTRL --> ERR["errorMiddleware<br/>AppError → JSON"]
```

## Actual module map

```mermaid
flowchart TB
  subgraph Entry
    server["server.ts — dotenv, listen, start job"]
    app["app.ts — /, /health, /api-docs, routes"]
  end

  subgraph Routes["routes/"]
    authR["/api/auth"]
    userR["/api/users"]
    groupR["/api/groups"]
    savedR["/api/outings/saved…"]
    outingR["/api/outings"]
    placeR["/api/places"]
    notifR["/api/notifications"]
    chatR["/api/chat"]
  end

  subgraph Controllers
    AuthC["AuthController"]
    UserC["UserController"]
    GroupC["GroupController"]
    OutingC["OutingController"]
    PlaceC["PlaceController"]
    NotifC["NotificationController"]
    ChatC["ChatController"]
  end

  subgraph CrossCutting
    AuthMW["auth.middleware.ts"]
    ValMW["validate.middleware.ts"]
    ErrMW["error.middleware.ts"]
    FB["config/firebase.ts + firebase-client.ts"]
    DBCFG["config/database.ts"]
    JOB["jobs/complete-outings.job.ts"]
  end

  server --> app --> Routes
  Routes --> Controllers
  AuthMW --> FB
  DS --> DBCFG
  JOB --> DBCFG
```

## Dependency style (observed)

- Controllers instantiate use cases with **default constructors** (manual DI, no IoC container).
- Use cases default to concrete `*Repository` implementations.
- Repositories wrap datasources that call Prisma.
- Cross-cutting services (`password`, `firebase-identity`, `normalize-phone`, `chat-access`, `invitation-policy`, `whatsapp`) are imported directly.

## Success / error envelope

**Success** (typical): `{ success: true, data: T }`  
**Sync special case:** also returns top-level `invitations`  
**Error** (`error.middleware.ts`): `{ success: false, message: string }` with status from `AppError` subclasses (400/401/403/404/409/500).

## Background processing

| Job | Location | Behavior |
|-----|----------|----------|
| Outing completion | `jobs/complete-outings.job.ts` | Every 60s: `upcoming` → `past` when `COALESCE(ends_at, scheduled_at + 6h) <= now()` |
| Neon keep-alive | `config/database.ts` | Dev-only `SELECT 1` every ~4 minutes |
