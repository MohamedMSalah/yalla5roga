# 2.6 API Request Lifecycle (Real Endpoint)

Example: **authenticated list of the current user’s groups**  
Backend: `GET /api/groups/cuser`  
Files: `group.routes.ts`, `group.controller.ts`, `list-groups.usecase.ts`, `group.repository.ts`, `group.datasource.ts`, `auth.middleware.ts`

> Flutter currently calls `GET /groups` (no `/api`, no `/cuser`). This sequence documents the **backend** path that exists today.

```mermaid
sequenceDiagram
  autonumber
  participant App as Flutter Dio
  participant Exp as Express app.ts
  participant Auth as authMiddleware
  participant FB as Firebase Admin verifyIdToken
  participant Route as group.routes
  participant Ctrl as GroupController.listForCuser
  participant UC as ListGroupsUseCase
  participant Repo as GroupRepository
  participant DS as GroupDatasource
  participant Prisma as Prisma Client
  participant DB as Neon PostgreSQL

  App->>Exp: GET /api/groups/cuser<br/>Authorization: Bearer <idToken>
  Exp->>Route: mount /api/groups
  Route->>Auth: router-level authMiddleware
  Auth->>Auth: extractBearerToken
  Auth->>FB: verifyIdToken(token)
  FB-->>Auth: decoded { uid, email?, phone_number?, ... }
  Auth->>Route: req.user = AuthUser
  Route->>Ctrl: listForCuser
  Ctrl->>Ctrl: require req.user.uid
  Ctrl->>UC: execute({ userId: uid })
  UC->>Repo: findByUserId(uid)
  Repo->>DS: findByUserId
  DS->>Prisma: groups.findMany where members contain uid
  Prisma->>DB: SQL SELECT … JOIN group_members
  DB-->>Prisma: rows
  Prisma-->>DS: Group[]
  DS-->>Ctrl: Group[]
  Ctrl-->>App: 200 { success: true, data: Group[] }

  alt Missing / invalid token
    Auth-->>App: 401 { success: false, message }
  end

  alt Unexpected error
    Ctrl->>Exp: next(error)
    Exp-->>App: 500 { success: false, message: Internal server error }
  end
```

## What Flutter would need to match this call

| Concern | Backend today | Flutter today |
|---------|---------------|---------------|
| Method | `GET` | `GET` — matches |
| Path | `/api/groups/cuser` or filtered `GET /api/groups?userId=` | `/groups` |
| Auth header | Bearer Firebase ID token | AuthInterceptor attaches token — OK if path hits backend |
| Response | `{ success, data: Group[] }` snake_case Prisma fields | Parses `data` via `apiPayload`, then expects camelCase aliases (`image`/`coverUrl`, `people`/`members`) |

## Alternate example: cast a vote

Backend `POST /api/outings/:id/votes` body `{ option_id }` → `CastVoteUseCase` → Prisma upsert on `outing_votes`.

Flutter sends `{ optionIndex, toggle: true }` to `POST /outings/:id/votes` — **contract mismatch**; see consistency audit.
