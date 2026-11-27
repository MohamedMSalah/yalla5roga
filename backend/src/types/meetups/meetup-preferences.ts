import {
  meetup_budget_level, meetup_optimization_priority, travel_fairness_mode,
  type meetup_optimization,
} from "@prisma/client";

export const TravelFairnessMode = travel_fairness_mode;
export type TravelFairnessMode = travel_fairness_mode;

export const BudgetLevel = { ...meetup_budget_level, UNKNOWN: "UNKNOWN" } as const;
export type BudgetLevel = typeof BudgetLevel[keyof typeof BudgetLevel];
export const selectableBudgetLevels = Object.values(meetup_budget_level);

export const OptimizationPriority = meetup_optimization_priority;
export type OptimizationPriority = meetup_optimization_priority;

export const minimumRatings = [3, 4, 4.5] as const;
export const maximumTravelDurations = [900, 1800, 2700, 3600, 5400] as const;

export interface MeetupPreferences {
  categoryIds: string[];
  budgetLevels: meetup_budget_level[];
  minimumRating: typeof minimumRatings[number] | null;
  travelFairnessMode: TravelFairnessMode;
  maximumTravelDurationSeconds: typeof maximumTravelDurations[number] | null;
  additionalPriorities: OptimizationPriority[];
  plannedMeetupAt: Date | null;
  requireOpenAtMeetupTime: boolean;
}

export function defaultMeetupPreferences(legacy?: meetup_optimization): MeetupPreferences {
  return {
    categoryIds: [],
    budgetLevels: [],
    minimumRating: null,
    travelFairnessMode: legacy === "SHORTEST_TOTAL_TIME" ? "FASTEST_OVERALL" : "BALANCED",
    maximumTravelDurationSeconds: null,
    additionalPriorities: [],
    plannedMeetupAt: null,
    requireOpenAtMeetupTime: false,
  };
}

export function legacyOptimization(mode: TravelFairnessMode): meetup_optimization {
  return mode === "FASTEST_OVERALL" ? "SHORTEST_TOTAL_TIME" : "BALANCED";
}
