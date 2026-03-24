import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const username = process.env.DJ_CONTRIBUTOR_BACKFILL_USERNAME?.trim() || 'uploadtester';

  const user = await prisma.user.findUnique({
    where: { username },
    select: { id: true, username: true },
  });

  if (!user) {
    throw new Error(`User not found: ${username}`);
  }

  const djs = await prisma.dJ.findMany({
    select: { id: true },
  });

  if (djs.length === 0) {
    console.log('No DJ records found; nothing to backfill.');
    return;
  }

  const rows = djs.map((dj) => ({
    djId: dj.id,
    userId: user.id,
  }));

  const result = await prisma.dJContributor.createMany({
    data: rows,
    skipDuplicates: true,
  });

  console.log(
    `Backfill completed for @${user.username}: added ${result.count} contributor rows across ${djs.length} DJs.`
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
