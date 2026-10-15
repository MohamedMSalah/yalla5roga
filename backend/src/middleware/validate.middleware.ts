import type { NextFunction, Request, Response } from "express";
import type { ZodType } from "zod";
import { ValidationError } from "../utils/errors.js";

type RequestSchemas = {
  body?: ZodType;
  query?: ZodType;
  params?: ZodType;
};

export function validate(schemas: RequestSchemas) {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      if (schemas.body) {
        req.body = schemas.body.parse(req.body);
      }

      if (schemas.query) {
        const parsed = schemas.query.parse(req.query);
        Object.assign(req.query, parsed);
      }

      if (schemas.params) {
        const parsed = schemas.params.parse(req.params);
        Object.assign(req.params, parsed);
      }

      next();
    } catch (error) {
      if (
        error &&
        typeof error === "object" &&
        "issues" in error &&
        Array.isArray((error as { issues: unknown[] }).issues)
      ) {
        const issues = (
          error as {
            issues: Array<{ path: (string | number)[]; message: string }>;
          }
        ).issues;

        const message = issues
          .map((issue) => {
            const path = issue.path.join(".") || "request";
            return `${path}: ${issue.message}`;
          })
          .join("; ");

        return next(new ValidationError(message));
      }

      next(error);
    }
  };
}
