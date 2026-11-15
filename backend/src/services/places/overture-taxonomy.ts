/** Exact category tokens only. No substring matching (e.g. parking != park). */
export const OVERTURE_CATEGORIES: Record<string, string> = {
  restaurant: "restaurants", restaurants: "restaurants", food_truck: "fast_food", fast_food_restaurant: "fast_food",
  fast_food: "fast_food", cafe: "cafes", coffee_shop: "cafes", tea_house: "cafes", internet_cafe: "gaming_centers",
  bakery: "bakeries", dessert_shop: "dessert_shops", dessert: "dessert_shops", candy_store: "dessert_shops",
  ice_cream_shop: "ice_cream", ice_cream_and_frozen_yogurt: "ice_cream", movie_theater: "cinemas", cinema: "cinemas",
  park: "parks", public_park: "parks", garden: "gardens", botanical_garden: "gardens", botanical_gardens: "gardens",
  shopping_mall: "shopping_malls", shopping_center: "shopping_centers", shopping_centre: "shopping_centers",
  bowling_alley: "bowling", bowling: "bowling", escape_room: "escape_rooms", escape_game: "escape_rooms",
  video_game_arcade: "arcades", arcade: "arcades", amusement_arcade: "arcades", gaming_center: "gaming_centers",
  virtual_reality_center: "vr_centers", virtual_reality: "vr_centers", amusement_park: "amusement_parks",
  theme_park: "amusement_parks", water_park: "water_parks", museum: "museums", history_museum: "museums",
  historic_site: "historical_attractions", historical_site: "historical_attractions", archaeological_site: "historical_attractions",
  monument: "historical_attractions", castle: "historical_attractions", tourist_attraction: "tourist_attractions",
  art_gallery: "art_galleries", performing_arts_theater: "theaters", theater: "theaters", theatre: "theaters",
  sports_center: "sports_centers", recreation_center: "sports_centers", fitness_center: "sports_centers",
  soccer_field: "football_fields", football_field: "football_fields", padel_court: "padel_courts",
  billiards: "billiards", pool_hall: "billiards", swimming_pool: "swimming_pools", trampoline_park: "trampoline_parks",
  indoor_playground: "kids_entertainment", childrens_amusement_center: "kids_entertainment",
  family_entertainment_center: "family_entertainment", adventure_park: "adventure_activities",
  zoo: "zoos", aquarium: "family_entertainment", picnic_area: "picnic_areas", go_kart_track: "karting",
  cultural_center: "cultural_centers", social_club: "social_clubs", ice_skating_rink: "ice_skating",
  gym: "sports_centers", gymnastics_center: "sports_centers", martial_arts_club: "sports_centers",
  tennis_court: "sports_centers", squash_court: "sports_centers", basketball_court: "sports_centers",
  pool_billiards: "billiards", theatre_venue: "theaters", palace: "historical_attractions",
  sandwich_shop: "fast_food", diner: "restaurants", bistro: "restaurants",
  chocolatier: "dessert_shops", donut_shop: "dessert_shops", cupcake_shop: "dessert_shops", pie_shop: "dessert_shops",
  bagel_shop: "bakeries", frozen_yogurt_shop: "ice_cream", shaved_ice_shop: "ice_cream",
  indoor_playcenter: "kids_entertainment", paintball: "adventure_activities", rock_climbing_spot: "adventure_activities",
};
export type OvertureTaxonomy = { primary?: string; hierarchy?: string[]; alternates?: string[] };
export function classifyOverture(basic: string | undefined, taxonomy: OvertureTaxonomy = {}) {
  const path = [taxonomy.primary, ...(taxonomy.hierarchy ?? []).slice().reverse(), basic];
  const primary = path.map((token) => token && OVERTURE_CATEGORIES[token]).find(Boolean) || null;
  const alternates = [...new Set((taxonomy.alternates ?? []).map((token) => OVERTURE_CATEGORIES[token]).filter((v): v is string => !!v))];
  return { primary, secondary: alternates.filter((c) => c !== primary) };
}
