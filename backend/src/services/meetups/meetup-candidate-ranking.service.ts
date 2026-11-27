import { meetupOptimizationPolicy, type OptimizationPolicy } from "../../config/meetup-optimization-policy.js";
import { OptimizationPriority, type MeetupPreferences, type TravelFairnessMode } from "../../types/meetups/meetup-preferences.js";
import {
  MeetupCandidateFilterService, type MeetupCandidate, type MeetupRoutingEvidence, type RoutedMeetupCandidate,
} from "./meetup-candidate-filter.service.js";

function metrics(candidate: RoutedMeetupCandidate) {
  const times = candidate.journeys.map(journey => journey.durationSeconds);
  const distances = candidate.journeys.map(journey => journey.distanceMeters);
  const maximum = Math.max(...times);
  return {
    candidate,
    times,
    maximum,
    spread: maximum - Math.min(...times),
    total: times.reduce((sum, seconds) => sum + seconds, 0),
    distance: distances.every(distance => distance !== null && Number.isFinite(distance) && distance >= 0)
      ? distances.reduce<number>((sum, distance) => sum + (distance ?? 0), 0) : null,
  };
}

type Metrics = ReturnType<typeof metrics>;

function travelOrder(mode: TravelFairnessMode, a: Metrics, b: Metrics) {
  switch (mode) {
    case "BALANCED": return a.maximum - b.maximum || a.total - b.total || a.spread - b.spread;
    case "EQUAL_TRAVEL": return a.spread - b.spread || a.maximum - b.maximum || a.total - b.total;
    case "FASTEST_OVERALL": return a.total - b.total;
  }
}

function dominates(a: Metrics, b: Metrics) {
  return a.times.every((time, i) => time <= b.times[i]!) && a.times.some((time, i) => time < b.times[i]!);
}

function lowerIsBetter(values: readonly number[]) {
  const min = Math.min(...values), max = Math.max(...values);
  return (value: number) => min === max ? 0 : (max - value) / (max - min);
}

export class MeetupCandidateRankingService {
  constructor(private readonly policy: OptimizationPolicy = meetupOptimizationPolicy,
    private readonly filters = new MeetupCandidateFilterService()) {}

  rank(catalogMatches: readonly MeetupCandidate[], preferences: MeetupPreferences,
    routing: MeetupRoutingEvidence): RoutedMeetupCandidate[] {
    if (routing.status === "UNAVAILABLE") return [];
    const eligible = this.filters.attachTravel(catalogMatches, routing, preferences.maximumTravelDurationSeconds ?? Infinity)
      .map(metrics);

    const mode = preferences.travelFairnessMode;
    const contenders = mode === "EQUAL_TRAVEL" ? this.guardEqualTravel(eligible) : eligible;
    const ordered = contenders.sort((a, b) => travelOrder(mode, a, b));
    const ranked: RoutedMeetupCandidate[] = [];
    for (let start = 0; start < ordered.length;) {
      let end = start + 1;
      while (end < ordered.length && travelOrder(mode, ordered[start]!, ordered[end]!) === 0) end++;
      ranked.push(...this.rankTies(ordered.slice(start, end), preferences.additionalPriorities));
      start = end;
    }
    return ranked;
  }

  private guardEqualTravel(eligible: Metrics[]) {
    if (!eligible.length) return eligible;
    // Anchor both ratios to one feasible candidate so the guardrail never eliminates every place.
    const anchor = eligible.reduce((a, b) => travelOrder("BALANCED", a, b) <= 0 ? a : b);
    const { maximumTravelRatio, totalTravelRatio } = this.policy.equalTravelEfficiency;
    return eligible.filter(candidate =>
      candidate.maximum <= anchor.maximum * maximumTravelRatio && candidate.total <= anchor.total * totalTravelRatio &&
      !eligible.some(other => dominates(other, candidate)));
  }

  private rankTies(tied: Metrics[], priorities: readonly OptimizationPriority[]): RoutedMeetupCandidate[] {
    const weights = this.policy.priorityWeights;
    const distances = tied.map(item => item.distance);
    const distance = distances.every(value => value !== null) ? lowerIsBetter(distances) : null;
    const byScore = (a: { candidate: RoutedMeetupCandidate; score: number },
      b: { candidate: RoutedMeetupCandidate; score: number }) =>
      b.score - a.score || a.candidate.placeId.localeCompare(b.candidate.placeId);
    const ranked = tied.map(({ candidate, distance: meters }) => ({
      candidate,
      score: (priorities.includes("TOP_RATED") ? (candidate.bayesianRating ?? 0) / 5 * weights.TOP_RATED : 0) +
        (priorities.includes("SHORTEST_DISTANCE") && distance && meters !== null
          ? distance(meters) * weights.SHORTEST_DISTANCE : 0),
    })).sort(byScore);
    if (priorities.includes("BUDGET_FRIENDLY")) {
      const cohorts = new Map<string, { index: number; amount: number }[]>();
      ranked.forEach(({ candidate }, index) => {
        const price = candidate.comparablePrice;
        if (!price) return;
        const key = JSON.stringify([price.categoryId, price.basis, price.currency]);
        const cohort = cohorts.get(key) ?? [];
        cohort.push({ index, amount: price.amount });
        cohorts.set(key, cohort);
      });
      // Keep each price cohort in its existing slots. A price can only reorder comparable places.
      for (const cohort of cohorts.values()) {
        if (cohort.length < 2) continue;
        const affordability = lowerIsBetter(cohort.map(price => price.amount));
        const ordered = cohort.map(({ index, amount }) => ({
          ...ranked[index]!, score: ranked[index]!.score + affordability(amount) * weights.BUDGET_FRIENDLY,
        })).sort(byScore);
        cohort.forEach(({ index }, i) => { ranked[index] = ordered[i]!; });
      }
    }
    return ranked.map(item => item.candidate);
  }
}
