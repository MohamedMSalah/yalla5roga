# 2.1 High-Level System Architecture

Verified against `backend/src/app.ts`, `backend/src/server.ts`, `backend/src/config/*`, `flutter/lib/core/di/app_dependencies.dart`, `flutter/lib/core/config/app_config.dart`.

```mermaid
flowchart TB
  subgraph Client["Flutter App — yalla_5roga"]
    UI["Screens / Widgets"]
    PROV["Providers — ChangeNotifier"]
    REPO["Repositories — Either"]
    DIO["ApiClient / Dio + AuthInterceptor"]
    PREFS["SharedPreferences"]
    FA_C["Firebase Auth SDK"]
    FCM_C["Firebase Messaging SDK"]
    MAP["flutter_map + geolocator"]
    NOM_C["Nominatim HTTP — package:http"]
  end

  subgraph Google["Google / Apple / Firebase"]
    FA["Firebase Authentication"]
    FCM["Firebase Cloud Messaging"]
  end

  subgraph Backend["Node.js API — Express + TypeScript"]
    EXP["Express app — CORS, JSON, /health, /api-docs"]
    AUTH_MW["authMiddleware — verifyIdToken"]
    UC["Use cases"]
    PRISMA["Prisma Client"]
    JOB["complete-outings job — setInterval 60s"]
  end

  subgraph Data["Data plane"]
    NEON[("PostgreSQL — Neon")]
  end

  subgraph External["Other external services"]
    OSM["OpenStreetMap tiles"]
    NOM["Nominatim geocoding"]
    WA["WhatsApp wa.me URLs only"]
  end

  UI --> PROV --> REPO
  REPO --> DIO
  REPO --> PREFS
  REPO --> FA_C
  REPO --> FCM_C
  REPO --> NOM_C
  MAP --> OSM

  FA_C <-->|"sign-in / ID token"| FA
  FCM_C <-->|"receive only — no server register"| FCM
  NOM_C -->|"HTTPS reverse/search"| NOM

  DIO -->|"HTTPS JSON — Bearer Firebase ID token"| EXP
  EXP --> AUTH_MW --> UC --> PRISMA --> NEON
  JOB --> PRISMA
  UC -->|"generate invite link"| WA

  note1["Object storage: NOT implemented — image_url strings only"]
  note2["FCM send from backend: NOT implemented — user_fcm_tokens unused"]
  note3["WebSockets: NOT present — chat is REST"]
```

## Communication protocols

| From → To | Protocol | Auth / notes |
|-----------|----------|--------------|
| Flutter → Backend | HTTP/JSON (Dio) | `Authorization: Bearer <Firebase ID token>` |
| Flutter → Firebase Auth | Firebase SDK | Phone OTP, email/password, Google, Apple |
| Backend → Firebase Admin | Admin SDK | `verifyIdToken`, create user, custom token |
| Backend → Firebase Client REST | HTTPS | Custom token → ID token exchange (`FIREBASE_API_KEY`) |
| Backend → Neon | Prisma / PostgreSQL | `DATABASE_URL` (pooled Neon URL) |
| Flutter → Nominatim | HTTPS | Public User-Agent; not proxied |
| Flutter → OSM tiles | HTTPS | Tile template from `AppConfig` |
| Backend → WhatsApp | None | Builds `wa.me` URL; does not send messages |
| FCM → Flutter | Push | Receive path only; token not synced to API |

## Confirmed absences

- No S3 / R2 / Cloudinary / Firebase Storage upload pipeline
- No SMTP / email provider
- No Redis, queue, or message broker
- No WebSocket / Socket.IO layer
- No CDN in front of the API (not configured in repo)
