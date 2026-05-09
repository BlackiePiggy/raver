import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';

type AvatarManifest = {
  generatedAt: string;
  user: string[];
  group: string[];
};

const prisma = new PrismaClient();
const MANIFEST_FILE = path.join(__dirname, 'default-avatar-manifest.json');
const USER_COUNT = 24;
const GROUP_COUNT = 12;

function hashString(input: string): number {
  const normalized = input.toLowerCase();
  let hash = BigInt('1469598103934665603');
  const prime = BigInt('1099511628211');
  for (const char of normalized) {
    hash ^= BigInt(char.codePointAt(0) ?? 0);
    hash *= prime;
  }
  return Number(hash & BigInt(0xffffffff));
}

function localAvatarIndex(value: string | null | undefined, kind: 'user' | 'group'): number | null {
  if (!value) return null;
  const trimmed = value.trim();
  const pattern =
    kind === 'user'
      ? /^local-avatar:\/\/LocalUserAvatar(\d{2})$/i
      : /^local-avatar:\/\/LocalGroupAvatar(\d{2})$/i;
  const match = trimmed.match(pattern);
  if (!match) return null;
  const parsed = Number(match[1]);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function pickIndex(seed: string, count: number): number {
  return (hashString(seed) % count) + 1;
}

async function loadManifest(): Promise<AvatarManifest> {
  const raw = await fs.readFile(MANIFEST_FILE, 'utf-8');
  const parsed = JSON.parse(raw) as AvatarManifest;
  if (!Array.isArray(parsed.user) || parsed.user.length < USER_COUNT) {
    throw new Error(`Manifest user avatars missing. Need ${USER_COUNT}.`);
  }
  if (!Array.isArray(parsed.group) || parsed.group.length < GROUP_COUNT) {
    throw new Error(`Manifest group avatars missing. Need ${GROUP_COUNT}.`);
  }
  return parsed;
}

function userAvatarUrl(manifest: AvatarManifest, userId: string, current: string | null): string {
  const explicitIndex = localAvatarIndex(current, 'user');
  const index = explicitIndex ?? pickIndex(userId, USER_COUNT);
  return manifest.user[index - 1]!;
}

function groupAvatarUrl(manifest: AvatarManifest, groupId: string, current: string | null): string {
  const explicitIndex = localAvatarIndex(current, 'group');
  const index = explicitIndex ?? pickIndex(groupId, GROUP_COUNT);
  return manifest.group[index - 1]!;
}

function shouldRewriteAvatar(value: string | null | undefined): boolean {
  if (!value) return true;
  const trimmed = value.trim();
  if (!trimmed) return true;
  if (/^https?:\/\//i.test(trimmed)) return false;
  if (/^local-avatar:\/\//i.test(trimmed)) return true;
  return true;
}

async function main(): Promise<void> {
  const manifest = await loadManifest();

  const users = await prisma.user.findMany({
    select: {
      id: true,
      avatarUrl: true,
    },
  });

  let updatedUsers = 0;
  for (const user of users) {
    if (!shouldRewriteAvatar(user.avatarUrl)) continue;
    await prisma.user.update({
      where: { id: user.id },
      data: {
        avatarUrl: userAvatarUrl(manifest, user.id, user.avatarUrl),
      },
    });
    updatedUsers += 1;
  }

  const squads = await prisma.squad.findMany({
    select: {
      id: true,
      avatarUrl: true,
    },
  });

  let updatedSquads = 0;
  for (const squad of squads) {
    if (!shouldRewriteAvatar(squad.avatarUrl)) continue;
    await prisma.squad.update({
      where: { id: squad.id },
      data: {
        avatarUrl: groupAvatarUrl(manifest, squad.id, squad.avatarUrl),
      },
    });
    updatedSquads += 1;
  }

  console.log(JSON.stringify({
    manifestGeneratedAt: manifest.generatedAt,
    updatedUsers,
    updatedSquads,
  }, null, 2));
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
