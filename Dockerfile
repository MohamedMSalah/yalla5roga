FROM node:24-bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates openssl \
    && rm -rf /var/lib/apt/lists/* \
    && npm install --global pnpm@12.6.0

WORKDIR /app/backend
COPY backend/package.json backend/pnpm-lock.yaml backend/pnpm-workspace.yaml ./
COPY backend/prisma ./prisma
RUN pnpm install --frozen-lockfile
COPY backend/src ./src
COPY backend/tsconfig.json ./
RUN pnpm build

COPY backend/licenses ./licenses
COPY scripts/environment.mjs scripts/production-environment.mjs /app/scripts/
ENV HOST=0.0.0.0 PORT=3000
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=4s CMD node -e 'fetch("http://127.0.0.1:"+process.env.PORT+"/health/live",{signal:AbortSignal.timeout(3000)}).then(x=>process.exit(x.ok?0:1),()=>process.exit(1))'
CMD ["node", "--import", "../scripts/production-environment.mjs", "dist/server.js"]
