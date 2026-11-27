import type { Prisma } from "@prisma/client";
import type { CreateOutingInput, MeetupOutingSelection } from "../../types/outings/outing.types.js";
import { GetMeetupResultsUseCase } from "../../usecases/meetups/meetup-result.usecases.js";
import { MeetupSessionWorkflow } from "../../usecases/meetups/meetup-session.usecases.js";
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from "../../utils/errors.js";

const staleResultCode = "stale_meetup_result";

function staleResult() {
  return new ConflictError("Smart Meetup result is no longer available. Refresh recommendations.", staleResultCode);
}

export class ValidateMeetupSelectionService {
  constructor(private readonly results = new GetMeetupResultsUseCase(new MeetupSessionWorkflow())) {}

  // Validate the existing outing fields before using the transaction's idempotent read.
  requireMatchingSelection(input: CreateOutingInput, selection: MeetupOutingSelection) {
    const ids = selection.place_ids.map(id => id.toLowerCase());
    const actual = (input.initial_vote_options
      ? input.initial_vote_options.map(option => option.place_id)
      : [input.location_place_id]).map(id => id?.toLowerCase());
    if (!input.create_request_key || ids.length < 1 || ids.length > 5 ||
        new Set(ids).size !== ids.length || ids.length !== actual.length ||
        actual.some(id => !id || !ids.includes(id)) || new Set(actual).size !== ids.length) {
      throw new ValidationError("A Smart Meetup selection requires a request key and matching catalog venues");
    }
  }

  transaction<T>(run: (tx: Prisma.TransactionClient) => Promise<T>) {
    return this.results.flow.repository.transaction(run);
  }

  async execute(tx: Prisma.TransactionClient, input: CreateOutingInput, selection: MeetupOutingSelection) {
    // Input-version changes and session closure take the same row lock.
    await tx.$queryRaw`SELECT id FROM meetup_sessions WHERE id = ${selection.session_id}::uuid FOR UPDATE`;
    const session = await this.authorizedSession(tx, selection.session_id, input.created_by);
    if (session.session_type === "GROUP" && session.group_id !== input.group_id?.toLowerCase()) {
      throw new ForbiddenError("Group meetup recommendations require an outing in the same group");
    }
    if (input.group_id) {
      const members = await tx.$queryRaw<{ user_id: string }[]>`
        SELECT user_id FROM group_members
        WHERE group_id = ${input.group_id}::uuid AND user_id = ${input.created_by} FOR SHARE
      `;
      if (!members.length) throw new ForbiddenError("Current group membership required");
    }

    if (session.status !== "ACTIVE" || session.expires_at <= new Date()) throw staleResult();
    const result = await this.results.read(tx, session, input.created_by, { lockCatalog: true });
    const calculation = result.calculation;
    if (!calculation || calculation.id !== selection.calculation_id.toLowerCase() ||
        !calculation.calculatedAt || !calculation.expiresAt ||
        calculation.calculatedAt > new Date() || calculation.expiresAt <= new Date() ||
        (result.status !== "READY" && result.status !== "PARTIAL")) throw staleResult();

    const places = new Map(result.recommendations.map(row => [row.placeId, row.place]));
    if (selection.place_ids.some(id => !places.has(id.toLowerCase()))) {
      throw new ValidationError("Selected venues must belong to the Smart Meetup result");
    }
    return places;
  }

  private async authorizedSession(tx: Prisma.TransactionClient, sessionId: string, uid: string) {
    const { flow } = this.results;
    try {
      const session = await flow.repository.get(tx, sessionId);
      if (session.session_type === "STANDALONE") flow.standalonePolicy.requireOwner(session, uid);
      return session;
    } catch (error) {
      if (error instanceof NotFoundError) throw new NotFoundError("Smart Meetup", staleResultCode);
      throw error;
    }
  }
}
