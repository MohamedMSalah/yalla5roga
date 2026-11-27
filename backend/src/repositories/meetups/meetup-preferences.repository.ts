import type { Prisma } from "@prisma/client";
import { defaultMeetupPreferences, type MeetupPreferences } from "../../types/meetups/meetup-preferences.js";
import type { MeetupSession } from "../../types/meetups/meetup-session.js";
import { ValidationError } from "../../utils/errors.js";

export class MeetupPreferencesRepository {
  async get(tx: Prisma.TransactionClient, session: MeetupSession): Promise<MeetupPreferences> {
    const row = await tx.meetup_preferences.findUnique({
      where: { meetup_session_id: session.id },
      include: { categories: { select: { category_id: true } } },
    });
    if (!row) return defaultMeetupPreferences(session.optimization);
    return {
      categoryIds: row.categories.map(category => category.category_id).sort(),
      budgetLevels: row.selected_budget_levels.sort(),
      minimumRating: (row.minimum_rating?.toNumber() ?? null) as MeetupPreferences["minimumRating"],
      travelFairnessMode: row.travel_fairness_mode,
      maximumTravelDurationSeconds: row.maximum_travel_duration_seconds as MeetupPreferences["maximumTravelDurationSeconds"],
      additionalPriorities: row.additional_priorities.sort(),
      plannedMeetupAt: row.planned_meetup_at,
      requireOpenAtMeetupTime: row.require_open_at_meetup_time,
    };
  }

  async validateCategories(tx: Prisma.TransactionClient, ids: string[]) {
    if (!ids.length) return;
    const count = await tx.place_categories.count({ where: { id: { in: ids }, is_active: true } });
    if (ids.length !== count) throw new ValidationError("Unknown or inactive meetup category");
  }

  async replace(tx: Prisma.TransactionClient, sessionId: string, preferences: MeetupPreferences) {
    const data = {
      travel_fairness_mode: preferences.travelFairnessMode,
      selected_budget_levels: preferences.budgetLevels,
      minimum_rating: preferences.minimumRating,
      maximum_travel_duration_seconds: preferences.maximumTravelDurationSeconds,
      additional_priorities: preferences.additionalPriorities,
      planned_meetup_at: preferences.plannedMeetupAt,
      require_open_at_meetup_time: preferences.requireOpenAtMeetupTime,
    };
    const where = { meetup_session_id: sessionId };
    await tx.meetup_preferences.upsert({ where, create: { ...where, ...data }, update: data });
    await tx.meetup_preference_categories.deleteMany({ where });
    if (preferences.categoryIds.length) {
      await tx.meetup_preference_categories.createMany({
        data: preferences.categoryIds.map(category_id => ({ ...where, category_id })),
      });
    }
  }

  filterOptions(tx: Pick<Prisma.TransactionClient, "place_categories">) {
    return tx.place_categories.findMany({
      where: { is_active: true },
      select: { id: true, name_en: true, name_ar: true },
      orderBy: [{ sort_order: "asc" }, { id: "asc" }],
    });
  }
}
