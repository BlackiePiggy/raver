import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const DJ_NAMES: string[] = [
  'Martin Garrix',
  'Tiësto',
  'Avicii',
  'David Guetta',
  'Marshmello',
  'Alesso',
  'ILLENIUM',
  'Armin van Buuren',
  'Skrillex',
  'Hardwell',
  'Afrojack',
  'Alan Walker',
  'Carl Cox',
  'Oliver Heldens',
  'Don Diablo',
  'Nicky Romero',
  'Steve Aoki',
  'Kygo',
  'Zedd',
  'Dillon Francis',
  'KSHMR',
  'R3HAB',
  'Reinier Zonneveld',
  'Jamie Jones',
  'Charlotte de Witte',
  'Amelie Lens',
  'Fisher',
  'Diplo',
  'Calvin Harris',
  'deadmau5',
  'Porter Robinson',
  'Madeon',
  'Seven Lions',
  'Nora En Pure',
  'Peggy Gou',
  'Anyma',
  'Vintage Culture',
  'Fred again..',
  'ODESZA',
  'Subtronics',
  'Excision',
  'RL Grime',
  'Gryffin',
  'NURKO',
  'Dabin',
  'Said The Sky',
  'Blanke',
  'Wooli',
  'Kompany',
  'Knock2',
  'ISOxo',
  'Tisoki',
  'Carta',
  'Chace',
  'RayRay',
  'Howie Lee',
  'Luminn',
];

const slugify = (name: string): string =>
  name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');

async function getUniqueSlug(baseName: string) {
  const base = slugify(baseName) || `dj-${Date.now()}`;
  let candidate = base;
  let seq = 1;

  while (true) {
    const exists = await prisma.dJ.findUnique({ where: { slug: candidate } });
    if (!exists || exists.name.toLowerCase() === baseName.toLowerCase()) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
}

async function main() {
  console.log(`Importing ${DJ_NAMES.length} DJs...`);
  const results: { name: string; action: 'created' | 'exists' }[] = [];

  for (const rawName of DJ_NAMES) {
    const name = rawName.trim();
    if (!name) {
      continue;
    }

    const existing = await prisma.dJ.findFirst({
      where: { name: { equals: name, mode: 'insensitive' } },
    });

    if (existing) {
      results.push({ name, action: 'exists' });
      continue;
    }

    const slug = await getUniqueSlug(name);
    await prisma.dJ.create({
      data: {
        name,
        slug,
        isVerified: true,
      },
    });
    results.push({ name, action: 'created' });
  }

  const created = results.filter((r) => r.action === 'created').length;
  const exists = results.filter((r) => r.action === 'exists').length;
  console.log(`Created: ${created}, Exists: ${exists}`);
  console.log(results);
}

main()
  .catch((error) => {
    console.error('Failed to import DJ list:', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
