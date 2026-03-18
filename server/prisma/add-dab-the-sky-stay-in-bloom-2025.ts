import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const SET_SLUG = 'dab-the-sky-live-stay-in-bloom-2025-full-set';
const VIDEO_ID = '5z4873lw2No';

const rawTracklist = [
  '0:00 - DAB THE SKY INTRO (In the End x Hero)',
  '1:40 - Said the Sky - Stay (Afinity Remix)',
  '2:32 - Said the Sky - Spider x Dabin - Holding On x Dabin - Stay with Me (Dab the Sky Edit)',
  '3:31 - Dabin - Stay with Me feat. Velvetears',
  '4:04 - Trippie Redd - Miss the Rage feat. Playboi Carti (Crankdat Remix)',
  '4:42 - RZRKT - Immortal vs How You Love Me x Exodia x Dust (CELO & SLICK EDIT)',
  '5:20 - Aespa - Drama (RayJhin Remix)',
  '6:02 - Viperactive, Strobez, Vel Nine - One Time',
  '6:42 - Knock2, Sophia Gripari - Hold My Hand (sportmode flip)',
  '7:52 - Stariah & Valkyr - Astral',
  '9:23 - Said the Sky, Taylor Acorn - Reminisce',
  '10:45 - Illenium, Said the Sky, Vera Blue - Other Side',
  '12:37 - Said the Sky, Dia Frampton - Love Let Me Go (Dia Frampton Live Vocal)',
  '14:17 - Bring me the Horizon - YOUtopia (Roy Knox Remix) [Unreleased]',
  '15:37 - Said the Sky, BOYS LIKE GIRLS - Hold My Breath (Mazare Remix)',
  '17:22 - Dabin, Blanke, Lospirit - Night Bloom',
  '18:58 - Dabin, Trella - Starbright (Chime Remix) [Dab the Sky Edit]',
  '20:51 - Moore Kismet - Overthinking Out Loud',
  '21:24 - Said the Sky, Terry Zhong, CVBZ - Glass House',
  '22:43 - Dabin, Mokita - Drown (Blanke Remix) vs Said the Sky, Parachute, Will Anderson - Emotion Sickness (Dab the Sky Edit)',
  '24:40 - Dabin, NURKO, Skylar Grey - I See You',
  '26:11 - Dabin, NURKO, Skylar Grey - I See You (Chenda Remix) [Unreleased]',
  '26:50 - Virtual Self - Ghost Voices (Tisoki Flip)',
  '27:41 - Dabin, Noelle Johnson - Remember x Said the Sky, We The Kings - It Was You (Dab the Sky Edit)',
  '28:33 - Said the Sky, We The Kings - It Was You (Ace Aura Remix)',
  "29:36 - Dabin - Won't Be the Same (Paper Skies Remix) [Unreleased]",
  '30:30 - Rl Grime, Reo Cragun - Lose My Mind (SLICK FLIP)',
  '31:40 - Knock2, Nghtmre - One Chance (Stoned Level Remix)',
  '32:43 - Dabin - Smoke Signals x ODEA - ID',
  '33:48 - ROSE, Bruno Mars - APT. (Dabin Remix)',
  '35:12 - Said the Sky, Kerli - Never Gone VIP',
  '36:15 - Said the Sky, Dabin, Linn - Superstar (Dab the Sky Edit)',
  '37:55 - Boombox Cartel & Frosttop - Feel It 2 feat. Transviolet',
  '39:06 - Isoxo, Knock2, RL Grime - Smack Talk vs Travis Scott - Fein vs Jiqui - Pop Rocks',
  '40:04 - Dabin, Stephanie Poetri - Not Enough',
  '41:32 - Dabin, Stephanie Poetri - Not Enough (Roy Knox Remix) [Unreleased]',
  '43:06 - Yogi, Pusha-T x Perry Wayne, CELO - Burial x Bad Boys x Step Up (CELO & SLICK EDIT)',
  '44:17 - ex:hail - Blade',
  '44:44 - Skrillex - ANDY',
  '45:24 - Slander, Bring me the Horizon, Blackbear - Wish I Could Forget (William Black Remix)',
  '46:46 - Dabin, Kai Wachi, Lospirit - Hollow',
  '48:51 - Dabin, Kai Wachi, Lospirit - Hollow (VNDETTA Remix)',
  '49:19 - Dabin, Lowell - Holding On',
  '50:11 - Dabin, Lowell - Holding On (Kompany Remix) vs. Viperactive - All Day',
  '51:04 - Madeon - All My Friends vs ODEA - ID',
  '51:44 - Illenium, Wooli, Grabbitz - You Were Right',
  '53:12 - Said the Sky, Good Problem - Till I Met You',
  "54:58 - Dabin, FrostTop, Tiffany Day - Summer's Gone",
  "57:05 - Dabin, FrostTop, Tiffany Day - Summer's Gone (Skybreak Remix) [Unreleased]",
  '57:32 - Dabin, NURKO, Skylar Grey - I See You (Hex Cougar Remix) [Unreleased]',
  '58:24 - Said the Sky, Olivver the Kid - Forgotten You (Live Edit)',
  '59:03 - Dabin, Conor Byrne - Rings & Roses (Slippy Remix) vs Kompany - Justice',
  '59:05 - DABIN ACCIDENTALLY PRESSES STOP LIKE AN IDIOT',
  '1:00:23 - Skrillex - MORJA KAIJU VIP',
  '1:01:01 - Dabin, Stephanie Poetri - Not Enough (SLICK & 808gong Remix) [Unreleased]',
  '1:01:40 - Said the Sky, William Black, SayWeCanFly - On My Own',
  '1:02:57 - Skrillex, BEAM - Mumbai Power vs Said the Sky, Kwesi - All I Got',
  '1:04:26 - Slander, Said the Sky, JT Roach - Potions (Tisoki Remix)',
  '1:05:04 - Slander, Said the Sky, JT Roach - Potions (Au5 Remix)',
  '1:06:20 - Porter Robinson - Language (Man Club Remix) vs Seven Lions, Slander, Dabin, Dylan Matthew - First Time',
  '1:08:36 - Dabin, RUNN- Alive vs Seven Lions, Illenium, Said the Sky, HALIENE - Rush Over Me',
  '1:10:54 - Dabin, RUNN - Alive (Mitis Remix)',
  '1:13:04 - Dabin, Trella - Worlds Away',
  '1:15:28 - Dabin, Trella - Worlds Away (Nikademis Remix vs Illenium, Said the Sky, Rock Mafia - Crazy Times (Dab the Sky Edit)',
  '1:16:45 - Said the Sky, Jessica Baio - How to Say Goodbye',
  '1:19:00 - Said the Sky, Olivver the Kid - We Know Who We Are vs Dabin, Trella - Starbright (Dab the Sky Edit)',
  '1:22:50 - Illenium, Dabin, Lights - Hearts on Fire vs Said the Sky, Illenium, Chelsea Cutler - Walk Me Home (Dab the Sky Edit)',
];

function parseTimeToSeconds(time: string): number {
  const parts = time.split(':').map((p) => Number(p.trim()));
  if (parts.some((p) => Number.isNaN(p))) {
    throw new Error(`Invalid time value: ${time}`);
  }
  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }
  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  throw new Error(`Unsupported time format: ${time}`);
}

function inferStatus(text: string): 'released' | 'id' | 'remix' | 'edit' {
  const t = text.toLowerCase();
  if (t.includes('[unreleased]') || /\bid\b/.test(t) || t.includes('accidentally presses stop')) {
    return 'id';
  }
  if (t.includes(' edit') || t.includes('(edit') || t.includes(' vs ') || t.includes(' x ')) {
    return 'edit';
  }
  if (t.includes('remix') || t.includes(' flip') || t.includes(' vip')) {
    return 'remix';
  }
  return 'released';
}

function parseTrackLine(line: string) {
  const match = line.match(/^(\d{1,2}:\d{2}(?::\d{2})?)\s*-\s*(.+)$/);
  if (!match) {
    throw new Error(`Cannot parse track line: ${line}`);
  }

  const time = parseTimeToSeconds(match[1]);
  const detail = match[2].trim();
  const splitIndex = detail.indexOf(' - ');

  const artist = splitIndex > -1 ? detail.slice(0, splitIndex).trim() : 'Unknown';
  const title = splitIndex > -1 ? detail.slice(splitIndex + 3).trim() : detail;

  return {
    startTime: time,
    artist,
    title,
    status: inferStatus(detail),
  };
}

async function run() {
  console.log('Creating/updating DAB THE SKY set...');

  const dj = await prisma.dJ.upsert({
    where: { slug: 'dab-the-sky' },
    update: {
      name: 'DAB THE SKY',
      isVerified: true,
    },
    create: {
      name: 'DAB THE SKY',
      slug: 'dab-the-sky',
      bio: 'Melodic bass duo project by Dabin and Said The Sky',
      country: 'United States',
      isVerified: true,
    },
  });

  const existingSet = await prisma.dJSet.findFirst({
    where: {
      OR: [{ slug: SET_SLUG }, { videoId: VIDEO_ID }],
    },
  });

  const baseSetData = {
    djId: dj.id,
    title: 'DAB THE SKY LIVE @ STAY IN BLOOM 2025 (FULL SET)',
    slug: SET_SLUG,
    description: 'Live set with full manual tracklist.',
    videoUrl:
      'https://www.youtube.com/watch?v=5z4873lw2No&list=RD5z4873lw2No&start_radio=1',
    platform: 'youtube',
    videoId: VIDEO_ID,
    eventName: 'Stay In Bloom 2025',
    venue: 'Live Stage',
    isVerified: true,
  } as const;

  const djSet = existingSet
    ? await prisma.dJSet.update({
        where: { id: existingSet.id },
        data: baseSetData,
      })
    : await prisma.dJSet.create({
        data: baseSetData,
      });

  const parsed = rawTracklist.map(parseTrackLine);

  await prisma.track.deleteMany({
    where: { setId: djSet.id },
  });

  await prisma.track.createMany({
    data: parsed.map((track, index) => ({
      setId: djSet.id,
      position: index + 1,
      startTime: track.startTime,
      endTime: parsed[index + 1]?.startTime,
      title: track.title,
      artist: track.artist,
      status: track.status,
    })),
  });

  console.log(`Set ID: ${djSet.id}`);
  console.log(`Tracks imported: ${parsed.length}`);
  console.log(`Player URL: http://localhost:3000/dj-sets/${djSet.id}`);
}

run()
  .catch((error) => {
    console.error('Failed:', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
