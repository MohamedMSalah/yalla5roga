# Yalla 5roga

Monorepo for the Yalla 5roga backend and Flutter app. The two projects stay in separate directories, and each keeps the commit history from its original repository.

## Layout

- `backend/` — Node.js, TypeScript, Express, and Prisma API
- `flutter/` — Flutter app

## Commits

Stage one project at a time so a backend change and a Flutter change can be committed separately.

Backend only:

```bash
git add backend/
git commit -m "Describe the backend change."
```

Flutter only:

```bash
git add flutter/
git commit -m "Describe the Flutter change."
```

Root files only:

```bash
git add README.md .gitignore
git commit -m "Describe the root change."
```

## Local files that stay untracked

Do not commit `.env` files, Firebase client options, signing keys, keystores, or service-account credentials. Copy those files into the matching directory on each machine. `.env.example` is the committed template for the backend.
