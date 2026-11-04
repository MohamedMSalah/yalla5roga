import type { NextFunction, Request, Response } from "express";
import { LoginUseCase } from "../../usecases/auth/login.usecase.js";
import { SignupUseCase } from "../../usecases/auth/signup.usecase.js";

export class AuthController {
  constructor(
    private readonly login = new LoginUseCase(),
    private readonly signup = new SignupUseCase(),
  ) {}

  loginHandler = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await this.login.execute({
        email: req.body.email,
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
        email: req.body.email,
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
}
