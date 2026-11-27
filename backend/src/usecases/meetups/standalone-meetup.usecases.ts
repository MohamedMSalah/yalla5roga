import type { Prisma } from "@prisma/client";
import type { ManualParticipantInput } from "../../repositories/meetups/standalone-meetup.repository.js";
import { ConflictError } from "../../utils/errors.js";
import { manualParticipantLimit, MeetupSessionWorkflow } from "./meetup-session.usecases.js";

export class CreateStandaloneMeetupUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}

  execute(uid: string) {
    return this.flow.repository.transaction(async tx => {
      const session = await this.flow.repository.initializeStandalone(tx, uid);
      return this.flow.resolve(tx, session, uid);
    });
  }
}

export class ListStandaloneParticipantsUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}

  execute(uid: string, sessionId: string) {
    return this.flow.withSession(uid, sessionId, async (tx, session) => {
      const view = await this.flow.resolve(tx, session, uid);
      return view.standalone_participants ?? [];
    }, { standaloneOnly: true, activeOnly: true });
  }
}

function changeParticipants(flow: MeetupSessionWorkflow, uid: string, sessionId: string,
  change: (tx: Prisma.TransactionClient) => Promise<void>) {
  return flow.withSession(uid, sessionId, async tx => {
    const session = await flow.repository.invalidateInputs(tx, sessionId);
    await change(tx);
    return flow.resolve(tx, session, uid);
  }, { standaloneOnly: true, activeOnly: true });
}

export class AddManualParticipantUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}

  execute(uid: string, sessionId: string, input: ManualParticipantInput) {
    return changeParticipants(this.flow, uid, sessionId, async tx => {
      if (await this.flow.standalone.count(tx, sessionId) >= manualParticipantLimit) {
        throw new ConflictError("Quick Meetup participant limit reached");
      }
      await this.flow.standalone.add(tx, sessionId, input);
    });
  }
}

export class UpdateManualParticipantUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}

  execute(uid: string, sessionId: string, participantId: string, input: Partial<ManualParticipantInput>) {
    return changeParticipants(this.flow, uid, sessionId,
      tx => this.flow.standalone.update(tx, sessionId, participantId, input));
  }
}

export class RemoveManualParticipantUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}

  execute(uid: string, sessionId: string, participantId: string) {
    return changeParticipants(this.flow, uid, sessionId,
      tx => this.flow.standalone.remove(tx, sessionId, participantId));
  }
}
