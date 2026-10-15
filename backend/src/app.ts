import express from "express";
import cors from "cors";
import { serve, setup, type JsonObject } from "swagger-ui-express";
import { prisma } from "./config/database.js";
import { swaggerSpec } from "./config/swagger.js";
import routes from "./routes/index.js";
import { errorMiddleware } from "./middleware/error.middleware.js";

const app = express();

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());

/**
 * @openapi
 * /:
 *   get:
 *     tags: [System]
 *     summary: API status
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
 *     summary: Database health check
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
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({
      success: true,
      message: "OK",
      database: "connected",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Database connection failed",
      database: "disconnected",
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

app.use(
  "/api-docs",
  serve,
  setup(swaggerSpec as JsonObject, {
    customSiteTitle: "Yalla 5roga API",
    swaggerOptions: {
      persistAuthorization: true,
    },
  }),
);

app.use(routes);
app.use(errorMiddleware);

export default app;
