-- AlterTable
ALTER TABLE "places" ADD COLUMN     "address" VARCHAR(1000),
ADD COLUMN     "category_id" VARCHAR(64),
ADD COLUMN     "city" VARCHAR(100),
ADD COLUMN     "district" VARCHAR(100),
ADD COLUMN     "last_seen_at" TIMESTAMPTZ(6),
ADD COLUMN     "last_synced_at" TIMESTAMPTZ(6),
ADD COLUMN     "manually_managed" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "missing_sync_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "name_ar" VARCHAR(100),
ADD COLUMN     "name_en" VARCHAR(100),
ADD COLUMN     "opening_hours" VARCHAR(1000),
ADD COLUMN     "phone" VARCHAR(100),
ADD COLUMN     "source" VARCHAR(16) NOT NULL DEFAULT 'manual',
ADD COLUMN     "source_id" VARCHAR(32),
ADD COLUMN     "source_region" VARCHAR(16),
ADD COLUMN     "source_tags" JSONB NOT NULL DEFAULT '{}',
ADD COLUMN     "source_type" VARCHAR(16),
ADD COLUMN     "status" VARCHAR(32) NOT NULL DEFAULT 'active',
ADD COLUMN     "website" VARCHAR(2048);

-- CreateTable
CREATE TABLE "place_categories" (
    "id" VARCHAR(64) NOT NULL,
    "name_en" VARCHAR(100) NOT NULL,
    "name_ar" VARCHAR(100) NOT NULL,
    "group_id" VARCHAR(64) NOT NULL,
    "icon" VARCHAR(64) NOT NULL,
    "legacy_vibe" "outing_vibe" NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "place_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vibes" (
    "id" VARCHAR(64) NOT NULL,
    "name_en" VARCHAR(100) NOT NULL,
    "name_ar" VARCHAR(100) NOT NULL,
    "icon" VARCHAR(64) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "vibes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_vibes" (
    "place_id" UUID NOT NULL,
    "vibe_id" VARCHAR(64) NOT NULL,
    "source" VARCHAR(16) NOT NULL DEFAULT 'manual',

    CONSTRAINT "place_vibes_pkey" PRIMARY KEY ("place_id","vibe_id")
);

-- CreateTable
CREATE TABLE "place_sync_runs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "started_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ(6),
    "status" VARCHAR(32) NOT NULL,
    "imported_count" INTEGER NOT NULL DEFAULT 0,
    "updated_count" INTEGER NOT NULL DEFAULT 0,
    "closed_count" INTEGER NOT NULL DEFAULT 0,
    "skipped_count" INTEGER NOT NULL DEFAULT 0,
    "failed_count" INTEGER NOT NULL DEFAULT 0,
    "error_details" JSONB NOT NULL DEFAULT '[]',
    "dry_run" BOOLEAN NOT NULL DEFAULT false,
    "complete" BOOLEAN NOT NULL DEFAULT false,
    "coverage" JSONB NOT NULL DEFAULT '{}',
    "progress" JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT "place_sync_runs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_sync_lock" (
    "id" VARCHAR(32) NOT NULL,
    "token" UUID NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "place_sync_lock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_status_changes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "place_id" UUID NOT NULL,
    "run_id" UUID,
    "old_status" VARCHAR(32) NOT NULL,
    "new_status" VARCHAR(32) NOT NULL,
    "evidence" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "place_status_changes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_place_vibes_vibe" ON "place_vibes"("vibe_id", "place_id");

-- CreateIndex
CREATE INDEX "idx_place_sync_success" ON "place_sync_runs"("status", "completed_at");

-- CreateIndex
CREATE INDEX "idx_place_sync_started" ON "place_sync_runs"("started_at");

-- CreateIndex
CREATE INDEX "idx_place_status_history" ON "place_status_changes"("place_id", "created_at");

-- CreateIndex


-- CreateIndex


-- CreateIndex
CREATE INDEX "idx_places_status_category" ON "places"("status", "category_id");

-- CreateIndex
CREATE INDEX "idx_places_region_source" ON "places"("source_region", "source");

-- CreateIndex
CREATE UNIQUE INDEX "places_source_identity_key" ON "places"("source", "source_type", "source_id");

-- AddForeignKey
ALTER TABLE "places" ADD CONSTRAINT "places_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "place_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "place_vibes" ADD CONSTRAINT "place_vibes_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "place_vibes" ADD CONSTRAINT "place_vibes_vibe_id_fkey" FOREIGN KEY ("vibe_id") REFERENCES "vibes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "place_status_changes" ADD CONSTRAINT "place_status_changes_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Stable, bilingual taxonomy. Existing manually-created places retain their identities.
INSERT INTO place_categories(id,name_en,name_ar,group_id,icon,legacy_vibe,sort_order) VALUES
('restaurants','Restaurants','مطاعم','food_drinks','restaurant','food',0),
('fast_food','Fast Food','وجبات سريعة','food_drinks','fastfood','food',1),
('cafes','Cafes','كافيهات','food_drinks','local_cafe','food',2),
('coffee_shops','Coffee Shops','محلات قهوة','food_drinks','coffee','food',3),
('bakeries','Bakeries','مخابز','food_drinks','bakery_dining','food',4),
('dessert_shops','Dessert Shops','محلات حلويات','food_drinks','cake','food',5),
('ice_cream','Ice Cream Shops','آيس كريم','food_drinks','icecream','food',6),
('cinemas','Cinemas','سينمات','entertainment','movie','movie',7),
('bowling','Bowling','بولينج','entertainment','sports','activity',8),
('escape_rooms','Escape Rooms','غرف الهروب','entertainment','lock','activity',9),
('gaming_centers','Gaming Centers','مراكز ألعاب','entertainment','sports_esports','activity',10),
('arcades','Arcades','ألعاب أركيد','entertainment','sports_esports','activity',11),
('vr_centers','VR Centers','واقع افتراضي','entertainment','view_in_ar','activity',12),
('trampoline_parks','Trampoline Parks','ترامبولين','entertainment','sports_gymnastics','activity',13),
('amusement_parks','Amusement Parks','ملاهي','entertainment','attractions','activity',14),
('billiards','Billiards','بلياردو','entertainment','sports','activity',15),
('parks','Parks','حدائق عامة','outdoor','park','outdoor',16),
('gardens','Gardens','حدائق نباتية','outdoor','local_florist','outdoor',17),
('zoos','Zoos','حدائق حيوان','outdoor','pets','outdoor',18),
('picnic_areas','Picnic Areas','أماكن نزهات','outdoor','forest','outdoor',19),
('outdoor_attractions','Outdoor Attractions','معالم خارجية','outdoor','landscape','outdoor',20),
('shopping_malls','Shopping Malls','مولات','shopping','shopping_bag','activity',21),
('shopping_centers','Shopping Centers','مراكز تسوق','shopping','store','activity',22),
('markets','Markets','أسواق','shopping','storefront','activity',23),
('karting','Karting','كارتينج','activities','sports_motorsports','activity',24),
('sports_centers','Sports Centers','مراكز رياضية','activities','fitness_center','activity',25),
('ice_skating','Ice Skating','تزلج على الجليد','activities','sports','activity',26),
('indoor_activities','Indoor Activities','أنشطة داخلية','activities','sports_esports','activity',27),
('adventure_activities','Adventure Activities','أنشطة مغامرات','activities','hiking','activity',28),
('museums','Museums','متاحف','culture','museum','activity',29),
('art_galleries','Art Galleries','معارض فنية','culture','palette','activity',30),
('historical_attractions','Historical Attractions','معالم تاريخية','culture','account_balance','outdoor',31),
('cultural_centers','Cultural Centers','مراكز ثقافية','culture','theater_comedy','activity',32),
('lounges','Lounges','لاونج','social','weekend','food',33),
('social_clubs','Social Clubs','نوادي اجتماعية','social','groups','activity',34),
('group_activities','Group Activities','أنشطة جماعية','social','groups','activity',35);
INSERT INTO vibes(id,name_en,name_ar,icon,sort_order) VALUES
('chill_relax','Chill & Relax','هدوء واسترخاء','spa',0),
('friends_hangout','Friends Hangout','خروجة أصحاب','groups',1),
('romantic','Romantic','رومانسي','favorite',2),
('family','Family','عائلي','family_restroom',3),
('adventure','Adventure','مغامرة','hiking',4),
('fun_games','Fun & Games','مرح وألعاب','sports_esports',5),
('food_dining','Food & Dining','أكل ومطاعم','restaurant',6),
('coffee_conversations','Coffee & Conversations','قهوة ودردشة','coffee',7),
('outdoor_nature','Outdoor & Nature','طبيعة وهواء طلق','park',8),
('shopping','Shopping','تسوق','shopping_bag',9),
('movies','Movies','أفلام','movie',10),
('culture_exploring','Culture & Exploring','ثقافة واستكشاف','museum',11),
('sports_active','Sports & Active','رياضة ونشاط','fitness_center',12),
('study_work','Study & Work','مذاكرة وشغل','school',13),
('budget_friendly','Budget Friendly','اقتصادي','savings',14);
UPDATE places SET status='unverified' WHERE NOT is_active;
ALTER TABLE places ADD CONSTRAINT places_status_check CHECK(status IN ('active','temporarily_closed','permanently_closed','unverified'));
ALTER TABLE places ADD CONSTRAINT places_source_check CHECK(source IN ('manual','osm') AND (source <> 'osm' OR (source_type IN ('node','way','relation') AND source_id IS NOT NULL AND source_region IS NOT NULL)));
ALTER TABLE places ADD CONSTRAINT places_missing_check CHECK(missing_sync_count>=0);
CREATE INDEX idx_places_category ON places(category_id);
CREATE INDEX idx_places_active_coordinates ON places(latitude,longitude) WHERE is_active AND status='active';

ALTER TABLE place_categories ADD COLUMN updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT now();
ALTER TABLE vibes ADD COLUMN updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT now();
