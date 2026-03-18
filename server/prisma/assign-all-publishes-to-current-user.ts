import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const currentUser = await prisma.user.findFirst({
    orderBy: [
      { lastLoginAt: 'desc' },
      { updatedAt: 'desc' },
      { createdAt: 'desc' },
    ],
  });

  if (!currentUser) {
    throw new Error('No user found in database');
  }

  const organizerName = currentUser.displayName || currentUser.username;

  const [eventsUpdated, setsUpdated] = await Promise.all([
    prisma.event.updateMany({
      data: {
        organizerId: currentUser.id,
        organizerName,
      },
    }),
    prisma.dJSet.updateMany({
      data: {
        uploadedById: currentUser.id,
      },
    }),
  ]);

  console.log('Assigned all publishes to current user:');
  console.log(`- userId: ${currentUser.id}`);
  console.log(`- username: ${currentUser.username}`);
  console.log(`- events updated: ${eventsUpdated.count}`);
  console.log(`- dj sets updated: ${setsUpdated.count}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
