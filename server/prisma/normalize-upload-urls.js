const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function run() {
  await prisma.$executeRawUnsafe(`
    UPDATE users
    SET avatar_url = substring(avatar_url from '/uploads/.*$')
    WHERE avatar_url LIKE 'http%/uploads/%'
  `);

  await prisma.$executeRawUnsafe(`
    UPDATE events
    SET cover_image_url = substring(cover_image_url from '/uploads/.*$')
    WHERE cover_image_url LIKE 'http%/uploads/%'
  `);

  await prisma.$executeRawUnsafe(`
    UPDATE events
    SET lineup_image_url = substring(lineup_image_url from '/uploads/.*$')
    WHERE lineup_image_url LIKE 'http%/uploads/%'
  `);

  await prisma.$executeRawUnsafe(`
    UPDATE dj_sets
    SET thumbnail_url = substring(thumbnail_url from '/uploads/.*$')
    WHERE thumbnail_url LIKE 'http%/uploads/%'
  `);

  await prisma.$executeRawUnsafe(`
    UPDATE djs
    SET avatar_url = substring(avatar_url from '/uploads/.*$')
    WHERE avatar_url LIKE 'http%/uploads/%'
  `);

  await prisma.$executeRawUnsafe(`
    UPDATE djs
    SET banner_url = substring(banner_url from '/uploads/.*$')
    WHERE banner_url LIKE 'http%/uploads/%'
  `);

  console.log('Normalized upload URLs to relative /uploads/... paths');
}

run()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
