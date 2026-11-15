import { PlaceVibeClassifier } from "./place-vibe-classifier.js";
/** Stable catalog identifiers; outing_vibe remains a compatibility projection. */
export const categories = [
  ["restaurants", "Restaurants", "مطاعم", "food_drinks", "restaurant", "food"],
  ["fast_food", "Fast Food", "وجبات سريعة", "food_drinks", "fastfood", "food"],
  ["cafes", "Cafes", "كافيهات", "food_drinks", "local_cafe", "food"],
  [
    "coffee_shops",
    "Coffee Shops",
    "محلات قهوة",
    "food_drinks",
    "coffee",
    "food",
  ],
  ["bakeries", "Bakeries", "مخابز", "food_drinks", "bakery_dining", "food"],
  [
    "dessert_shops",
    "Dessert Shops",
    "محلات حلويات",
    "food_drinks",
    "cake",
    "food",
  ],
  [
    "ice_cream",
    "Ice Cream Shops",
    "آيس كريم",
    "food_drinks",
    "icecream",
    "food",
  ],
  ["cinemas", "Cinemas", "سينمات", "entertainment", "movie", "movie"],
  ["bowling", "Bowling", "بولينج", "entertainment", "sports", "activity"],
  [
    "escape_rooms",
    "Escape Rooms",
    "غرف الهروب",
    "entertainment",
    "lock",
    "activity",
  ],
  [
    "gaming_centers",
    "Gaming Centers",
    "مراكز ألعاب",
    "entertainment",
    "sports_esports",
    "activity",
  ],
  [
    "arcades",
    "Arcades",
    "ألعاب أركيد",
    "entertainment",
    "sports_esports",
    "activity",
  ],
  [
    "vr_centers",
    "VR Centers",
    "واقع افتراضي",
    "entertainment",
    "view_in_ar",
    "activity",
  ],
  [
    "trampoline_parks",
    "Trampoline Parks",
    "ترامبولين",
    "entertainment",
    "sports_gymnastics",
    "activity",
  ],
  [
    "amusement_parks",
    "Amusement Parks",
    "ملاهي",
    "entertainment",
    "attractions",
    "activity",
  ],
  ["billiards", "Billiards", "بلياردو", "entertainment", "sports", "activity"],
  ["parks", "Parks", "حدائق عامة", "outdoor", "park", "outdoor"],
  ["gardens", "Gardens", "حدائق نباتية", "outdoor", "local_florist", "outdoor"],
  ["zoos", "Zoos", "حدائق حيوان", "outdoor", "pets", "outdoor"],
  [
    "picnic_areas",
    "Picnic Areas",
    "أماكن نزهات",
    "outdoor",
    "forest",
    "outdoor",
  ],
  [
    "outdoor_attractions",
    "Outdoor Attractions",
    "معالم خارجية",
    "outdoor",
    "landscape",
    "outdoor",
  ],
  [
    "shopping_malls",
    "Shopping Malls",
    "مولات",
    "shopping",
    "shopping_bag",
    "activity",
  ],
  [
    "shopping_centers",
    "Shopping Centers",
    "مراكز تسوق",
    "shopping",
    "store",
    "activity",
  ],
  ["markets", "Markets", "أسواق", "shopping", "storefront", "activity"],
  [
    "karting",
    "Karting",
    "كارتينج",
    "activities",
    "sports_motorsports",
    "activity",
  ],
  [
    "sports_centers",
    "Sports Centers",
    "مراكز رياضية",
    "activities",
    "fitness_center",
    "activity",
  ],
  [
    "ice_skating",
    "Ice Skating",
    "تزلج على الجليد",
    "activities",
    "sports",
    "activity",
  ],
  [
    "indoor_activities",
    "Indoor Activities",
    "أنشطة داخلية",
    "activities",
    "sports_esports",
    "activity",
  ],
  [
    "adventure_activities",
    "Adventure Activities",
    "أنشطة مغامرات",
    "activities",
    "hiking",
    "activity",
  ],
  ["museums", "Museums", "متاحف", "culture", "museum", "activity"],
  [
    "art_galleries",
    "Art Galleries",
    "معارض فنية",
    "culture",
    "palette",
    "activity",
  ],
  [
    "historical_attractions",
    "Historical Attractions",
    "معالم تاريخية",
    "culture",
    "account_balance",
    "outdoor",
  ],
  [
    "cultural_centers",
    "Cultural Centers",
    "مراكز ثقافية",
    "culture",
    "theater_comedy",
    "activity",
  ],
  ["lounges", "Lounges", "لاونج", "social", "weekend", "food"],
  [
    "social_clubs",
    "Social Clubs",
    "نوادي اجتماعية",
    "social",
    "groups",
    "activity",
  ],
  [
    "group_activities",
    "Group Activities",
    "أنشطة جماعية",
    "social",
    "groups",
    "activity",
  ],
  ["water_parks", "Water Parks", "ألعاب مائية", "entertainment", "attractions", "activity"],
  ["tourist_attractions", "Tourist Attractions", "معالم سياحية", "culture", "account_balance", "outdoor"],
  ["theaters", "Theaters", "مسارح", "culture", "theater_comedy", "activity"],
  ["football_fields", "Football Fields", "ملاعب كرة قدم", "activities", "sports", "activity"],
  ["padel_courts", "Padel Courts", "ملاعب بادل", "activities", "sports", "activity"],
  ["swimming_pools", "Swimming Pools", "حمامات سباحة", "activities", "sports", "activity"],
  ["kids_entertainment", "Kids Entertainment", "ترفيه الأطفال", "entertainment", "attractions", "activity"],
  ["family_entertainment", "Family Entertainment", "ترفيه عائلي", "entertainment", "groups", "activity"],
] as const;

export const vibes = [
  ["chill_relax", "Chill & Relax", "هدوء واسترخاء", "spa"],
  ["friends_hangout", "Friends Hangout", "خروجة أصحاب", "groups"],
  ["romantic", "Romantic", "رومانسي", "favorite"],
  ["family", "Family", "عائلي", "family_restroom"],
  ["adventure", "Adventure", "مغامرة", "hiking"],
  ["fun_games", "Fun & Games", "مرح وألعاب", "sports_esports"],
  ["food_dining", "Food & Dining", "أكل ومطاعم", "restaurant"],
  ["coffee_conversations", "Coffee & Conversations", "قهوة ودردشة", "coffee"],
  ["outdoor_nature", "Outdoor & Nature", "طبيعة وهواء طلق", "park"],
  ["shopping", "Shopping", "تسوق", "shopping_bag"],
  ["movies", "Movies", "أفلام", "movie"],
  ["culture_exploring", "Culture & Exploring", "ثقافة واستكشاف", "museum"],
  ["sports_active", "Sports & Active", "رياضة ونشاط", "fitness_center"],
  ["study_work", "Study & Work", "مذاكرة وشغل", "school"],
  ["budget_friendly", "Budget Friendly", "اقتصادي", "savings"],
  ["entertainment", "Entertainment", "ترفيه", "attractions"],
  ["relaxing", "Relaxing", "استرخاء", "spa"],
  ["date_night", "Date Night", "خروجة مسائية", "favorite"],
  ["kids_friendly", "Kids Friendly", "مناسب للأطفال", "family_restroom"],
  ["group_activities", "Group Activities", "أنشطة جماعية", "groups"],
  ["luxury", "Luxury", "فاخر", "favorite"],
  ["active", "Active", "حركة ونشاط", "fitness_center"],
  ["photography", "Photography", "تصوير", "landscape"],
] as const;

export type Tags = Record<string, string>;
export function classify(tags: Tags): string | null {
  const t = tags;
  if (t.sport === "karting") return "karting";
  if (t.sport === "bowling" || t.leisure === "bowling_alley") return "bowling";
  if (t.sport === "billiards") return "billiards";
  if (t.leisure === "pitch" && t.sport?.split(";").includes("soccer")) return "football_fields";
  if (t.leisure === "pitch" && t.sport?.split(";").includes("padel")) return "padel_courts";
  if (t.leisure === "swimming_pool") return "swimming_pools";
  if (t.leisure === "water_park") return "water_parks";
  if (t.leisure === "escape_game") return "escape_rooms";
  if (t.leisure === "virtual_reality") return "vr_centers";
  if (t.leisure === "trampoline_park") return "trampoline_parks";
  if (t.leisure === "amusement_arcade") return "arcades";
  if (t.leisure === "gaming_centre" || t.leisure === "gaming_center")
    return "gaming_centers";
  if (t.leisure === "ice_rink") return "ice_skating";
  if (t.leisure === "sports_centre" || t.leisure === "fitness_centre")
    return "sports_centers";
  if (t.leisure === "indoor_play") return "kids_entertainment";
  if (t.leisure === "adventure_park") return "adventure_activities";
  if (t.shop === "coffee") return "coffee_shops"; // retail coffee, distinct from amenity=cafe
  const mappings: Record<string, Record<string, string>> = {
    amenity: {
      restaurant: "restaurants",
      fast_food: "fast_food",
      cafe: "cafes",
      ice_cream: "ice_cream",
      cinema: "cinemas",
      theatre: "theaters",
      marketplace: "markets",
      arts_centre: "cultural_centers",
      social_centre: "social_clubs",
      community_centre: "group_activities",
      lounge: "lounges",
    },
    shop: {
      bakery: "bakeries",
      pastry: "dessert_shops",
      confectionery: "dessert_shops",
      ice_cream: "ice_cream",
      mall: "shopping_malls",
      department_store: "shopping_centers",
    },
    leisure: { park: "parks", garden: "gardens", social_club: "social_clubs" },
    tourism: {
      zoo: "zoos",
      picnic_site: "picnic_areas",
      theme_park: "amusement_parks",
      museum: "museums",
      gallery: "art_galleries",
      viewpoint: "outdoor_attractions",
    },
  };
  for (const [key, values] of Object.entries(mappings))
    if (values[t[key]!]) return values[t[key]!]!;
  if (
    [
      "castle",
      "archaeological_site",
      "monument",
      "memorial",
      "ruins",
      "fort",
    ].includes(t.historic!)
  )
    return "historical_attractions";
  if (t.tourism === "attraction") return "tourist_attractions";
  return null;
}

export function mappedVibes(category: string, tags: Tags): string[] {
  return new PlaceVibeClassifier().classify(category, tags).map((v) => v.id);
}
