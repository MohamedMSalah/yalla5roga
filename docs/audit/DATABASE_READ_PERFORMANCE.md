# PostgreSQL read performance — 2026-11-20

## Index inventory and decisions

| Tables | Read patterns and existing indexes |
| --- | --- |
| `outings`, `outing_voting_rounds` | Group lists filter by `group_id` and order by `scheduled_at DESC`. Upcoming and history classification does not add a server-side status predicate to that list. Reminder jobs use scheduled date windows and deadline ranges. Reused `idx_outings_group`, `idx_outings_scheduled`, `idx_outings_created_by`, creator/request uniqueness, `idx_outings_vote_ends_at`, and `idx_outings_voting_deadline` on `(status, vote_ends_at)`. The voting-round deadline index is `(status, ends_at)`. No current outing list filters by `outings.ends_at`. |
| `groups`, `group_members` | Membership checks and roster reads use the `(group_id, user_id)` primary key. A user’s group list can use `idx_group_members_user`. Group ownership uses `idx_groups_created_by` and the group primary key. |
| `group_invitations` | Reused the normalized phone/status index, user index, group index, invitation primary key, and SQL-only pending uniqueness on `(group_id, invited_phone)`. The inbox retrieves all statuses for the verified user plus unlinked pending matches for the verified phone. The roster retrieves all statuses for a group. |
| `chat_messages`, `chat_reads` | Reused `(outing_id, sent_at DESC, id DESC)` for chronological history and latest pages, the message primary key for cursor/ownership lookups, and `(outing_id, sender_id, client_message_id)` uniqueness for retries. Read receipts use `(outing_id, user_id)`. |
| `outing_votes`, `outing_vote_options`, `outing_voting_round_options` | The ballot primary key on `(outing_id, user_id, option_id, round_number)` preserves multi-place voting. Option/user indexes serve their respective lookups. Round candidates already use `(outing_id, round_number, option_id)`; the new ballot index gives current-round reads a matching leading prefix. |
| `outing_attendance`, `outing_arrivals` | Each uses an `(outing_id, user_id)` primary key for outing reads and user checks. Attendance uses `status`; the attendance read projects the roster and the current RSVP values. GPS arrival is a separate lookup. |
| `places`, `place_brands` | Reused `idx_places_lat_lng` and SQL-only `idx_places_active_coordinates` for viewport/radius prefilters. Existing indexes cover `(status, category_id)`, `category_id`, legacy `vibe`, and `(brand_id, status)`. Opening hours remain place details. Catalog status is distinct from opening hours. |
| `place_categories`, `vibes`, `place_vibes`, `place_images`, `place_hours`, `place_prices`, `place_status_changes` | Category and vibe IDs are primary keys. `place_vibes` has both key orders for forward/reverse filtering. Images use `(place_id, sort_order)`; hours use unique `(place_id, day)`; prices use `(place_id)`; status history uses `(place_id, created_at)`. `places.category_id` is the category foreign key. |
| `notifications`, `users` | Inbox history retains `(user_id, created_at DESC)`; notification event uniqueness and row ownership lookups also remain. Firebase UID is the user primary key. Normalized phone uses the existing unique phone index. |

The group outing and invitation-history sorting indexes were built as candidates. Both plans retained the existing group index plus a sort for 2,500 matching rows, with the same buffer counts, so both candidates were removed from the migration before delivery. Existing membership keys and indexes cover both lookup directions. No additional indexes were selected for invitation status, chat text, RSVP status, category/vibe junctions, coordinates, or identity lookups.

## Migrations

| Index | Keys in order | Workload |
| --- | --- | --- |
| `idx_outing_votes_round_user` | `outing_id, round_number, user_id` | Read the current round or a specific voter’s current ballot without traversing old rounds. |
| `idx_notifications_user_read_created` | `user_id, is_read, created_at` | Count unread inbox items and bound bulk read updates by creation time. The full index also supports parameterized Prisma predicates when PostgreSQL uses a generic plan. Revisit a smaller partial index if production usage and query plans justify it. |
| `idx_places_catalog_updated` | `status, is_active, updated_at DESC, id ASC` | Serve the default catalog order within the requested status and active flag, including timestamp cursor bounds. |

`20261120000000_index_backend_reads` builds the first two indexes atomically with a five-second lock acquisition timeout. That timeout bounds waiting for a lock. The builds hold write-conflicting locks through commit. `20261120000100_index_places_catalog_order` uses a single `CREATE INDEX CONCURRENTLY` statement outside a transaction. All three definitions are represented in Prisma. Existing migrations, constraints and SQL-only indexes are preserved.

Before deploying, rehearse the migration chain on a disposable Neon branch and check build time and write contention for the two transactional builds. If a concurrent build fails, verify `pg_index.indisvalid` and resolve any invalid index and failed Prisma migration record before retrying. PostgreSQL can leave an invalid index after an interrupted concurrent build. [PostgreSQL CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html)

## Query changes

- Catalog queries select and limit the place page before loading related data and keep the same final ordering. The list looks up the fallback image once per page row with an empty cover and uses it for both response fields. GeoJSON skips image lookup. Updated-time pagination adds an indexable timestamp bound while preserving the existing ID tie-break and full timestamp precision. The legacy vibe filter casts its parameter to the enum so the existing column index stays eligible.
- Ballot replacement counts matching submitted options and fetches only the caller’s saved votes inside the existing transaction. Voting state still returns the documented votes, tallies, and distinct voter count.
- The invitation inbox selects the response fields and relation names it uses. The verified-phone lookup and invitation acceptance rules are unchanged.

## Spatial and search evaluation

The catalog radius query uses a latitude/longitude bounding box followed by exact distance filtering and sorting. The GeoJSON endpoint emits `[longitude, latitude]` for MapLibre. A PostGIS GiST index could help broad or dense viewport and radius searches if plans show high candidate counts or heap work. Neon documents PostGIS support. The pinned Prisma 6 line can use spatial operations through raw SQL. A branch experiment can evaluate a spatial expression over existing coordinates, preserve the GeoJSON payload, and check distance and edge behavior against the current implementation. This change leaves extensions and coordinate storage unchanged. [Neon PostGIS](https://neon.com/docs/extensions/postgis) [Prisma ORM v6 spatial SQL](https://www.prisma.io/docs/orm/v6/prisma-client/using-raw-sql/safeql) [PostGIS index-aware operators](https://postgis.net/documentation/faq/spatial-indexes/)

The public search uses escaped `ILIKE '%term%'` across `name`, `name_ar`, `name_en`, `area` and `address`. The normalized-name B-tree serves normalization/equality workflows. Full-text search would change substring matching. Neon supports `pg_trgm`, which is suitable for a branch trial with representative Arabic and English terms. Compare selectivity, short patterns, index footprint, and write cost across all five OR branches before selecting indexes. [Neon pg_trgm](https://neon.com/docs/extensions/pg_trgm) [PostgreSQL trigram index support](https://www.postgresql.org/docs/current/pgtrgm.html)

## Before and after query plans

Local PostgreSQL 18.6 via PGlite 0.5.16. The fixture replayed the existing migrations, loaded synthetic data, then applied the final two migrations. The fixture contained 120,000 places, 150,000 notifications, 60,000 ballots, 50,000 chat messages, 40,000 invitations and 30,000 outings. The ballot test represents a deliberately large outing with 12 rounds. `VACUUM ANALYZE` ran on each side. Rows show the median of five warmed `EXPLAIN (ANALYZE, BUFFERS)` executions, starting after one warm-up. All reported shared blocks were hits. The catalog measurements isolate page selection, including the new timestamp bound on the deep page.

| Query | Before → after, ms | Shared hits | Plan and rows examined |
| --- | ---: | ---: | --- |
| Default catalog, first 51 | 114.064 → 0.096 | 2,678 → 5 | Sequential scan and sort over 120,000 rows → ordered index scan of 51. |
| Default catalog, deep cursor | 50.926 → 0.090 | 2,678 → 5 | Sequential scan and sort over 120,000 rows → bounded index scan of 51. |
| Unread notifications | 1.141 → 0.065 | 135 → 4 | Bitmap heap scan of 6,000 user rows, 60 matched → index-only scan of 60. |
| Current-round ballots | 8.289 → 3.737 | 741 → 753 | Sequential scan of 60,000 rows, 5,000 matched → bitmap index/heap scan of 5,000 matches. |
| Group outing list | 4.400 → 4.161 | 49 → 49 | Both use the existing bitmap group scan and sort 2,500 matches. |
| Roster invitation history | 3.283 → 3.197 | 42 → 42 | Both use the existing bitmap group scan and sort 2,500 matches. |
| Latest chat page | 0.064 → 0.065 | 5 → 5 | Both scan 41 rows through the existing chat history index. |
| Narrow viewport | 0.197 → 0.180 | 17 → 17 | Both use `idx_places_active_coordinates` and sort 35 matches. |
| Expired voting deadlines | 0.020 → 0.020 | 3 → 3 | Both use `idx_outings_voting_deadline` and return one match. |

These timings measure representative SQL on a local synthetic fixture. Neon execution time, production distributions, API latency and Flutter load times remain unmeasured.

## Swagger/OpenAPI verification

The isolated Express application served its Swagger UI and OpenAPI definition. Requests were selected by operation ID from that served document and checked against documented response codes. The local database replayed the full migration chain. The Firebase adapter returned controlled identities and phone records for the test accounts.

| Area | Result |
| --- | --- |
| Groups and memberships | Member’s group list, roster, pending roster entry and anonymous rejection passed. |
| Outings and voting | Group sort, attendance status, outsider denial, multi-place ballot replacement, per-caller ballot response, tallies and invalid option rejection passed. |
| Invitations | Declined linked history and verified-phone pending lookup passed. Pending invitations did not grant membership. |
| Chat history | Recent and older pages preserved order at equal timestamps. An outsider was rejected. |
| Places and Discover | Pagination across identical and microsecond-separated timestamps, direct and fallback covers, Arabic substring search, radius/distance sorting, GeoJSON coordinate order and branch lists passed. |
| Notifications | Equal-timestamp paging, unread count and cross-account cursor rejection passed. |

Prisma validation and TypeScript type checking passed. On a fresh local database, `prisma migrate deploy` applied all 23 migrations, `prisma migrate status` reported the database up to date, and PostgreSQL reported all three new indexes as valid and ready. The same Swagger scenarios passed on that schema. The schema and audit documentation were updated. Diagrams and the OpenAPI contract required no changes. Production Neon, real Firebase authentication, Socket.IO, and Flutter/device behavior were outside this verification.

## Remaining bottlenecks

- Profile wide map bounds, radius scans, and multilingual substring search on a representative Neon branch. The selective viewport plan already uses its spatial prefilter.
- Track catalog index size and ingestion throughput. Place synchronization updates `updated_at`, so the ordered index adds ingestion write work.
- Profile high-cardinality and deep chat, notification and outing history reads. The legacy chat history without a pagination request and the group outing list still return their documented complete lists. Any future default limit needs a contract change. Audit notification read/write ratios and deep tied-timestamp pages before changing the chronological index.

## Neon deployment

Prisma applied `20261120000000_index_backend_reads` and `20261120000100_index_places_catalog_order` to the verified application branch on November 20, 2026. Readback matched the migration checksums and confirmed all three indexes as valid and ready. The staged migration directory excluded `20261120000200_place_catalog_changes`. A checksummed snapshot of the three affected tables contained 11,617 places, 26 notifications and zero votes. The local PostgreSQL restore rehearsal replayed the existing migration chain, compared the restored rows, and executed both exact migration files. External parent keys were bypassed only during the local snapshot restore. Live verification used migration metadata and index definitions. Production query benchmarking was outside the deployment.
