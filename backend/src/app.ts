import express from "express";
import cors from "cors";
import { serve, setup, type JsonObject } from "swagger-ui-express";
import { swaggerSpec } from "./config/swagger.js";
import routes from "./routes/index.js";
import { errorMiddleware } from "./middleware/error.middleware.js";
import { corsOrigin } from "./config/cors.js";

import { apiRateLimit } from "./middleware/api-rate-limit.middleware.js";
import { databaseHealth, installHealth } from "./monitoring/health.js";
import { requestMonitoring, observeRequestIdentity } from "./monitoring/http.js";
import { registeredRoutes, compareSwagger } from "./monitoring/routes.js";
import { logger, errorCode } from "./monitoring/logger.js";
import { installMobileTelemetry } from "./monitoring/mobile.js";

const app = express();
app.disable("x-powered-by");
const trustedProxies = process.env.TRUST_PROXY?.trim();
if (trustedProxies) app.set("trust proxy", trustedProxies);
app.use(requestMonitoring(() => routeInventory));
app.use((_req, res, next) => {
  res.set({ "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer" });
  next();
});

app.use(
  cors({
    origin: corsOrigin,
    credentials: true,
    allowedHeaders: ["Authorization", "Content-Type", "Accept", "If-Match", "Idempotency-Key",
      "X-Request-ID", "X-Correlation-ID", "X-Client-Source", "X-Request-Trigger"],
    exposedHeaders: ["X-Request-ID", "X-Correlation-ID", "Server-Timing", "X-Cache-Status", "X-Route-Template"],
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  }),
);
app.use("/api", apiRateLimit);
app.use("/monitoring/mobile", apiRateLimit);
installMobileTelemetry(app, () => routeInventory);
app.use(express.json());
app.use(observeRequestIdentity);

/**
 * @openapi
 * /:
 *   get:
 *     tags: [System]
 *     summary: Process health
 *     description: Confirms the API process is running and accepting HTTP requests. Does not check the database.
 *     operationId: getRoot
 *     security: []
 *     responses:
 *       "200":
 *         description: The API process is accepting requests
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, message]
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: Yalla 5roga API is running
 */
app.get("/", (_req, res) => {
  res.json({
    success: true,
    message: "Yalla 5roga API is running",
  });
});

/**
 * @openapi
 * /health:
 *   get:
 *     tags: [System]
 *     summary: Database health
 *     description: Reports a recent lightweight database connectivity probe.
 *     operationId: getHealth
 *     security: []
 *     responses:
 *       "200":
 *         description: Database connection succeeded
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/HealthOk"
 *       "500":
 *         description: Database connection failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/HealthError"
 */
app.get("/health", async (_req, res) => {
  if ((await databaseHealth()).available) {
    res.json({
      success: true,
      message: "OK",
      database: "connected",
    });
  } else {
    res.status(500).json({
      success: false,
      message: "Database connection failed",
      database: "disconnected",
      error: "Database unavailable",
    });
  }
});

installHealth(app);
if (process.env.NODE_ENV !== "production") {
  app.get("/api-docs/openapi.json", (_req, res) => { res.json(swaggerSpec); });
  app.use("/api-docs", serve, setup(swaggerSpec as JsonObject, {
    customSiteTitle: "Yalla 5roga API",
    swaggerOptions: { persistAuthorization: false },
  }));
}

app.use(routes);
app.use((_req, res) => {
  res.status(404).json({ success: false, message: "Route not found" });
});
app.use(errorMiddleware);

export const routeInventory = (() => {
  try { return registeredRoutes(app); }
  catch (error) {
    logger.warn({ errorCode: errorCode(error) }, "Route inventory unavailable");
    return [];
  }
})();
export const swaggerCoverage = compareSwagger(routeInventory, swaggerSpec);

export default app;
