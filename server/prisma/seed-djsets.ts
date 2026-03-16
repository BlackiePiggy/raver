import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function seedDJSets() {
  console.log('🎵 Seeding DJ Sets...');

  // Find or create a DJ
  let dj = await prisma.dJ.findFirst({
    where: { slug: 'amelie-lens' },
  });

  if (!dj) {
    dj = await prisma.dJ.create({
      data: {
        name: 'Amelie Lens',
        slug: 'amelie-lens',
        bio: 'Belgian techno DJ and producer',
        country: 'Belgium',
        isVerified: true,
      },
    });
    console.log('✅ Created DJ: Amelie Lens');
  }

  // Create a DJ Set
  const djSet = await prisma.dJSet.create({
    data: {
      djId: dj.id,
      title: 'Amelie Lens - Boiler Room Berlin',
      slug: 'amelie-lens-boiler-room-berlin',
      description: 'Techno set from Boiler Room Berlin 2023',
      videoUrl: 'https://www.youtube.com/watch?v=example',
      platform: 'youtube',
      videoId: 'example',
      venue: 'Berghain',
      eventName: 'Boiler Room',
      isVerified: true,
    },
  });

  console.log('✅ Created DJ Set:', djSet.title);

  // Create tracks
  const tracks = [
    {
      setId: djSet.id,
      position: 1,
      startTime: 0,
      endTime: 300,
      title: 'Exhale',
      artist: 'Amelie Lens',
      status: 'released',
    },
    {
      setId: djSet.id,
      position: 2,
      startTime: 300,
      endTime: 600,
      title: 'In My Mind',
      artist: 'Amelie Lens',
      status: 'released',
    },
    {
      setId: djSet.id,
      position: 3,
      startTime: 600,
      endTime: 900,
      title: 'Unreleased ID',
      artist: 'Amelie Lens',
      status: 'id',
    },
    {
      setId: djSet.id,
      position: 4,
      startTime: 900,
      endTime: 1200,
      title: 'Feel It (Amelie Lens Remix)',
      artist: 'Various Artists',
      status: 'remix',
    },
  ];

  await prisma.track.createMany({
    data: tracks,
  });

  console.log(`✅ Created ${tracks.length} tracks`);

  // Create another DJ and set
  let dj2 = await prisma.dJ.findFirst({
    where: { slug: 'charlotte-de-witte' },
  });

  if (!dj2) {
    dj2 = await prisma.dJ.create({
      data: {
        name: 'Charlotte de Witte',
        slug: 'charlotte-de-witte',
        bio: 'Belgian DJ and record label owner',
        country: 'Belgium',
        isVerified: true,
      },
    });
    console.log('✅ Created DJ: Charlotte de Witte');
  }

  const djSet2 = await prisma.dJSet.create({
    data: {
      djId: dj2.id,
      title: 'Charlotte de Witte - Tomorrowland 2023',
      slug: 'charlotte-de-witte-tomorrowland-2023',
      description: 'Main stage performance at Tomorrowland',
      videoUrl: 'https://www.youtube.com/watch?v=example2',
      platform: 'youtube',
      videoId: 'example2',
      venue: 'Tomorrowland',
      eventName: 'Tomorrowland 2023',
      isVerified: true,
    },
  });

  console.log('✅ Created DJ Set:', djSet2.title);

  const tracks2 = [
    {
      setId: djSet2.id,
      position: 1,
      startTime: 0,
      endTime: 240,
      title: 'Selected',
      artist: 'Charlotte de Witte',
      status: 'released',
    },
    {
      setId: djSet2.id,
      position: 2,
      startTime: 240,
      endTime: 480,
      title: 'The Healer',
      artist: 'Charlotte de Witte',
      status: 'released',
    },
    {
      setId: djSet2.id,
      position: 3,
      startTime: 480,
      endTime: 720,
      title: 'ID - ID',
      artist: 'Unknown',
      status: 'id',
    },
  ];

  await prisma.track.createMany({
    data: tracks2,
  });

  console.log(`✅ Created ${tracks2.length} tracks`);

  console.log('\n🎉 DJ Sets seeding completed!');
}

seedDJSets()
  .catch((e) => {
    console.error('❌ Error seeding DJ sets:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });