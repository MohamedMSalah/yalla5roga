import type { meetup_optimization } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { MeetupEventPublisher } from "../../services/meetups/meetup-event-publisher.js";
import {
  defaultMeetupPreferences, maximumTravelDurations, minimumRatings, OptimizationPriority,
  selectableBudgetLevels, TravelFairnessMode, type MeetupPreferences,
} from "../../types/meetups/meetup-preferences.js";
import type { MeetupSessionWorkflow } from "./meetup-session.usecases.js";

export class GetMeetupPreferencesUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}

  execute(uid: string, sessionId: string) {
    return this.flow.withSession(uid, sessionId,
      (tx, session) => this.flow.preferences.get(tx, session));
  }

  async filterOptions() {
    return {
      categories: await this.flow.preferences.filterOptions(prisma),
      budgetLevels: selectableBudgetLevels,
      minimumRatings,
      travelFairnessModes: Object.values(TravelFairnessMode),
      maximumTravelDurationSeconds: maximumTravelDurations,
      additionalPriorities: Object.values(OptimizationPriority),
      defaults: defaultMeetupPreferences(),
    };
  }
}

export class UpdateMeetupPreferencesUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow, private readonly events = new MeetupEventPublisher()) {}

  execute(uid: string, sessionId: string, preferences: MeetupPreferences) {
    return this.replace(uid, sessionId, () => preferences, true);
  }

  updateLegacy(uid: string, sessionId: string, optimization: meetup_optimization) {
    return this.replace(uid, sessionId, current => ({
      ...current,
      travelFairnessMode: defaultMeetupPreferences(optimization).travelFairnessMode,
    }), false);
  }

  private replace(uid: string, sessionId: string,
    edit: (current: MeetupPreferences) => MeetupPreferences, validateCategories: boolean) {
    return this.flow.withSession(uid, sessionId, async (tx, session) => {
      const current = await this.flow.preferences.get(tx, session);
      const requested = edit(current);
      const next = {
        ...defaultMeetupPreferences(),
        ...requested,
        categoryIds: [...requested.categoryIds].sort(),
        budgetLevels: [...requested.budgetLevels].sort(),
        additionalPriorities: [...requested.additionalPriorities].sort(),
      };
      if (validateCategories) await this.flow.preferences.validateCategories(tx, next.categoryIds);
      if (JSON.stringify(current) === JSON.stringify(next)) return this.flow.resolve(tx, session, uid, current);

      const invalidated = await this.flow.repository.invalidateInputs(tx, session.id);
      await this.flow.preferences.replace(tx, session.id, next);
      await this.events.enqueuePreferencesChanged(tx, invalidated.id, invalidated.input_version);
      return this.flow.resolve(tx, invalidated, uid, next);
    }, { activeOnly: true, managerOnly: true });
  }
}

export class ResetMeetupPreferencesUseCase {
  constructor(private readonly update: UpdateMeetupPreferencesUseCase) {}

  execute(uid: string, sessionId: string) {
    return this.update.execute(uid, sessionId, defaultMeetupPreferences());
  }
}
