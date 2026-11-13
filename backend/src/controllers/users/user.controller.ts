import type { NextFunction, Request, Response } from "express";
import {
  toPublicUser,
  toUserSummaries,
  toUserSummary,
} from "../../services/auth/to-public-user.js";
import { DeleteUserUseCase } from "../../usecases/users/delete-user.usecase.js";
import { GetUserUseCase } from "../../usecases/users/get-user.usecase.js";
import { ListUsersUseCase } from "../../usecases/users/list-users.usecase.js";
import { SyncUserUseCase } from "../../usecases/users/sync-user.usecase.js";
import { UpdateUserUseCase } from "../../usecases/users/update-user.usecase.js";
import { ForbiddenError, UnauthorizedError, ValidationError } from "../../utils/errors.js";
import { FirebasePhoneIdentity } from "../../services/phone/phone-identity.js";
import { listUsersQuerySchema } from "../../validators/users/user.validator.js";

import { emitDataChange, publishGroupChange } from "../../realtime/data-changes.js";
import { prisma } from "../../config/database.js";
import { getChatIo } from "../../realtime/chat-emitter.js";

export class UserController {
  constructor(
    private readonly syncUser = new SyncUserUseCase(),
    private readonly getUser = new GetUserUseCase(),
    private readonly listUsers = new ListUsersUseCase(),
    private readonly updateUser = new UpdateUserUseCase(),
    private readonly deleteUser = new DeleteUserUseCase(),
    private readonly phones: Pick<FirebasePhoneIdentity, "verifiedPhone"> = new FirebasePhoneIdentity(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const parsed = listUsersQuerySchema.safeParse(req.query);
      if (!parsed.success) {
        throw new ValidationError(
          parsed.error.issues
            .map((issue) => `${issue.path.join(".") || "request"}: ${issue.message}`)
            .join("; "),
        );
      }
      const { ids, phone } = parsed.data;
      const users = ids.length > 0
        ? await this.listUsers.executeByIds(ids)
        : await this.listUsers.executeByPhone(phone as string, req.user.uid);
      res.json({ success: true, data: toUserSummaries(users) });
    } catch (error) {
      next(error);
    }
  };

  /**
   * Self → full profile (same shape as `/api/users/cuser`).
   * Anyone else → directory-safe summary: no phone, no `has_password`, no
   * credential or internal authentication fields. Authorized member phones are
   * served by the group roster endpoint, not this route.
   */
  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const targetId = req.params.id as string;
      const user = await this.getUser.execute(targetId);
      const data = req.user.uid === targetId ? toPublicUser(user) : toUserSummary(user);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const user = await this.getUser.execute(req.user.uid);
      res.json({ success: true, data: toPublicUser(user) });
    } catch (error) {
      next(error);
    }
  };

  sync = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const currentPhone = req.user.phone ? await this.phones.verifiedPhone(req.user.uid) : null;
      // Identity always comes from the verified token — never body.uid / role.
      const result = await this.syncUser.execute({
        id: req.user.uid,
        phoneVerificationToken: req.body.phoneVerificationToken,
        name: req.body.name,
        phone: req.body.phone,
        image_url: req.body.image_url ?? null,
        verifiedPhone: currentPhone === req.user.phone ? currentPhone : null,
        tokenName: req.user.name ?? null,
        signInProvider: req.user.signInProvider ?? null,
      });

      if (["name", "phone", "image_url", "phoneVerificationToken"].some((key) => req.body[key] !== undefined)) {
        emitDataChange({ kind: "profile" }, [req.user.uid]);
      }
      res.status(200).json({
        success: true,
        data: toPublicUser(result.user),
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
      emitDataChange({ kind: "profile" }, [req.user.uid]);
      if (getChatIo()) {
        void prisma.group_members.findMany({
          where: { user_id: req.user.uid },
          select: { group_id: true },
        }).then((groups) => Promise.all(groups.map(({ group_id }) =>
          publishGroupChange(group_id, "group"),
        ))).catch((error: unknown) => console.error("[realtime] profile audience", error));
      }
      res.json({ success: true, data: toPublicUser(user) });
    } catch (error) {
      next(error);
    }
  };

  deleteCuser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const user = await this.deleteUser.execute(req.user.uid);
      res.json({ success: true, data: toPublicUser(user) });
    } catch (error) {
      next(error);
    }
  };

  deleteById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      if (req.user.uid !== req.params.id) throw new ForbiddenError();
      const user = await this.deleteUser.execute(req.params.id as string);
      res.json({ success: true, data: toPublicUser(user) });
    } catch (error) {
      next(error);
    }
  };
}
