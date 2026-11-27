import { z } from "zod";
import {
  maximumTravelDurations, minimumRatings, OptimizationPriority, selectableBudgetLevels, TravelFairnessMode,
} from "../../types/meetups/meetup-preferences.js";

function distinctArray<T extends z.ZodType>(entry: T) {
  return z.array(entry).refine(values => new Set(values).size === values.length, "Select each value at most once");
}

export const meetupPreferencesBody = z.strictObject({
  categoryIds: distinctArray(z.string().min(1).max(64)),
  budgetLevels: distinctArray(z.enum(selectableBudgetLevels)),
  minimumRating: z.literal(minimumRatings).nullable(),
  travelFairnessMode: z.enum(TravelFairnessMode),
  maximumTravelDurationSeconds: z.literal(maximumTravelDurations).nullable(),
  additionalPriorities: distinctArray(z.enum(OptimizationPriority)),
  plannedMeetupAt: z.iso.datetime({ offset: true }).transform(value => new Date(value)).nullable(),
  requireOpenAtMeetupTime: z.boolean(),
});
