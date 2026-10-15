import type { NextFunction, Request, Response } from "express";
import { DeleteUserUseCase } from "../../usecases/users/delete-user.usecase.js";
import { GetUserUseCase } from "../../usecases/users/get-user.usecase.js";
import { ListUsersUseCase } from "../../usecases/users/list-users.usecase.js";
import { SyncUserUseCase } from "../../usecases/users/sync-user.usecase.js";
import { UpdateUserUseCase } from "../../usecases/users/update-user.usecase.js";
import { ForbiddenError, UnauthorizedError } from "../../utils/errors.js";

export class UserController {
  constructor(
    private readonly syncUser = new SyncUserUseCase(),
    private readonly getUser = new GetUserUseCase(),
    private readonly listUsers = new ListUsersUseCase(),
    private readonly updateUser = new UpdateUserUseCase(),
    private readonly deleteUser = new DeleteUserUseCase(),
  ) {}

  list = async (_req: Request, res: Response, next: NextFunction) => {
    try {
      const users = await this.listUsers.execute();
      res.json({ success: true, data: users });
    } catch (error) {
      next(error);
    }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const user = await this.getUser.execute(req.params.id as string);
      res.json({ success: true, data: user });
    } catch (error) {
      next(error);
    }
  };

  getCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const user = await this.getUser.execute(req.user.uid);
      res.json({ success: true, data: user });
    } catch (error) {
      next(error);
    }
  };

  sync = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const result = await this.syncUser.execute({
        id: req.user.uid,
        name: req.body.name,
        phone: req.body.phone,
        email: req.body.email,
        image_url: req.body.image_url ?? null,
        verifiedPhone: req.user.phone ?? null,
        signInProvider: req.user.signInProvider ?? null,
      });

      res.status(200).json({
        success: true,
        data: result.user,
        invitations: result.invitations,
      });
    } catch (error) {
      next(error);
    }
  };

  updateCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const user = await this.updateUser.execute(req.user.uid, req.body);
      res.json({ success: true, data: user });
    } catch (error) {
      next(error);
    }
  };

  deleteCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const user = await this.deleteUser.execute(req.user.uid);
      res.json({ success: true, data: user });
    } catch (error) {
      next(error);
    }
  };

  deleteById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      if (req.user.uid !== req.params.id) throw new ForbiddenError();
      const user = await this.deleteUser.execute(req.params.id as string);
      res.json({ success: true, data: user });
    } catch (error) {
      next(error);
    }
  };
}
