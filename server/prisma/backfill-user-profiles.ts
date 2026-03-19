import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const LOCAL_USER_AVATAR_POOL = 24;
const LOCAL_GROUP_AVATAR_POOL = 12;

const RAVER_PREFIXES = [
  'warehouse',
  'afterhours',
  'acid',
  'strobe',
  'bassline',
  'neon',
  'techno',
  'house',
  'groove',
  'vinyl',
  'midnight',
  'pulse',
  'detroit',
  'berlin',
  'ibiza',
  'shanghai',
];

const RAVER_SUFFIXES = [
  'rider',
  'dancer',
  'listener',
  'dreamer',
  'walker',
  'pilot',
  'signal',
  'echo',
  'beats',
  'flow',
  'freq',
  'floor',
  'wave',
  'head',
];

function localUserAvatarToken(seed: string): string {
  const index = (hashString(seed) % LOCAL_USER_AVATAR_POOL) + 1;
  const name = `LocalUserAvatar${String(index).padStart(2, '0')}`;
  return `local-avatar://${name}`;
}

function localGroupAvatarToken(seed: string): string {
  const index = (hashString(seed) % LOCAL_GROUP_AVATAR_POOL) + 1;
  const name = `LocalGroupAvatar${String(index).padStart(2, '0')}`;
  return `local-avatar://${name}`;
}

function isLocalAvatarToken(value?: string | null): boolean {
  if (!value) return false;
  return /^local-avatar:\/\/Local(User|Group)Avatar\d{2}$/i.test(value.trim());
}

function hashString(input: string): number {
  let hash = 0;
  for (const char of input) {
    hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  }
  return hash;
}

function normalizeUsername(raw: string): string {
  const normalized = raw
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
  return normalized || 'raver';
}

function isRandomLike(value?: string | null): boolean {
  if (!value) return true;
  const v = value.trim();
  if (!v) return true;

  const checks = [
    /^(user|test|guest|demo|random|temp|newuser|default|unknown|unnamed)[\W_]*\d*$/i,
    /^[a-f0-9]{8,}$/i,
    /^[0-9]{6,}$/,
    /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i,
    /^u_[a-z0-9]{4,}$/i,
  ];
  if (checks.some((re) => re.test(v))) return true;

  const digits = (v.match(/\d/g) || []).length;
  if (v.length >= 10 && digits / v.length > 0.45) return true;

  return false;
}

function displayNameFromUsername(username: string): string {
  return username
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
    .slice(0, 32) || 'Raver';
}

function buildRaverUsername(seed: string): string {
  const hash = hashString(seed);
  const prefix = RAVER_PREFIXES[hash % RAVER_PREFIXES.length];
  const suffix = RAVER_SUFFIXES[Math.floor(hash / RAVER_PREFIXES.length) % RAVER_SUFFIXES.length];
  const number = String(hash % 1000).padStart(3, '0');
  return `${prefix}_${suffix}_${number}`;
}

function ensureUniqueUsername(base: string, taken: Set<string>): string {
  let candidate = normalizeUsername(base).slice(0, 24);
  if (!taken.has(candidate)) {
    taken.add(candidate);
    return candidate;
  }

  let index = 1;
  while (index < 10_000) {
    const suffix = `_${index}`;
    const head = candidate.slice(0, Math.max(3, 24 - suffix.length));
    const next = `${head}${suffix}`;
    if (!taken.has(next)) {
      taken.add(next);
      return next;
    }
    index += 1;
  }

  const fallback = `${candidate.slice(0, 18)}_${Date.now().toString().slice(-5)}`;
  taken.add(fallback);
  return fallback;
}

async function main() {
  const apply = process.argv.includes('--apply');

  const users = await prisma.user.findMany({
    select: {
      id: true,
      username: true,
      displayName: true,
      avatarUrl: true,
    },
  });

  const takenUsernames = new Set(users.map((item) => item.username.toLowerCase()));
  const updates: Array<{
    id: string;
    username?: string;
    displayName?: string;
    avatarUrl?: string;
  }> = [];

  for (const user of users) {
    const patch: {
      id: string;
      username?: string;
      displayName?: string;
      avatarUrl?: string;
    } = { id: user.id };

    const expectedAvatar = localUserAvatarToken(user.id);
    if (!isLocalAvatarToken(user.avatarUrl) || user.avatarUrl !== expectedAvatar) {
      patch.avatarUrl = expectedAvatar;
    }

    const usernameLooksRandom = isRandomLike(user.username);
    const displayNameLooksRandom = isRandomLike(user.displayName);

    if (usernameLooksRandom) {
      takenUsernames.delete(user.username.toLowerCase());

      const preferredBase =
        !displayNameLooksRandom && user.displayName
          ? normalizeUsername(user.displayName)
          : buildRaverUsername(user.id);

      patch.username = ensureUniqueUsername(preferredBase, takenUsernames);
    }

    if (displayNameLooksRandom) {
      patch.displayName = displayNameFromUsername(patch.username ?? user.username);
    }

    if (patch.username || patch.displayName || patch.avatarUrl) {
      updates.push(patch);
    }
  }

  console.log(`Scanned users: ${users.length}`);
  console.log(`Users to update: ${updates.length}`);

  const squads = await prisma.squad.findMany({
    select: {
      id: true,
      avatarUrl: true,
    },
  });

  const squadUpdates = squads
    .map((squad) => {
      const expectedAvatar = localGroupAvatarToken(squad.id);
      if (!isLocalAvatarToken(squad.avatarUrl) || squad.avatarUrl !== expectedAvatar) {
        return { id: squad.id, avatarUrl: expectedAvatar };
      }
      return null;
    })
    .filter((item): item is { id: string; avatarUrl: string } => item !== null);

  console.log(`Squads to update: ${squadUpdates.length}`);

  if (!apply) {
    const preview = updates.slice(0, 20);
    for (const item of preview) {
      console.log(
        `[DRY-RUN] ${item.id} -> username=${item.username ?? '-'} displayName=${item.displayName ?? '-'} avatar=${
          item.avatarUrl ? 'set' : '-'
        }`
      );
    }
    if (updates.length > preview.length) {
      console.log(`[DRY-RUN] ...and ${updates.length - preview.length} more`);
    }
    console.log('Dry run only. Re-run with --apply to persist changes.');
    return;
  }

  let changed = 0;
  for (const item of updates) {
    await prisma.user.update({
      where: { id: item.id },
      data: {
        ...(item.username ? { username: item.username } : {}),
        ...(item.displayName ? { displayName: item.displayName } : {}),
        ...(item.avatarUrl ? { avatarUrl: item.avatarUrl } : {}),
      },
    });
    changed += 1;
  }

  let squadChanged = 0;
  for (const item of squadUpdates) {
    await prisma.squad.update({
      where: { id: item.id },
      data: { avatarUrl: item.avatarUrl },
    });
    squadChanged += 1;
  }

  console.log(`Done. Updated ${changed} users.`);
  console.log(`Done. Updated ${squadChanged} squads.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
