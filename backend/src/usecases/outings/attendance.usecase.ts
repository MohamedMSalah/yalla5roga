import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
import { assertOutingParticipant } from "../../services/outings/outing-participants.js";
import type {
  AttendanceStatus,
  OutingAttendance,
} from "../../types/outings/outing.types.js";
import { ConflictError, NotFoundError } from "../../utils/errors.js";

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
    if (outing.status === "cancelled" || outing.status === "past") {
      throw new ConflictError("Attendance is closed for this outing");
    }
    await assertOutingParticipant(outing, userId);

    // Owner stays Going; they cannot mark themselves otherwise.
    const nextStatus =
      outing.created_by === userId ? ("going" as const) : status;

    const row = await this.outings.upsertAttendance({
      outing_id: outingId,
      user_id: userId,
      status: nextStatus,
    });

    if (outing.created_by !== userId) {
      await notifyOutingParticipants({
        outing,
        type: "outing",
        eventType: "attendance_changed",
        body: "A participant updated their attendance.",
        eventKey: `attendance:${outingId}:${userId}:${nextStatus}:${row.updated_at.toISOString()}`,
        userIds: [outing.created_by],
      });
    }

    return row;
  }
}
