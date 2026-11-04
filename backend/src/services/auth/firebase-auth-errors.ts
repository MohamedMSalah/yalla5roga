import { FirebaseError } from "firebase/app";
import {
  AppError,
  ConflictError,
  UnauthorizedError,
  ValidationError,
} from "../../utils/errors.js";

export function mapFirebaseAuthError(error: unknown): Error {
  if (!(error instanceof FirebaseError) && !isAuthCodedError(error)) {
    return error instanceof Error ? error : new Error(String(error));
  }

  const code = readCode(error);

  switch (code) {
    case "auth/email-already-in-use":
    case "auth/email-already-exists":
      return new ConflictError("An account with this email already exists");
    case "auth/invalid-email":
      return new ValidationError("Invalid email address");
    case "auth/weak-password":
      return new ValidationError("Password is too weak");
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
    case "auth/invalid-login-credentials":
    case "auth/invalid-custom-token":
    case "auth/custom-token-mismatch":
      return new UnauthorizedError("Invalid email or password");
    case "auth/user-disabled":
      return new UnauthorizedError("This account has been disabled");
    case "auth/too-many-requests":
      return new AppError(429, "Too many attempts. Try again later");
    case "auth/operation-not-allowed":
      return new ValidationError("Email and password sign-in is not enabled");
    case "auth/uid-already-exists":
      return new ConflictError("An account with this identity already exists");
    default:
      return new UnauthorizedError("Authentication failed");
  }
}

function isAuthCodedError(
  error: unknown,
): error is { code: string; message?: string } {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof (error as { code: unknown }).code === "string" &&
    (error as { code: string }).code.startsWith("auth/")
  );
}

function readCode(error: { code: string } | FirebaseError): string {
  return error.code;
}
