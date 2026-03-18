import fs from 'fs';
import path from 'path';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const YEARS = [2022, 2023, 2024, 2025];

const slugify = (name: string): string =>
  name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');

async function uniqueSlug(name: string) {
  const base = slugify(name) || `dj-${Date.now()}`;
  let candidate = base;
  let seq = 1;
  while (true) {
    const exists = await prisma.dJ.findUnique({ where: { slug: candidate } });
    if (!exists || exists.name.toLowerCase() === name.toLowerCase()) {
      return candidate;
    }
    seq += 1;
    candidate = `${base}-${seq}`;
  }
}

async function main() {
  const names = new Set<string>();
  const root = path.join(__dirname, '..', '..', 'web', 'public', 'rankings', 'djmag');

  for (const year of YEARS) {
    const file = path.join(root, `${year}.txt`);
    const text = fs.readFileSync(file, 'utf8');
    text
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .forEach((line) => {
        const match = line.match(/^\d+\.\s+(.+)$/);
        if (!match) {
          return;
        }
        const name = match[1].trim();
        if (name.toLowerCase().startsWith('unknown dj')) {
          return;
        }
        names.add(name);
      });
  }

  const list = [...names];
  let created = 0;
  let exists = 0;

  for (const name of list) {
    const found = await prisma.dJ.findFirst({
      where: { name: { equals: name, mode: 'insensitive' } },
    });
    if (found) {
      exists += 1;
      continue;
    }

    const slug = await uniqueSlug(name);
    await prisma.dJ.create({
      data: {
        name,
        slug,
        isVerified: true,
      },
    });
    created += 1;
  }

  console.log(`DJ MAG unique names: ${list.length}`);
  console.log(`Created: ${created}, Exists: ${exists}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
