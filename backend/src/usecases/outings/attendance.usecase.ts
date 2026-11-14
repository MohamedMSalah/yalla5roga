import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
import { assertOutingParticipant, listOutingParticipantProfiles } from "../../services/outings/outing-participants.js";
import type {
  AttendanceStatus,
  OutingAttendance,
  OutingAttendanceRosterEntry,
} from "../../types/outings/outing.types.js";
import { ConflictError, NotFoundError } from "../../utils/errors.js";

export class ListAttendanceUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string): Promise<OutingAttendanceRosterEntry[]> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    await assertOutingParticipant(outing, userId);
    const [responses, participants] = await Promise.all([
      this.outings.listAttendance(outingId), listOutingParticipantProfiles(outing),
    ]);
    const byUser = new Map(responses.map(row => [row.user_id, row]));
    return participants.map<OutingAttendanceRosterEntry>(person => {
      const response = byUser.get(person.id);
      return {
        outing_id: outingId, user_id: person.id,
        status: response?.status ?? (person.id === outing.created_by ? "going" : "no_response"),
        updated_at: response?.updated_at ?? null,
        users: { name: person.name, image_url: person.image_url },
      };
    });
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
      }).catch((error: unknown) => {
        console.error("[attendance] notification enqueue failed", error);
      });
    }

    return row;
  }
}
