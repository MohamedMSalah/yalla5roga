import { OptimizationPriority } from "../types/meetups/meetup-preferences.js";

export interface OptimizationPolicy {
  equalTravelEfficiency: {
    maximumTravelRatio: number;
    totalTravelRatio: number;
  };
  priorityWeights: Readonly<Record<OptimizationPriority, number>>;
}

export const meetupOptimizationPolicy: OptimizationPolicy = {
  equalTravelEfficiency: {
    maximumTravelRatio: 1.25,
    totalTravelRatio: 1.25,
  },
  priorityWeights: {
    TOP_RATED: 1,
    BUDGET_FRIENDLY: 1,
    SHORTEST_DISTANCE: 1,
  },
};
