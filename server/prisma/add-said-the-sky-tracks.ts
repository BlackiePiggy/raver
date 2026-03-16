import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Said the Sky - VAC电音节 2024 完整歌单
const tracklist = [
  { time: '0:13', title: 'We Know Who We Are (开场)', artist: 'Said The Sky', status: 'released' },
  { time: '1:15', title: 'We Know Who We Are', artist: 'Said The Sky', status: 'released' },
  { time: '2:33', title: 'Go On Then, Love', artist: 'Said The Sky', status: 'released' },
  { time: '3:33', title: 'Divination', artist: 'Juelz', status: 'released' },
  { time: '4:36', title: 'Unknown Track', artist: 'Unknown', status: 'id' },
  { time: '5:41', title: 'All I Got', artist: 'Said The Sky', status: 'released' },
  { time: '7:10', title: 'Never Gone', artist: 'Said The Sky', status: 'released' },
  { time: '7:50', title: 'Lift Me From The Ground', artist: 'San Holo', status: 'released' },
  { time: '8:44', title: 'Superstar', artist: 'Said The Sky', status: 'released' },
  { time: '9:32', title: "Where'd U Go vs Never Gone (Mashup)", artist: 'Said The Sky', status: 'edit' },
  { time: '11:49', title: 'Stay (Mashup)', artist: 'Said The Sky', status: 'edit' },
  { time: '13:05', title: 'Legacy', artist: 'Said The Sky', status: 'released' },
  { time: '15:26', title: 'Ocean Avenue', artist: 'Yellowcard (Said The Sky Remix)', status: 'remix' },
  { time: '17:18', title: 'Emotion Sickness', artist: 'Said The Sky', status: 'released' },
  { time: '20:18', title: 'Glass House', artist: 'Said The Sky, Terry Zhong, CVBZ', status: 'released' },
  { time: '22:07', title: 'Show & Tell', artist: 'Said The Sky, Claire Ridgely', status: 'released' },
  { time: '23:49', title: 'Light', artist: 'San Holo', status: 'released' },
  { time: '25:35', title: 'It Was You', artist: 'Said The Sky, We The Kings', status: 'released' },
  { time: '28:36', title: 'Potions + Potions (Stonebank Remix)', artist: 'SLANDER, Said The Sky, JT Roach', status: 'edit' },
  { time: '32:02', title: 'Rumble (San Holo Existential Remix)', artist: 'San Holo', status: 'remix' },
  { time: '33:19', title: 'Angels Landing (Midnight Kids Remix)', artist: 'Said The Sky', status: 'remix' },
  { time: '34:34', title: 'Love Drunk', artist: 'Boys Like Girls', status: 'released' },
  { time: '36:20', title: 'Atoms (Said The Sky Remix)', artist: 'Said The Sky feat. Jeremy Zucker', status: 'remix' },
  { time: '38:34', title: 'Fireflies (Said The Sky Remix)', artist: 'Owl City', status: 'remix' },
  { time: '40:47', title: 'Hero', artist: 'Said The Sky, Dabin, Olivver the Kid', status: 'released' },
  { time: '43:25', title: 'In The End vs On The Other Side', artist: 'Dabin, Said The Sky, Clara Mae', status: 'edit' },
  { time: '45:25', title: 'I Write Sins Not Tragedies', artist: 'Me As Me', status: 'released' },
  { time: '47:24', title: 'Bittersweet Melody (Nurko Remix)', artist: 'Said The Sky, FRND', status: 'remix' },
  { time: '48:57', title: 'Unknown Track', artist: 'Unknown', status: 'id' },
  { time: '49:51', title: 'Blood', artist: 'ILLENIUM, Foy Vance', status: 'released' },
  { time: '50:43', title: 'On My Own (REAPER Remix)', artist: 'Said The Sky, William Black, SayWeCanFly', status: 'remix' },
  { time: '52:38', title: 'Forgotten You', artist: 'Said The Sky, Olivver the Kid', status: 'released' },
  { time: '55:45', title: 'Walk Me Home (Blanke Remix)', artist: 'Said The Sky, ILLENIUM, Chelsea Cutler', status: 'remix' },
];

function parseTime(timeStr: string): number {
  const parts = timeStr.split(':').map(Number);
  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  } else if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  return 0;
}

async function addTracklist() {
  console.log('🎵 添加 Said the Sky - VAC电音节 2024 歌单...\n');

  // 查找Set
  const djSet = await prisma.dJSet.findFirst({
    where: { slug: 'said-the-sky-vac-2024' },
  });

  if (!djSet) {
    console.error('❌ 找不到DJ Set，请先运行 create-said-the-sky.ts');
    return;
  }

  console.log(`✅ 找到Set: ${djSet.title}`);
  console.log(`📝 准备添加 ${tracklist.length} 首歌曲\n`);

  // 删除现有tracks（如果有）
  await prisma.track.deleteMany({
    where: { setId: djSet.id },
  });

  // 添加所有tracks
  const tracks = tracklist.map((track, index) => {
    const startTime = parseTime(track.time);
    const endTime = index < tracklist.length - 1
      ? parseTime(tracklist[index + 1].time)
      : undefined;

    return {
      setId: djSet.id,
      position: index + 1,
      startTime,
      endTime,
      title: track.title,
      artist: track.artist,
      status: track.status as 'released' | 'id' | 'remix' | 'edit',
    };
  });

  await prisma.track.createMany({
    data: tracks,
  });

  console.log(`✅ 成功添加 ${tracks.length} 首歌曲！\n`);

  // 显示统计
  const stats = {
    released: tracks.filter(t => t.status === 'released').length,
    remix: tracks.filter(t => t.status === 'remix').length,
    edit: tracks.filter(t => t.status === 'edit').length,
    id: tracks.filter(t => t.status === 'id').length,
  };

  console.log('📊 歌曲统计:');
  console.log(`   🎵 已发行: ${stats.released}`);
  console.log(`   🎹 Remix: ${stats.remix}`);
  console.log(`   ✂️ Edit/Mashup: ${stats.edit}`);
  console.log(`   🆔 未知ID: ${stats.id}`);
  console.log('');

  console.log('🌐 访问链接:');
  console.log(`   http://localhost:3000/dj-sets/${djSet.id}`);
  console.log('');
  console.log('🎉 完成！现在可以观看完整的Said the Sky VAC电音节表演了！');
}

addTracklist()
  .catch((e) => {
    console.error('❌ 错误:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });