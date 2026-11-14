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
] as const;

export type Tags = Record<string, string>;
export function classify(tags: Tags): string | null {
  const t = tags;
  if (t.sport === "karting") return "karting";
  if (t.sport === "bowling" || t.leisure === "bowling_alley") return "bowling";
  if (t.sport === "billiards") return "billiards";
  if (t.leisure === "escape_game") return "escape_rooms";
  if (t.leisure === "virtual_reality") return "vr_centers";
  if (t.leisure === "trampoline_park") return "trampoline_parks";
  if (t.leisure === "amusement_arcade") return "arcades";
  if (t.leisure === "gaming_centre" || t.leisure === "gaming_center")
    return "gaming_centers";
  if (t.leisure === "ice_rink") return "ice_skating";
  if (t.leisure === "sports_centre" || t.leisure === "fitness_centre")
    return "sports_centers";
  if (t.leisure === "indoor_play") return "indoor_activities";
  if (t.leisure === "adventure_park") return "adventure_activities";
  if (t.shop === "coffee") return "coffee_shops"; // retail coffee, distinct from amenity=cafe
  const mappings: Record<string, Record<string, string>> = {
    amenity: {
      restaurant: "restaurants",
      fast_food: "fast_food",
      cafe: "cafes",
      ice_cream: "ice_cream",
      cinema: "cinemas",
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
  if (t.tourism === "attraction" && t.indoor === "no")
    return "outdoor_attractions";
  return null;
}

export function mappedVibes(category: string, tags: Tags): string[] {
  const result = new Set<string>();
  const group = categories.find((c) => c[0] === category)?.[3];
  if (group === "food_drinks")
    result.add(
      ["cafes", "coffee_shops"].includes(category)
        ? "coffee_conversations"
        : "food_dining",
    );
  if (group === "outdoor") result.add("outdoor_nature");
  if (group === "culture") result.add("culture_exploring");
  if (group === "shopping") result.add("shopping");
  if (category === "cinemas") result.add("movies");
  if (
    [
      "bowling",
      "escape_rooms",
      "gaming_centers",
      "arcades",
      "vr_centers",
      "trampoline_parks",
      "billiards",
      "amusement_parks",
      "indoor_activities",
    ].includes(category)
  )
    result.add("fun_games");
  if (
    ["bowling", "billiards", "social_clubs", "group_activities"].includes(
      category,
    )
  )
    result.add("friends_hangout");
  if (["escape_rooms", "karting", "adventure_activities"].includes(category))
    result.add("adventure");
  if (["sports_centers", "ice_skating"].includes(category))
    result.add("sports_active");
  if (tags.fee === "no" || tags.charge === "0") result.add("budget_friendly");
  if (tags.coworking === "yes" || tags.amenity === "coworking_space")
    result.add("study_work");
  return [...result];
}
