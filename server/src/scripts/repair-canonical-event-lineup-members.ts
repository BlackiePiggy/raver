import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const dryRun = process.env.CANONICAL_REPAIR_DRY_RUN === '1';

const LEGACY_SOURCE_TYPES = ['event_lineup_artists', 'event_timetable_slots', 'event_lineup_slots'] as const;

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[repair-canonical-event-lineup-members]', step, detail || {});
};

async function countAffectedEvents(): Promise<number> {
  const rows = await prisma.$queryRawUnsafe<Array<{ event_id: string }>>(`
    SELECT DISTINCT artist."event_id"
    FROM "event_artists" artist
    JOIN "event_artist_members" member
      ON member."event_artist_id" = artist."id"
    WHERE artist."source_type" IN (${PrismaJoinLegacySourceTypes()})
      AND member."dj_id" IS NOT NULL
    GROUP BY artist."event_id", artist."id", member."dj_id"
    HAVING COUNT(*) > 1
  `);
  return rows.length;
}

function PrismaJoinLegacySourceTypes(): string {
  return LEGACY_SOURCE_TYPES.map((value) => `'${value}'`).join(', ');
}

function canonicalMemberOrderExpression(): string {
  return `CASE
    WHEN member."member_order" <= -1000000 THEN ABS(member."member_order") - 1000000
    ELSE member."member_order"
  END`;
}

async function deleteDuplicateMembers(): Promise<number> {
  const rows = await prisma.$queryRawUnsafe<Array<{ id: string }>>(`
    WITH ranked AS (
      SELECT
        member."id",
        ROW_NUMBER() OVER (
          PARTITION BY member."event_artist_id", member."dj_id"
          ORDER BY member."member_order" ASC, member."created_at" ASC, member."id" ASC
        ) AS duplicate_rank
      FROM "event_artist_members" member
      JOIN "event_artists" artist
        ON artist."id" = member."event_artist_id"
      WHERE artist."source_type" IN (${PrismaJoinLegacySourceTypes()})
        AND member."dj_id" IS NOT NULL
    )
    SELECT "id"
    FROM ranked
    WHERE duplicate_rank > 1
  `);

  if (dryRun || rows.length === 0) {
    return rows.length;
  }

  const ids = rows.map((row) => row.id);
  const result = await prisma.eventArtistMember.deleteMany({
    where: {
      id: {
        in: ids,
      },
    },
  });
  return result.count;
}

async function renumberMembers(): Promise<number> {
  const rows = await prisma.$queryRawUnsafe<Array<{ id: string; next_order: bigint | number }>>(`
    WITH ordered AS (
      SELECT
        member."id",
        ROW_NUMBER() OVER (
          PARTITION BY member."event_artist_id"
          ORDER BY ${canonicalMemberOrderExpression()} ASC, member."created_at" ASC, member."id" ASC
        ) AS next_order
      FROM "event_artist_members" member
      JOIN "event_artists" artist
        ON artist."id" = member."event_artist_id"
      WHERE artist."source_type" IN (${PrismaJoinLegacySourceTypes()})
    )
    SELECT
      member."id",
      ordered.next_order
    FROM ordered
    JOIN "event_artist_members" member
      ON member."id" = ordered."id"
    WHERE member."member_order" <> ordered.next_order
  `);

  if (dryRun || rows.length === 0) {
    return rows.length;
  }

  await prisma.$executeRawUnsafe(`
    WITH ordered AS (
      SELECT
        member."id",
        ROW_NUMBER() OVER (
          PARTITION BY member."event_artist_id"
          ORDER BY ${canonicalMemberOrderExpression()} ASC, member."created_at" ASC, member."id" ASC
        ) AS next_order
      FROM "event_artist_members" member
      JOIN "event_artists" artist
        ON artist."id" = member."event_artist_id"
      WHERE artist."source_type" IN (${PrismaJoinLegacySourceTypes()})
    )
    UPDATE "event_artist_members" member
    SET "member_order" = -1000000 - ordered.next_order
    FROM ordered
    WHERE member."id" = ordered."id"
      AND member."member_order" <> ordered.next_order
  `);

  await prisma.$executeRawUnsafe(`
    WITH ordered AS (
      SELECT
        member."id",
        ROW_NUMBER() OVER (
          PARTITION BY member."event_artist_id"
          ORDER BY ${canonicalMemberOrderExpression()} ASC, member."created_at" ASC, member."id" ASC
        ) AS next_order
      FROM "event_artist_members" member
      JOIN "event_artists" artist
        ON artist."id" = member."event_artist_id"
      WHERE artist."source_type" IN (${PrismaJoinLegacySourceTypes()})
    )
    UPDATE "event_artist_members" member
    SET "member_order" = ordered.next_order
    FROM ordered
    WHERE member."id" = ordered."id"
      AND member."member_order" = -1000000 - ordered.next_order
  `);

  return rows.length;
}

async function main(): Promise<void> {
  logStep('scan start', { dryRun });
  const affectedEvents = await countAffectedEvents();
  logStep('scan done', { affectedEvents });

  const deletedDuplicates = await deleteDuplicateMembers();
  logStep(dryRun ? 'would delete duplicates' : 'deleted duplicates', { count: deletedDuplicates });

  const renumberedMembers = await renumberMembers();
  logStep(dryRun ? 'would renumber members' : 'renumbered members', { count: renumberedMembers });

  console.log('[repair-canonical-event-lineup-members] done', {
    dryRun,
    affectedEvents,
    deletedDuplicates,
    renumberedMembers,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[repair-canonical-event-lineup-members] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
