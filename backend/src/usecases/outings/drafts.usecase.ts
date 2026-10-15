import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type {
  CreateOutingDraftInput,
  OutingDraft,
  UpdateOutingDraftInput,
} from "../../types/outings/outing.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

export class ListDraftsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(userId: string): Promise<OutingDraft[]> {
    return this.outings.listDraftsByUser(userId);
  }
}

export class CreateDraftUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(data: CreateOutingDraftInput): Promise<OutingDraft> {
    return this.outings.createDraft(data);
  }
}

export class UpdateDraftUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    id: string,
    userId: string,
    data: UpdateOutingDraftInput,
  ): Promise<OutingDraft> {
    const draft = await this.outings.findDraftById(id);
    if (!draft) throw new NotFoundError("Draft");
    if (draft.user_id !== userId) throw new ForbiddenError();
    return this.outings.updateDraft(id, data);
  }
}

export class DeleteDraftUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(id: string, userId: string): Promise<OutingDraft> {
    const draft = await this.outings.findDraftById(id);
    if (!draft) throw new NotFoundError("Draft");
    if (draft.user_id !== userId) throw new ForbiddenError();
    return this.outings.deleteDraft(id);
  }
}
