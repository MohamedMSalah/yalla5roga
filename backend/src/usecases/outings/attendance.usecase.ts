import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type {
  AttendanceStatus,
  OutingAttendance,
} from "../../types/outings/outing.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class ListAttendanceUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string): Promise<OutingAttendance[]> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.listAttendance(outingId);
  }
}

export class UpsertAttendanceUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    outingId: string,
    userId: string,
    status: AttendanceStatus,
  ): Promise<OutingAttendance> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.upsertAttendance({
      outing_id: outingId,
      user_id: userId,
      status,
    });
  }
}
