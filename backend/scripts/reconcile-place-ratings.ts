import { Prisma } from "@prisma/client";
import { prisma } from "../src/config/database.js";
import { validateDatabaseTargets } from "../src/config/deployment.js";

const args = process.argv.slice(2);
if (args.some((arg) => arg !== "--repair")) throw new Error("Usage: reconcile-place-ratings [--repair]");
const repair = args.includes("--repair");
if (repair) validateDatabaseTargets(process.env);

const counts = [
  "rating_sum", "rating_count", "written_review_count",
  "one_star_count", "two_star_count", "three_star_count", "four_star_count", "five_star_count",
];
const calculated = Prisma.sql`
  SELECT place_id, sum(rating)::integer AS rating_sum, count(*)::integer AS rating_count,
    count(review_text)::integer AS written_review_count,
    count(*) FILTER (WHERE rating = 1)::integer AS one_star_count,
    count(*) FILTER (WHERE rating = 2)::integer AS two_star_count,
    count(*) FILTER (WHERE rating = 3)::integer AS three_star_count,
    count(*) FILTER (WHERE rating = 4)::integer AS four_star_count,
    count(*) FILTER (WHERE rating = 5)::integer AS five_star_count
  FROM place_reviews WHERE moderation_status = 'visible' GROUP BY place_id`;
const drift = Prisma.sql`
  SELECT coalesce(actual.place_id, expected.place_id) AS place_id,
    ${Prisma.join(counts.map((field) => Prisma.raw(`coalesce(expected.${field}, 0) AS ${field}`)))}
  FROM place_rating_statistics actual FULL JOIN (${calculated}) expected USING (place_id)
  WHERE ${Prisma.join(counts.map((field) => Prisma.raw(
    `coalesce(actual.${field}, 0) <> coalesce(expected.${field}, 0)`)), " OR ")}`;

try {
  const result = await prisma.$transaction(async (tx) => {
    if (!repair) {
      const [row] = await tx.$queryRaw<{ drifted: number }[]>`SELECT count(*)::integer AS drifted FROM (${drift}) drift`;
      return { drifted: row!.drifted, repaired: 0 };
    }
    // Exclude writers while replacing the snapshot. Reads can continue.
    await tx.$executeRaw`SET LOCAL lock_timeout = '5s'`;
    await tx.$executeRaw`SET LOCAL statement_timeout = '60s'`;
    await tx.$executeRaw`LOCK TABLE place_reviews, place_rating_statistics IN SHARE ROW EXCLUSIVE MODE`;
    const repaired = await tx.$executeRaw`
      INSERT INTO place_rating_statistics (place_id, ${Prisma.raw(counts.join(", "))})
      ${drift}
      ON CONFLICT (place_id) DO UPDATE SET
        ${Prisma.join(counts.map((field) => Prisma.raw(`${field} = excluded.${field}`)))},
        updated_at = greatest(clock_timestamp()::timestamptz(3), place_rating_statistics.updated_at + interval '1 millisecond')`;
    return { drifted: repaired, repaired };
  }, { timeout: 75_000 });
  console.log(JSON.stringify(result));
  if (result.drifted && !repair) process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
