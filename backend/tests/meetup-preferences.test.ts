import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { prisma } from "../src/config/database.js";
import {
  MeetupCandidateFilterService, type MeetupCandidate, type MeetupJourney, type MeetupRoutingEvidence,
} from "../src/services/meetups/meetup-candidate-filter.service.js";
import { MeetupCandidateRankingService } from "../src/services/meetups/meetup-candidate-ranking.service.js";
import { isOpenAt } from "../src/services/meetups/meetup-opening-hours.js";
import {
  defaultMeetupPreferences, maximumTravelDurations, minimumRatings, OptimizationPriority,
  selectableBudgetLevels, TravelFairnessMode,
} from "../src/types/meetups/meetup-preferences.js";
import { meetupPreferencesBody } from "../src/validators/meetups/meetup-preferences.validator.js";
import { isolatedDatabase } from "./support/isolated-database.js";

function subsets<T>(values: readonly T[]) {
  return values.reduce<T[][]>((result, value) => [...result, ...result.map(items => [...items, value])], [[]]);
}

function routing(scenarios: Record<string, number[]>,
  distances: Record<string, number[]> = {}): MeetupRoutingEvidence {
  const journeysByPlace = new Map<string, MeetupJourney[]>();
  for (const [place, durations] of Object.entries(scenarios)) {
    journeysByPlace.set(place, durations.map((durationSeconds, i) => ({
      durationSeconds, distanceMeters: distances[place]?.[i] ?? durationSeconds,
    })));
  }
  return { status: "AVAILABLE", participantCount: 2, journeysByPlace };
}

function candidate(placeId: string, bayesianRating: number | null = null, amount?: number): MeetupCandidate {
  return { placeId, bayesianRating, categoryId: "test", budgetLevel: "UNKNOWN", averageRating: null,
    comparablePrice: amount === undefined ? null : { categoryId: "test", amount, currency: "EGP", basis: "ADMISSION" } };
}

test("all 4,608 budget, rating, fairness, travel-limit and priority chip combinations validate and keep their primary objective", () => {
  const ranker = new MeetupCandidateRankingService();
  const candidates = [candidate("balanced"), candidate("equal", 5), candidate("fastest", 4), candidate("too-long", 5)];
  const routes = routing({ balanced: [450, 550], equal: [565, 490], fastest: [100, 805], "too-long": [1000, 1000] });
  let count = 0;
  for (const travelFairnessMode of Object.values(TravelFairnessMode)) {
    for (const budgetLevels of subsets(selectableBudgetLevels)) {
      for (const minimumRating of [null, ...minimumRatings]) {
        for (const maximumTravelDurationSeconds of [null, ...maximumTravelDurations]) {
          for (const additionalPriorities of subsets(Object.values(OptimizationPriority))) {
            const parsed = meetupPreferencesBody.parse({
              ...defaultMeetupPreferences(), travelFairnessMode, budgetLevels, minimumRating,
              maximumTravelDurationSeconds, additionalPriorities,
            });
            assert.deepEqual(parsed.additionalPriorities, additionalPriorities);
            const scored = ranker.rank(candidates, parsed, routes).map(item => item.placeId);
            const expected = { BALANCED: "balanced", EQUAL_TRAVEL: "equal", FASTEST_OVERALL: "fastest" }[travelFairnessMode];
            assert.equal(scored[0], expected);
            if (maximumTravelDurationSeconds === 900) assert.ok(!scored.includes("too-long"));
            count++;
          }
        }
      }
    }
  }
  assert.equal(count, 4608);
});

test("ranking honors efficiency, participant dominance, comparable costs and selected signals within travel ties", () => {
  const ranker = new MeetupCandidateRankingService();
  const defaults = defaultMeetupPreferences();
  const equalCandidates = ["balanced", "unequal", "dominated", "slow"].map(id => candidate(id));
  assert.deepEqual(ranker.rank(equalCandidates, { ...defaults, travelFairnessMode: "EQUAL_TRAVEL" },
    routing({ balanced: [450, 550], unequal: [300, 600], dominated: [470, 550], slow: [900, 900] }))
    .map(item => item.placeId), ["balanced", "unequal"]);

  const candidates = [candidate("a", 4, 100), candidate("b", 5, 200), candidate("c", 3, 300)];
  const routes = routing({ a: [500, 500], b: [500, 500], c: [500, 500] },
    { a: [500, 500], b: [250, 250], c: [1000, 1000] });
  for (const travelFairnessMode of Object.values(TravelFairnessMode)) {
    const rankIds = (...additionalPriorities: OptimizationPriority[]) =>
      ranker.rank(candidates, { ...defaults, travelFairnessMode, additionalPriorities }, routes).map(item => item.placeId);
    assert.deepEqual(rankIds("TOP_RATED"), ["b", "a", "c"]);
    assert.deepEqual(rankIds("BUDGET_FRIENDLY"), ["a", "b", "c"]);
    assert.deepEqual(rankIds("SHORTEST_DISTANCE"), ["b", "a", "c"]);
    assert.deepEqual(rankIds("TOP_RATED", "BUDGET_FRIENDLY"), ["a", "b", "c"]);
    assert.deepEqual(rankIds("TOP_RATED", "BUDGET_FRIENDLY", "SHORTEST_DISTANCE"), ["b", "a", "c"]);
  }

  const tied = [candidate("b", 4, 1), candidate("a", 4, 200)];
  const pricePriority = { ...defaults, additionalPriorities: [OptimizationPriority.BUDGET_FRIENDLY] };
  const first = tied[0]!;
  const incompatible = [
    { ...first, comparablePrice: { ...first.comparablePrice!, basis: "PER_PERSON" as const } },
    { ...first, comparablePrice: { ...first.comparablePrice!, categoryId: "other" } },
    { ...first, comparablePrice: null },
  ];
  for (const variant of incompatible) {
    assert.equal(ranker.rank([variant, tied[1]!], pricePriority, routes)[0]?.placeId, "a");
  }
  const withUnpriced = [candidate("a", 4, 200), candidate("b", 4), candidate("c", 4, 1)];
  assert.deepEqual(ranker.rank(withUnpriced, pricePriority, routes).map(item => item.placeId), ["c", "b", "a"]);

  const filters = new MeetupCandidateFilterService();
  const unavailable = { status: "UNAVAILABLE" } as const;
  const limited = { ...defaults, maximumTravelDurationSeconds: 900 } as const;
  assert.equal(filters.applyTravelLimit(tied, limited, unavailable).length, 2);
  assert.deepEqual(ranker.rank(tied, limited, unavailable), []);
  assert.deepEqual(filters.applyTravelLimit(tied, limited, routing({ a: [0, 900], b: [1, 901] }))
    .map(item => item.placeId), ["a"]);
  assert.deepEqual(filters.applyTravelLimit(tied, limited, routing({ a: [100], b: [NaN, 2] })), []);
});

test("opening-hours checks use Cairo time, overnight carryover and strict proof", () => {
  const open = (expression: string | null, instant: string) =>
    isOpenAt({ opening_hours: expression, place_hours: [] }, new Date(instant));
  assert.equal(open("Fr 22:00-02:00", "2026-11-27T23:30:00Z"), true);
  assert.equal(open("Fr 22:00-02:00", "2026-11-28T00:00:00Z"), false);
  assert.equal(open("Fr 22:00-24:00", "2026-11-27T21:59:00Z"), true);
  assert.equal(open("Fr 22:00-24:00", "2026-11-27T22:00:00Z"), false);
  assert.equal(open("Fr 22:00-02:00; PH off", "2026-11-27T23:30:00Z"), false);
  assert.equal(open(null, "2026-11-27T23:30:00Z"), false);
  assert.equal(open("24/7", "2026-11-27T23:30:00Z"), true);
  assert.equal(open("Fr 20:00-22:00", "2026-07-03T17:00:00Z"), true);
  assert.equal(open("Fr 20:00-22:00", "2026-11-27T17:00:00Z"), false);
  const hours = [{ day: "friday" as const, is_closed: false, source: "manual",
    opens_at: new Date("1970-01-01T22:00:00Z"), closes_at: new Date("1970-01-01T02:00:00Z") }];
  assert.equal(isOpenAt({ opening_hours: null, place_hours: hours }, new Date("2026-11-27T23:30:00Z")), true);
  assert.equal(isOpenAt({ opening_hours: "24/7", place_hours: [{ ...hours[0]!, is_closed: true }] },
    new Date("2026-11-27T21:30:00Z")), false);
});

test("real catalog filtering uses actual ratings, relative levels, hours and evidenced prices",
  { skip: !isolatedDatabase }, async () => {
  const rollback = new Error("rollback isolated fixtures");
  const budget = randomUUID(), unknown = randomUUID(), unrated = randomUUID(), unknownHours = randomUUID(), other = randomUUID();
  const moderate = randomUUID(), expensive = randomUUID(), inactive = randomUUID();
  const catalog = new MeetupCandidateFilterService();
  const now = new Date("2026-11-27T23:30:00Z");
  const defaults = defaultMeetupPreferences();
  await assert.rejects(prisma.$transaction(async tx => {
    const categoryIds = [randomUUID(), randomUUID()];
    await tx.place_categories.createMany({ data: categoryIds.map(id => ({
      id, name_en: "Fixture", name_ar: "اختبار", group_id: "test", icon: "test", legacy_vibe: "activity",
    })) });
    await tx.places.createMany({ data: [
      { id: budget, price_level: "budget" }, { id: unknown, price_level: null },
      { id: unrated, price_level: "free" }, { id: unknownHours, price_level: "budget", opening_hours: null },
      { id: other, price_level: "budget", category_id: categoryIds[1] },
      { id: moderate, price_level: "moderate" }, { id: expensive, price_level: "luxury" },
      { id: inactive, price_level: "budget", is_active: false },
    ].map(row => ({ name: "Fixture", opening_hours: "Fr 22:00-02:00", category_id: categoryIds[0], ...row })) });
    await tx.place_prices.create({ data: {
      place_id: unknown, label: "Admission", amount: 0, currency: "EGP", source: "osm", evidence: { fee: "no" },
    } });
    await tx.place_rating_statistics.createMany({ data: [
      { place_id: budget, rating_sum: 470, rating_count: 100, four_star_count: 30, five_star_count: 70 },
      { place_id: unknown, rating_sum: 5, rating_count: 1, five_star_count: 1 },
      { place_id: unknownHours, rating_sum: 4, rating_count: 1, four_star_count: 1 },
      { place_id: other, rating_sum: 5, rating_count: 1, five_star_count: 1 },
      { place_id: moderate, rating_sum: 300, rating_count: 100, three_star_count: 100 },
    ] });
    const ids = [budget, unknown, unrated, unknownHours, other, moderate, expensive, inactive];
    const lookup = (preferences = defaults) => catalog.findCatalogCandidates(tx, ids, preferences, now);
    const all = await lookup();
    assert.equal(all.length, 7);
    assert.deepEqual(all.find(place => place.placeId === unknown)?.comparablePrice,
      { categoryId: categoryIds[0], amount: 0, basis: "ADMISSION", currency: "EGP" });
    assert.equal(all.find(place => place.placeId === unknown)?.budgetLevel, "UNKNOWN");

    for (const budgetLevels of subsets(selectableBudgetLevels)) {
      const result = await lookup({ ...defaults, budgetLevels });
      const expected = budgetLevels.length ? all.filter(place =>
        budgetLevels.some(level => level === place.budgetLevel)) : all;
      assert.deepEqual(result.map(place => place.placeId).sort(), expected.map(place => place.placeId).sort());
    }

    const filtered = await lookup({ ...defaults, categoryIds: [categoryIds[0]!],
      budgetLevels: ["AFFORDABLE"], minimumRating: 4, requireOpenAtMeetupTime: true,
      plannedMeetupAt: now, additionalPriorities: ["TOP_RATED"] });
    assert.deepEqual(filtered.map(place => place.placeId), [budget]);
    assert.equal(filtered[0]?.averageRating, 4.7);
    const rated = await lookup({ ...defaults, minimumRating: 4.5, additionalPriorities: ["TOP_RATED"] });
    assert.deepEqual(rated.map(place => place.placeId).sort(), [budget, unknown, other].sort());
    assert.ok((rated.find(place => place.placeId === budget)?.bayesianRating ?? 0) >
      (rated.find(place => place.placeId === unknown)?.bayesianRating ?? 0));
    throw rollback;
  }), rollback);
});
