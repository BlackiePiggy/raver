import { PrismaClient } from '@prisma/client';
import djAggregatorService from '../src/services/dj-aggregator.service';

const prisma = new PrismaClient();

async function syncAllDJs() {
  console.log('🔄 开始同步所有DJ信息...\n');

  const djs = await prisma.dJ.findMany({
    select: { id: true, name: true },
  });

  console.log(`找到 ${djs.length} 个DJ\n`);

  for (const dj of djs) {
    try {
      console.log(`🎵 同步: ${dj.name}...`);
      await djAggregatorService.syncDJ(dj.id);
      console.log(`✅ ${dj.name} 同步成功\n`);

      // Rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`❌ ${dj.name} 同步失败:`, (error as Error).message, '\n');
    }
  }

  console.log('🎉 所有DJ同步完成！');
}

syncAllDJs()
  .catch((e) => {
    console.error('❌ 同步错误:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });