# Place ratings and reviews verification

## Isolated Swagger checks

The verifier starts Swagger UI and serves the OpenAPI document, resolves operation paths and methods from that document, then calls the HTTP endpoints against disposable loopback PostgreSQL. It applies the workspace migration history to a fresh database, controls the Firebase verifier at the auth middleware boundary, and drops the database at completion.

Fifteen scenarios passed on disposable PostgreSQL, including four for Bayesian ranking.

- Empty global data, unrated fallback and searches without matches.
- A 4.0 global average and prior weight 20 produce about 4.047619 for the single five-star rating and 4.769231 for the 500-rating venue. The larger sample ranks first through Swagger. Low ratings, actual averages, counts and unrounded minimum filters are also checked.
- Rating-count and ID ties, complete cursor traversal, offset compatibility and consistent ordering on list, nearby, branch and GeoJSON reads.
- Prior changes, net-neutral rating changes, global changes outside the search, updates, hidden edits, moderation and deletions produce fresh results and reject stale cursors where applicable.

The existing review checks passed as well.

- Anonymous access, bounds, owner-only edits and basic text spam checks.
- Rating-only writes, repeated PUTs, fresh recommendation statistics and branch independence.
- Branch statistics in the catalog, saved-place and voting responses. Manual voting locations omit ratings.
- Concurrent writes by multiple authors and the same author.
- Stable cursor pagination after deletion of a page anchor, with minimal reviewer profiles.
- Report deduplication, authorization, moderation, restoration and report dismissal.
- Viewer-specific blocks and unblocking.
- Catalog import refresh and archival with retained review history.
- User deletion and coordinated account deletion with aggregate updates and report cascades.
- Drift detection and repair with a catalog change feed update.
- Per-account rating write limit.

The Node build and Prisma generation passed. Flutter verification covered static analysis. No app debug session was available for hot reload or device rendering checks.

## Neon release status

The configured production target was queried read-only. Its migration history had 31 applied migrations with no changed or failed entries. The ratings migration and a separate starting-location migration were pending at the time of the check. Automatic approval review rejected the required production backup because it would copy production rows to a local artifact. The ratings migration remains pending until the approved backup and restore rehearsal are available. All review fixtures were confined to the disposable local database.

Current Smart Meetup sessions expose setup and readiness. The shared rating widget and branch statistics contract can be used when that feature has a venue results screen.
