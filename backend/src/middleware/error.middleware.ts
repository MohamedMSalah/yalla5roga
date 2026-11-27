import { ZodError } from "zod";
import { Prisma } from "@prisma/client";
import type { NextFunction, Request, Response } from "express";
import { AppError } from "../utils/errors.js";
import { errorCode } from "../monitoring/logger.js";
import { recordRequestError } from "../monitoring/http.js";

export function errorMiddleware(
  err: unknown,
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  recordRequestError(err instanceof AppError ? `http_${err.statusCode}` : errorCode(err));
  if (res.headersSent) return next(err);
  if (err instanceof ZodError) return res.status(400).json({ success: false, message: "Invalid request header" });

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      ...(err.code && { code: err.code }),
    });
  }

  if (err instanceof SyntaxError && "type" in err && err.type === "entity.parse.failed") {
    return res.status(400).json({ success: false, message: "Invalid JSON body" });
  }
  if (err instanceof Error && "type" in err) {
    if (err.type === "entity.too.large") {
      return res.status(413).json({ success: false, message: "Request body is too large" });
    }
    if (err.type === "encoding.unsupported" || err.type === "charset.unsupported") {
      return res.status(415).json({ success: false, message: "Unsupported request body encoding" });
    }
    if (err.type === "request.size.invalid" || err.type === "request.aborted") {
      return res.status(400).json({ success: false, message: "Incomplete request body" });
    }
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === "P2002") {
      return res.status(409).json({ success: false, message: "Resource already exists" });
    }
    if (err.code === "P2003") {
      return res.status(409).json({ success: false, message: "Conflicting resource relationship" });
    }
    if (err.code === "P2025") {
      return res.status(404).json({ success: false, message: "Resource not found" });
    }
  }

  return res.status(500).json({
    success: false,
    message: "Internal server error",
  });
}
