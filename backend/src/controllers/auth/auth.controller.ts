import type { NextFunction, Request, Response } from "express";
import { ChangePasswordUseCase } from "../../usecases/auth/change-password.usecase.js";
import { LoginUseCase } from "../../usecases/auth/login.usecase.js";
import { SignupUseCase } from "../../usecases/auth/signup.usecase.js";
import { VerifyPasswordUseCase } from "../../usecases/auth/verify-password.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

export class AuthController {
  constructor(
    private readonly login = new LoginUseCase(),
    private readonly signup = new SignupUseCase(),
    private readonly changePassword = new ChangePasswordUseCase(),
    private readonly verifyPassword = new VerifyPasswordUseCase(),
  ) {}

  loginHandler = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await this.login.execute({
        phone: req.body.phone,
        password: req.body.password,
      });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  };

  signupHandler = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await this.signup.execute({
        name: req.body.name,
        password: req.body.password,
        phone: req.body.phone,
      });

      res.status(201).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  };

  changePasswordHandler = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      await this.changePassword.execute({
        userId: req.user.uid,
        currentPassword: req.body.currentPassword,
        newPassword: req.body.newPassword,
      });
      res.status(200).json({ success: true, data: { updated: true } });
    } catch (error) {
      next(error);
    }
  };

  verifyPasswordHandler = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      await this.verifyPassword.execute({
        userId: req.user.uid,
        password: req.body.password,
      });
      res.status(200).json({ success: true, data: { verified: true } });
    } catch (error) {
      next(error);
    }
  };
}
