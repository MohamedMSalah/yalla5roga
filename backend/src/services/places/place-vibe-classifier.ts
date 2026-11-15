import type { Tags } from "./taxonomy.js";

export type VibeInference = { id: string; confidence: number; evidence: { rule: string; version: number } };
export const CATEGORY_VIBES: Record<string, string[]> = {
  restaurants: ["food_dining", "friends_hangout"], fast_food: ["food_dining"],
  cafes: ["coffee_conversations", "chill_relax", "friends_hangout"],
  coffee_shops: ["coffee_conversations"], bakeries: ["food_dining"], dessert_shops: ["food_dining"], ice_cream: ["food_dining"],
  cinemas: ["movies", "entertainment", "date_night"],
  bowling: ["fun_games", "friends_hangout", "group_activities", "entertainment"],
  escape_rooms: ["adventure", "fun_games", "group_activities"],
  gaming_centers: ["fun_games", "friends_hangout", "entertainment"],
  arcades: ["fun_games", "entertainment"], vr_centers: ["fun_games", "entertainment"],
  parks: ["outdoor_nature", "family", "relaxing"], gardens: ["outdoor_nature", "relaxing"],
  museums: ["culture_exploring", "family"], historical_attractions: ["culture_exploring"],
  tourist_attractions: ["culture_exploring"], art_galleries: ["culture_exploring"], theaters: ["culture_exploring", "entertainment"],
  cultural_centers: ["culture_exploring"], shopping_malls: ["shopping"], shopping_centers: ["shopping"], markets: ["shopping"],
  sports_centers: ["sports_active", "active"], football_fields: ["sports_active", "active", "group_activities"],
  padel_courts: ["sports_active", "active", "group_activities"], swimming_pools: ["sports_active", "active"],
  billiards: ["fun_games", "friends_hangout", "group_activities"],
  kids_entertainment: ["entertainment", "family", "kids_friendly"], family_entertainment: ["family", "entertainment"],
  amusement_parks: ["entertainment", "adventure"], water_parks: ["entertainment", "active"],
  adventure_activities: ["adventure", "active"], karting: ["adventure", "active"],
  trampoline_parks: ["entertainment", "active"], ice_skating: ["sports_active", "active"],
  picnic_areas: ["outdoor_nature", "family"], zoos: ["outdoor_nature", "family"],
  outdoor_attractions: ["outdoor_nature"], social_clubs: ["friends_hangout", "group_activities"],
  group_activities: ["group_activities"], lounges: ["chill_relax"],
};

/** Category inference is distinct from evidence for specific venue facilities. */
export class PlaceVibeClassifier {
  constructor(private readonly rules: Readonly<Record<string, readonly string[]>> = CATEGORY_VIBES) {}
  classify(primary: string, tags: Tags = {}, secondary: string[] = []): VibeInference[] {
    const result = new Map<string, VibeInference>();
    const add = (id: string, rule: string, confidence: number) => {
      if (!result.has(id) || result.get(id)!.confidence < confidence)
        result.set(id, { id, confidence, evidence: { rule, version: 1 } });
    };
    for (const category of [primary, ...secondary])
      for (const id of this.rules[category] ?? []) add(id, `category:${category}`, .8);
    if (tags.fee === "no" || tags.charge === "0") add("budget_friendly", "explicit_free_admission", .95);
    if (tags.coworking === "yes" || tags.amenity === "coworking_space") add("study_work", "explicit_coworking", .95);
    if (tags.kids_area === "yes" || tags["playground:indoor"] === "yes") add("kids_friendly", "explicit_kids_facility", .95);
    if (tags.photography === "yes") add("photography", "explicit_photography", .9);
    // Generic descriptions, Wi-Fi, cuisine and category names never prove romance/luxury/budget/work.
    return [...result.values()];
  }
}
