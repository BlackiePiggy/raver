import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function createSaidTheSkySet() {
  console.log('🎵 创建 Said the Sky DJ Set...\n');

  // 创建或查找 Said the Sky DJ
  let dj = await prisma.dJ.findFirst({
    where: { slug: 'said-the-sky' },
  });

  if (!dj) {
    dj = await prisma.dJ.create({
      data: {
        name: 'Said the Sky',
        slug: 'said-the-sky',
        bio: 'American DJ and producer known for melodic dubstep and future bass',
        country: 'United States',
        isVerified: true,
      },
    });
    console.log('✅ 创建DJ: Said the Sky');
  }

  // 创建DJ Set
  const djSet = await prisma.dJSet.create({
    data: {
      djId: dj.id,
      title: 'Said the Sky - VAC电音节 2024',
      slug: 'said-the-sky-vac-2024',
      description: 'VAC电音节Said the Sky现场全程录像',
      videoUrl: 'https://www.bilibili.com/video/BV1cJ4m1J7pa',
      platform: 'bilibili',
      videoId: 'BV1cJ4m1J7pa',
      venue: 'VAC电音节',
      eventName: 'VAC Festival 2024',
      isVerified: true,
    },
  });

  console.log('✅ 创建DJ Set:', djSet.title);
  console.log('Set ID:', djSet.id);
  console.log('\n📝 请提供完整歌单，然后运行添加tracks的脚本');
  console.log('\n🌐 访问链接:');
  console.log(`   http://localhost:3000/dj-sets/${djSet.id}`);
  console.log(`   http://localhost:3000/djs/${dj.id}/sets`);
}

createSaidTheSkySet()
  .catch((e) => {
    console.error('❌ 错误:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });