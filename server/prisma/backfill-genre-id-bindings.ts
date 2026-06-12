import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

type BackfillTarget = 'djs' | 'personality' | 'users' | 'all';

type GenreLite = {
  id: string;
  name: string;
  slug: string;
  path: string;
};

type GenreBindingCandidate = {
  genreId: string;
  label: string;
  path: string | null;
};

type LabelMatch = {
  input: string;
  normalized: string;
  genreId: string;
  genreName: string;
  genrePath: string;
  strategy: string;
};

type DJPlan = {
  djId: string;
  djName: string;
  labels: string[];
  matches: LabelMatch[];
  unmatched: string[];
  nextBindings: Array<{ genreId: string; displayName: string | null; sortOrder: number }>;
  skippedBecauseExisting: boolean;
};

type PersonalityPlan = {
  resultTypeId: string;
  code: string;
  title: string;
  labels: string[];
  matches: LabelMatch[];
  unmatched: string[];
  nextBindings: GenreBindingCandidate[];
  skippedBecauseExisting: boolean;
};

type UserPlan = {
  userId: string;
  beforeKeys: string[];
  nextKeys: string[];
  matches: LabelMatch[];
  unmatched: string[];
  changed: boolean;
};

type ReportPayload = {
  startedAt: string;
  finishedAt: string;
  apply: boolean;
  overwriteExisting: boolean;
  target: BackfillTarget;
  limit: number | null;
  summary: Record<string, unknown>;
  djs?: Record<string, unknown>;
  personality?: Record<string, unknown>;
  users?: Record<string, unknown>;
};

type GenreIndex = {
  byId: Map<string, GenreLite>;
  exactMap: Map<string, GenreLite>;
  looseMap: Map<string, GenreLite>;
  compactMap: Map<string, GenreLite>;
};

const argv = process.argv.slice(2);
const APPLY = argv.includes('--apply');
const OVERWRITE_EXISTING = argv.includes('--overwrite-existing');
const TARGET = (readArgValue('target') || 'all') as BackfillTarget;
const LIMIT = (() => {
  const raw = readArgValue('limit');
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
})();
const REPORT_PATH = readArgValue('report') || path.join(
  process.cwd(),
  'prisma',
  '.cache',
  `genre-bindings-backfill-${new Date().toISOString().replace(/[:.]/g, '-')}.json`
);

function readArgValue(name: string): string | null {
  const prefix = `--${name}=`;
  const matched = argv.find((item) => item.startsWith(prefix));
  return matched ? matched.slice(prefix.length).trim() : null;
}

const PRIMARY_SPLIT_SEPARATORS = new Set([',', '\n', '\r', '，', '、', ';', '；']);
const PARENS_OPEN = new Set(['(', '[', '{', '（', '【']);
const PARENS_CLOSE = new Set([')', ']', '}', '）', '】']);

// All keys MUST be in normalizeLooseKey form (lowercase, no parens/slashes/&/hyphens/apostrophes).
const CONSERVATIVE_GENRE_ALIASES = new Map<string, string[]>([
  ['house music', ['House']],
  ['big room', ['Big Room House']],
  ['big room bounce', ['Big Room House']],
  ['big room edm', ['Big Room House']],
  ['bigroom', ['Big Room House']],
  ['bigroom house', ['Big Room House']],
  ['classic house', ['Classic Chicago House']],
  ['funky house', ['Funky Tech House']],
  ['underground house', ['House']],
  ['minimal house', ['Microhouse']],
  ['latin house', ['Tribal Tech House']],
  ['commercial house', ['Big Room House']],
  ['dutch house', ['Big Room House']],
  ['mainstage', ['Big Room House']],
  ['mainstage edm', ['Big Room House']],
  ['mainstage house', ['Big Room House']],
  ['main stage edm', ['Big Room House']],
  ['vocal house', ['Soulful House']],
  ['retro house', ['Classic Chicago House']],
  ['hippie house', ['Lo-fi House']],
  ['folk house', ['Lo-fi House']],
  ['power house', ['Hard House']],
  ['speed house', ['Hard House']],
  ['summer house', ['Tropical House']],
  ['modern house', ['Progressive House']],
  ['traditional house', ['Chicago House']],
  ['mainstream house', ['Big Room House']],
  ['pure house', ['House']],
  ['upfront house', ['Big Room House']],
  ['maximal house', ['Big Room House']],
  ['bouncy house', ['Big Room House']],
  ['chunky house', ['Tech House']],
  ['groovy house', ['Tech House']],
  ['indie house', ['Lo-fi House']],
  ['driving house', ['Peak Time / Driving Techno']],
  ['psychedelic house', ['Deep House']],
  ['steam house', ['Progressive House']],
  ['emotional house', ['Deep House']],
  ['gospel house', ['Soulful House']],
  ['detroit house', ['Classic Chicago House']],
  ['deep tech house', ['Minimal Tech House']],
  ['minimal deep tech', ['Minimal Tech House']],
  ['melodic tech house', ['Progressive Tech House']],
  ['new york house', ["Jackin' House"]],
  ['dirty house', ["Jackin' House"]],
  ['euro house', ['Eurodance']],
  ['uplifting house', ['Soulful House']],
  ['melodic afro house', ['Afro House']],
  ['afro latin house', ['Afro House']],
  ['hardhouse', ['Hard House']],
  ['hip house', ['Hip House']],
  ['jacking house', ["Jackin' House"]],
  ['deep jackin house', ["Jackin' House"]],
  ['jazzy house', ['Jazz House']],
  ['disco house', ['Disco']],
  ['deep dub house', ['Dub House']],
  ['tribal house', ['Tribal Tech House']],
  ['vina house', ['House']],
  ['vinahouse', ['House']],
  ['melodic house', ['Melodic House']],
  ['melodic house and techno', ['Melodic House', 'Melodic Techno']],
  ['future house', ['Future House']],
  ['future bounce', ['Future House']],
  ['bass future house', ['Future House']],
  ['bass house', ['Bass House']],
  ['organic house', ['Organic House']],
  ['g house', ['G-House']],
  ['uk house', ['UK House']],
  ['peak time techno', ['Peak Time / Driving Techno']],
  ['peaktime driving techno', ['Peak Time / Driving Techno']],
  ['driving techno', ['Peak Time / Driving Techno']],
  ['peak time driving', ['Peak Time / Driving Techno']],
  ['techno peak time driving', ['Peak Time / Driving Techno']],
  ['techno peak time driving', ['Peak Time / Driving Techno']],
  ['techno peak time', ['Peak Time / Driving Techno']],
  ['techno raw deep hypnotic', ['Techno']],
  ['raw deep hypnotic techno', ['Techno']],
  ['atmospheric techno', ['Ambient Techno']],
  ['cinematic techno', ['Ambient Techno']],
  ['emotional techno', ['Ambient Techno']],
  ['dark techno', ['Minimal Techno']],
  ['underground techno', ['Techno']],
  ['berlin techno', ['Techno']],
  ['hypnotic techno', ['Minimal Techno']],
  ['deep hypnotic techno', ['Minimal Techno']],
  ['psychedelic techno', ['Minimal Techno']],
  ['raw techno', ['Schranz']],
  ['atomic techno', ['Techno']],
  ['hyper techno', ['Hard Techno']],
  ['hypertechno', ['Hard Techno']],
  ['uk techno', ['Hard Techno']],
  ['mainstage techno', ['Peak Time / Driving Techno']],
  ['neo techno', ['Techno']],
  ['neorave', ['Techno']],
  ['hard industrial techno', ['Industrial Techno']],
  ['industrial hard techno', ['Industrial Techno']],
  ['high tech minimal', ['Minimal Techno']],
  ['hardtechno', ['Hard Techno']],
  ['minimal', ['Minimal Techno']],
  ['deep tech', ['Deep Techno']],
  ['progressive techno', ['Progressive Techno']],
  ['trance main floor', ['Uplifting Trance']],
  ['trance raw deep hypnotic', ['Trance']],
  ['tech trance', ['Hard Trance']],
  ['melodic trance', ['Melodic Progressive Trance']],
  ['euphoric trance', ['Uplifting Trance']],
  ['uplifting', ['Uplifting Trance']],
  ['club progressive', ['Progressive Trance']],
  ['melodic goa trance', ['Goa Trance']],
  ['progressive psychedelic trance', ['Progressive Psytrance']],
  ['melodic psy trance', ['Progressive Psytrance']],
  ['hi tech psytrance', ['Full-on Psytrance']],
  ['goa psy trance', ['Goa Trance']],
  ['darkpsy', ['Dark Psytrance']],
  ['full on', ['Full-on Psytrance']],
  ['full on night', ['Full-on Psytrance']],
  ['full on psy trance', ['Full-on Psytrance']],
  ['fullon psytrance', ['Full-on Psytrance']],
  ['psybreaks', ['Psychedelic Breakbeat']],
  ['psy tech', ['Hard Techno']],
  ['powertrance', ['Hard Trance']],
  ['euro trance', ['Hard Trance']],
  ['eurotrance', ['Hard Trance']],
  ['nu trance', ['Trance']],
  ['neo trance', ['Trance']],
  ['nitzhonot', ['Goa Trance']],
  ['nu nrg', ['Hi-NRG']],
  ['underground trance', ['Trance']],
  ['trance pop', ['Uplifting Trance']],
  ['trance brasileiro', ['Trance']],
  ['psy trance', ['Psytrance']],
  ['psychedelic trance', ['Psytrance']],
  ['progressive psy trance', ['Progressive Psytrance']],
  ['hardtrance', ['Hard Trance']],
  ['future rave', ['Future Rave']],
  ['hard dance', ['Hard Dance']],
  ['uptempo', ['Hardcore']],
  ['uptempo hardcore', ['Hardcore']],
  ['extreme uptempo', ['Hardcore']],
  ['melodic uptempo hardcore', ['Hardcore']],
  ['rawstyle', ['Hardstyle']],
  ['raw hardstyle', ['Hardstyle']],
  ['extra raw', ['Hardstyle']],
  ['extra rawstyle', ['Hardstyle']],
  ['euphoric hardstyle', ['Hardstyle']],
  ['harder styles', ['Hardstyle']],
  ['rawphoric', ['Hardstyle']],
  ['reverse bass', ['Hardstyle']],
  ['melodic hardstyle', ['Hardstyle']],
  ['hardstyle bass', ['Hardstyle']],
  ['hardstyle classics', ['Hardstyle']],
  ['early hardstyle', ['Hardstyle']],
  ['psystyle', ['Hardstyle']],
  ['elektro jump hardstyle', ['Hardstyle']],
  ['uk hardcore', ['Hardcore']],
  ['early hardcore', ['Hardcore']],
  ['90s hardcore', ['Hardcore']],
  ['oldskool hardcore', ['Hardcore']],
  ['melodic hardcore', ['Hardcore']],
  ['hardcore techno', ['Hardcore']],
  ['sickcore', ['Hardcore']],
  ['texcore', ['Hardcore']],
  ['krach', ['Hardcore']],
  ['hardbass', ['Gabber']],
  ['nu gabber', ['Gabber']],
  ['gabba', ['Gabber']],
  ['hardtek', ['Frenchcore']],
  ['tekno', ['Hardcore']],
  ['jumpstyle', ['Hardcore']],
  ['terror', ['Terrorcore']],
  ['hard bounce', ['Hardcore']],
  ['hard psy', ['Psytrance']],
  ['atmospheric hard dance', ['Hard Techno']],
  ['jungle hardcore', ['Jungle']],
  ['neo rave', ['Neo Rave']],
  ['drum and bass', ['Drum and Bass']],
  ['liquid drum and bass', ['Liquid Drum and Bass']],
  ['melodic drum and bass', ['Liquid Drum and Bass']],
  ['rolling drum and bass', ['Drum and Bass']],
  ['soulful drum and bass', ['Drum and Bass']],
  ['jump up drum and bass', ['Jump Up']],
  ['dancefloor drum and bass', ['Party Drum and Bass']],
  ['halftime drum and bass', ['Drum and Bass']],
  ['rollers drum and bass', ['Drum and Bass']],
  ['neuro drum and bass', ['Neurofunk']],
  ['intelligent drum and bass', ['Atmospheric Drum and Bass']],
  ['liquid dnb', ['Liquid Drum and Bass']],
  ['drumstep', ['Drum and Bass']],
  ['funk influenced drum and bass', ['Liquid Funk']],
  ['jazz influenced drum and bass', ['Jazzstep']],
  ['jungle techno', ['Jungle']],
  ['trap', ['Trap (EDM)']],
  ['hybrid trap', ['Trap (EDM)']],
  ['hard trap', ['Trap (EDM)']],
  ['melodic trap', ['Melodic Dubstep']],
  ['festival trap', ['Trap (EDM)']],
  ['folk trap', ['Trap (EDM)']],
  ['raw trap', ['Trap (EDM)']],
  ['trap house', ['Trap (EDM)']],
  ['trapengue', ['Trap (EDM)']],
  ['heaven trap', ['Melodic Dubstep']],
  ['emotional bass', ['Melodic Dubstep']],
  ['dark melodic bass', ['Melodic Dubstep']],
  ['heavy bass', ['Dubstep']],
  ['heavy bass music', ['Dubstep']],
  ['dark bass', ['Dark Dubstep']],
  ['dark bass music', ['UK Dubstep']],
  ['experimental bass', ['UK bass']],
  ['experimental bass music', ['UK bass']],
  ['deathstep', ['Brostep']],
  ['metalstep', ['Brostep']],
  ['metal dubstep', ['Brostep']],
  ['tearout', ['Brostep']],
  ['tearout dubstep', ['Brostep']],
  ['crunkstep', ['Brostep']],
  ['hard bass dubstep', ['Brostep']],
  ['halftime', ['Halftime Dubstep']],
  ['bassline riddim', ['Riddim']],
  ['future riddim', ['Riddim']],
  ['riddim dubstep', ['Riddim']],
  ['post dubstep', ['UK Dubstep']],
  ['experimental dubstep', ['UK Dubstep']],
  ['wobble bass', ['Dubstep']],
  ['bass', ['UK bass']],
  ['deep bass', ['Deep Dubstep']],
  ['vocal bass', ['Future bass']],
  ['global bass', ['UK bass']],
  ['leftfield bass', ['Leftfield']],
  ['funky bass', ['Tech Funk']],
  ['booty bass', ['Miami Bass']],
  ['bubblegum bass', ['Color Bass']],
  ['140 bass music', ['UK bass']],
  ['140', ['UK bass']],
  ['melodic bass', ['Melodic Bass']],
  ['edm', ['Trap (EDM)']],
  ['electronic dance music', ['House']],
  ['breaks', ['Breakbeat']],
  ['rave', ['Breakbeat hardcore']],
  ['90s rave', ['Breakbeat hardcore']],
  ['old school rave', ['Breakbeat hardcore']],
  ['oldschool rave', ['Breakbeat hardcore']],
  ['acid rave', ['Acid Breaks']],
  ['old school electronic', ['Breakbeat']],
  ['oldschool electronic', ['Breakbeat']],
  ['90s electronica', ['Breakbeat']],
  ['bounce', ['Big Beat']],
  ['melbourne bounce', ['Big Room House']],
  ['korean bounce', ['Big Room House']],
  ['korea bounce', ['Big Room House']],
  ['minimal bounce', ['Microhouse']],
  ['nu breaks', ['Nu skool breaks']],
  ['electro breakbeat', ['Acid Breaks']],
  ['dark disco', ['Electro-disco']],
  ['italodance', ['Italo disco']],
  ['italo house', ['Italo disco']],
  ['french touch', ['French House']],
  ['funk house', ['Hip House']],
  ['funk infused house', ['Hip House']],
  ['funk influenced electronic', ['Electrofunk']],
  ['electronic funk', ['Electrofunk']],
  ['electro funk', ['Electrofunk']],
  ['soul electronic', ['Funk and Soul Fusion']],
  ['disco funk', ['Funk and Soul Fusion']],
  ['disco influenced dance', ['Nu-disco']],
  ['disco influenced house', ['Nu-disco']],
  ['disco infused house', ['Nu-disco']],
  ['disco pop', ['Nu-disco']],
  ['edit disco', ['Nu-disco']],
  ['old skool disco', ['Disco']],
  ['boogie funk', ['Boogie']],
  ['slo mo boogie', ['Boogie']],
  ['electro trash', ['Electroclash']],
  ['tecktonik', ['Electroclash']],
  ['italian euro dance', ['Eurodance']],
  ['belgian dance', ['Eurodance']],
  ['euro dance', ['Eurodance']],
  ['eurodisco', ['Euro disco']],
  ['nu disco', ['Nu-disco']],
  ['acid', ['Acid House']],
  ['new rave', ['Indie Electronic']],
  ['nu rave', ['Indie Electronic']],
  ['dark edm', ['Darkwave']],
  ['commercial dance', ['Dance-pop']],
  ['electro rock', ['Electronic Rock']],
  ['experimental electronic', ['Experimental']],
  ['experimental electronic music', ['Experimental']],
  ['experimental electronica', ['Experimental']],
  ['electronica', ['IDM (Intelligent Dance Music)']],
  ['idm', ['IDM (Intelligent Dance Music)']],
  ['psychedelic electronic', ['Experimental']],
  ['melodic electronic', ['Experimental']],
  ['futuristic electronic', ['Experimental']],
  ['experimental techno', ['Experimental']],
  ['avant garde electronic', ['Experimental']],
  ['ambient gabber', ['Experimental']],
  ['ambient electronic', ['Ambient']],
  ['atmospheric electronica', ['Ambient']],
  ['ambient electronica', ['Ambient']],
  ['chill electronic', ['Chill-out']],
  ['chill edm', ['Chill-out']],
  ['chill out', ['Chill-out']],
  ['chillout', ['Chill-out']],
  ['chill trap', ['Chillstep']],
  ['chillhop', ['Lo-fi Hip Hop']],
  ['lo fi electronic', ['Lo-fi House']],
  ['lofi electronic', ['Lo-fi House']],
  ['lo fi', ['Lo-fi House']],
  ['leftfield electronic', ['Leftfield']],
  ['noise', ['Noise & Distortion']],
  ['noise music', ['Noise & Distortion']],
  ['noise influenced electronic', ['Noise & Distortion']],
  ['noise influenced techno', ['Industrial Techno']],
  ['industrial', ['Industrial and Post-Industrial']],
  ['industrial electronic', ['EBM']],
  ['industrial bass', ['Industrial and Post-Industrial']],
  ['isolationist drone', ['Isolationism']],
  ['drone', ['Drone Ambient']],
  ['alternative electronica', ['Indie Electronic']],
  ['jazz electronica', ['Nu-jazz']],
  ['cinematic electronic', ['Cinematic']],
  ['minimal electronic', ['Minimal Techno']],
  ['progressive', ['Progressive House']],
  ['progressive electronic', ['Progressive House']],
  ['progressive edm', ['Big Room House']],
  ['progressive indie edm', ['Progressive House']],
  ['melodic progressive house', ['Progressive House']],
  ['alternative dance', ['Indie Electronic']],
  ['indie electro', ['Indie Electronic']],
  ['indietronica', ['Indie Electronic']],
  ['folktronica', ['Indie Electronic']],
  ['french indie pop', ['Indie Electronic']],
  ['electronic pop', ['Synth-pop']],
  ['pop dance', ['Dance-pop']],
  ['pop edm', ['Dance-pop']],
  ['edm pop', ['Dance-pop']],
  ['pop infused edm', ['Dance-pop']],
  ['poptronica', ['Synth-pop']],
  ['electropunk', ['Dance-punk']],
  ['electronicore', ['Electronic Rock']],
  ['post techno punk', ['Electronic Rock']],
  ['psychedelic', ['Psychedelic Goa']],
  ['psychedelic ambient', ['Psybient']],
  ['dance pop', ['Dance-pop']],
  ['dark wave', ['Darkwave']],
  ['synth pop', ['Synth-pop']],
  ['synthpop', ['Synth-pop']],
  ['techfunk', ['Tech Funk']],
  ['trip hop', ['Trip hop']],
  ['balearic', ['Balearic Beat']],
  ['glitch hop', ['Glitch Hop']],
  ['glitch hip hop', ['Glitch Hop']],
  ['hard groove', ['Hardgroove']],
  ['hard wave', ['Hardwave']],
  ['melodic', ['Melodic Techno']],
  ['indie dance', ['Indie Dance']],
  ['baile funk', ['Funk Carioca']],
  ['brazilian funk', ['Funk Carioca']],
  ['brazilian electronic', ['Funk Carioca']],
  ['favela bass', ['Funk Carioca']],
  ['baile', ['Funk Carioca']],
  ['afro electronic', ['Afro House']],
  ['afro tech', ['Afro House']],
  ['afrotech', ['Afro House']],
  ['afro', ['Afro House']],
  ['afro house', ['Afro House']],
  ['afrohouse', ['Afro House']],
  ['afro rhythm', ['Afro House']],
  ['afro latin', ['Latin Club']],
  ['latin electronic', ['Latin Club']],
  ['latin urban', ['Reggaeton']],
  ['latin', ['Latin Club']],
  ['latin tech', ['Latin Club']],
  ['latin crossover house', ['Latin Club']],
  ['latin edm', ['Latin Club']],
  ['latin gabber', ['Hardcore']],
  ['latin urbano', ['Reggaeton']],
  ['latin infused grooves', ['Latin Club']],
  ['perreo', ['Neoperreo']],
  ['perreo bass', ['Neoperreo']],
  ['perreo sexotico', ['Neoperreo']],
  ['perreo millennial', ['Reggaeton']],
  ['reggaeton mexicano', ['Reggaeton']],
  ['guaracha', ['Latin Club']],
  ['acid guaracha', ['Latin Club']],
  ['batida', ['Kuduro']],
  ['bubbling', ['Latin Club']],
  ['tropical electronic', ['Moombahton']],
  ['tropical bass', ['Moombahton']],
  ['screwmbia', ['Global Club']],
  ['algerian dance music', ['Global Club']],
  ['world electronic', ['Global Club']],
  ['world ethnic electronic', ['Global Club']],
  ['worldbeat', ['Global Club']],
  ['balkan electronic', ['Global Club']],
  ['chinese style electronic', ['Global Club']],
  ['bollywood remix', ['Global Club']],
  ['urban', ['Latin Club']],
  ['urban dance', ['Latin Club']],
  ['future afro', ['Afro House']],
  ['dub', ['Ambient Dub']],
  ['deep dub', ['Dub House']],
  ['uk garage bassline', ['UK Garage']],
  ['garage', ['UK Garage']],
  ['2 step', ['2-step Garage']],
  ['3 step', ['UK Garage']],
  ['3step', ['UK Garage']],
  ['uk beats', ['UK Garage']],
  ['underground electronic', ['House']],
  ['underground electronic music', ['House']],
  ['dark electronic', ['Dark Ambient']],
  ['drift', ['Drift Phonk']],
  ['vocal edm', ['Dance-pop']],
  ['vocal driven electronica', ['Synth-pop']],
  ['emotional dance pop', ['Dance-pop']],
  ['emotional edm', ['Dance-pop']],
  ['emotional pop', ['Synth-pop']],
  ['emotional pop edm', ['Dance-pop']],
  ['pop electronic', ['Synth-pop']],
  ['dark pop', ['Darkwave']],
  ['cyber electronic', ['Synth-pop']],
  ['weird house', ['Lo-fi House']],
  ['weirdo house', ['Lo-fi House']],
  ['retro tech', ['Detroit Techno']],
  ['club music', ['House']],
  ['club', ['House']],
  ['dance', ['Dance-pop']],
  ['dance remix', ['Dance-pop']],
  ['tech', ['Tech House']],
  ['tek tribal', ['Tribal Tech House']],
  ['tribal electronic', ['Tribal Tech House']],
  ['tribal techno', ['Tribal Tech House']],
  ['tribal textured house', ['Tribal Tech House']],
  ['tribe', ['Tribal Tech House']],
  ['mashup', ['House']],
  ['beat scene', ['IDM (Intelligent Dance Music)']],
  ['freestyle', ['Electro']],
  ['nu wave', ['New Wave']],
  ['country edm', ['Dance-pop']],
  ['hypnotic house', ['Minimal Techno']],
  ['full on night', ['Full-on Psytrance']],
  ['future boogie', ['Future Funk']],
  ['funk dance', ['Electrofunk']],
  ['funky', ['Funky Tech House']],
  ['hard edm', ['Big Room House']],
  ['pop edm', ['Dance-pop']],
  ['bounce and bass', ['Big Room House']],
  ['electro acoustic', ['Electronica']],
  ['electro soul', ['Electrofunk']],
  ['festival edm', ['Big Room House']],
  ['funk electronic', ['Electrofunk']],
  ['hip hop influenced electronic', ['Hip House']],
  ['house lak', ['House']],
  ['hydro house', ['House']],
  ['modern cumbia', ['Global Club']],
  ['uk bass music', ['UK Bass']],
  ['u k bass music', ['UK Bass']],
]);

const NON_ELECTRONIC_EXCLUSIONS = new Set([
  'hip hop', 'funk', 'r and b', 'dancehall', 'reggae', 'soul',
  'afrobeats', 'afrobeat', 'jazz', 'pop', 'punk', 'indie pop', 'samba',
  'salsa', 'cumbia', 'pop rap', 'alternative', 'indie', 'korean hip hop',
  'nu soul', 'contemporary r and b', 'latin alternative rock', 'hip hop rap',
  'hip hop dance', 'soulful pop', 'alternative pop', 'drill',
  '70s funk', 'k pop electronic remix', 'k pop remix', 'dream pop',
  'emo rock', 'french indie pop', 'dark pop', 'emotional pop',
  'worldbeat', 'reggaeton mexicano', 'latin urbano', 'perreo',
  'latin urban', 'urban', 'urban dance', '70 s funk',
]);

const normalizeText = (value: unknown): string =>
  String(value || '')
    .trim()
    .replace(/\s+/g, ' ');

const normalizeFolded = (value: string): string =>
  value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

const normalizeLooseKey = (value: string): string =>
  normalizeFolded(value)
    .replace(/&/g, ' and ')
    .replace(/[_/]+/g, ' ')
    .replace(/[-\u2010-\u2015\u2212]+/g, ' ')
    .replace(/[()[\]{}''""'".:;!?+*#@`~|\\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeCompactKey = (value: string): string =>
  normalizeLooseKey(value).replace(/\s+/g, '');

const splitTopLevel = (value: string, separators: Set<string>): string[] => {
  const result: string[] = [];
  let depth = 0;
  let current = '';

  for (const char of value) {
    if (PARENS_OPEN.has(char)) {
      depth += 1;
      current += char;
      continue;
    }

    if (PARENS_CLOSE.has(char)) {
      depth = Math.max(0, depth - 1);
      current += char;
      continue;
    }

    if (depth === 0 && separators.has(char)) {
      const normalized = normalizeText(current);
      if (normalized) result.push(normalized);
      current = '';
      continue;
    }

    current += char;
  }

  const tail = normalizeText(current);
  if (tail) result.push(tail);
  return result;
};

const splitGenreLabels = (values: unknown): string[] => {
  const source = Array.isArray(values) ? values : [values];
  const result: string[] = [];
  const seen = new Set<string>();

  for (const rawValue of source) {
    const text = String(rawValue || '');
    const parts = splitTopLevel(text, PRIMARY_SPLIT_SEPARATORS);

    for (const part of parts) {
      const key = normalizeLooseKey(part);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      result.push(part);
    }
  }

  return result;
};

type MatchCandidate = {
  label: string;
  source: 'original' | 'alias' | 'derived';
};

const buildMatchCandidates = (label: string): MatchCandidate[] => {
  const normalizedInput = normalizeText(label);
  const normalizedKey = normalizeLooseKey(normalizedInput);
  const candidates: MatchCandidate[] = [];
  const seen = new Set<string>();

  const remember = (candidateLabel: string, source: MatchCandidate['source']) => {
    const normalizedCandidate = normalizeText(candidateLabel);
    const candidateKey = normalizeLooseKey(normalizedCandidate);
    if (!candidateKey || seen.has(candidateKey)) return;
    seen.add(candidateKey);
    candidates.push({ label: normalizedCandidate, source });
  };

  remember(normalizedInput, 'original');

  for (const alias of CONSERVATIVE_GENRE_ALIASES.get(normalizedKey) ?? []) {
    remember(alias, 'alias');
  }

  const parentheticalMatch = normalizedInput.match(/^(.+?)\s*[\(（]\s*(.+?)\s*[\)）]\s*$/);
  if (parentheticalMatch) {
    const prefix = normalizeText(parentheticalMatch[1]);
    const inside = normalizeText(parentheticalMatch[2]);

    if (inside) {
      remember(inside, 'derived');
      if (prefix) {
        remember(`${inside} ${prefix}`, 'derived');
        remember(`${prefix} ${inside}`, 'derived');
      }
    }
  }

  return candidates;
};

const matchGenreLabelWithCandidates = (label: string, index: GenreIndex): LabelMatch | null => {
  const normalizedInput = normalizeText(label);
  const normalizedLoose = normalizeLooseKey(normalizedInput);

  for (const candidate of buildMatchCandidates(label)) {
    const matched = matchGenreLabel(candidate.label, index);
    if (!matched) continue;
    return {
      ...matched,
      input: normalizedInput,
      normalized: normalizedLoose,
      strategy: candidate.source === 'original'
        ? matched.strategy
        : `${candidate.source}_${matched.strategy}`,
    };
  }

  return null;
};

type LabelResolution = {
  matches: LabelMatch[];
  unmatched: string[];
};

const resolveDJLabel = (label: string, index: GenreIndex): LabelResolution => {
  if (NON_ELECTRONIC_EXCLUSIONS.has(normalizeLooseKey(normalizeText(label)))) {
    return { matches: [], unmatched: [] };
  }

  const directMatch = matchGenreLabelWithCandidates(label, index);
  if (directMatch) {
    return { matches: [directMatch], unmatched: [] };
  }

  const slashParts = splitTopLevel(label, new Set(['/']));
  if (slashParts.length <= 1) {
    return { matches: [], unmatched: [label] };
  }

  const matches: LabelMatch[] = [];
  const unmatched: string[] = [];

  for (const part of slashParts) {
    const matched = matchGenreLabelWithCandidates(part, index);
    if (matched) {
      matches.push(matched);
    } else {
      unmatched.push(part);
    }
  }

  if (matches.length == 0) {
    return { matches: [], unmatched: [label] };
  }

  return { matches, unmatched };
};

const buildGenreIndex = (genres: GenreLite[]): GenreIndex => {
  const byId = new Map<string, GenreLite>();
  const exactMap = new Map<string, GenreLite>();
  const looseMap = new Map<string, GenreLite>();
  const compactMap = new Map<string, GenreLite>();

  const remember = (map: Map<string, GenreLite>, key: string, genre: GenreLite) => {
    if (!key || map.has(key)) return;
    map.set(key, genre);
  };

  for (const genre of genres) {
    byId.set(genre.id, genre);
    const keys = [genre.id, genre.slug, genre.path, genre.name]
      .map((item) => normalizeText(item))
      .filter(Boolean);

    for (const key of keys) {
      remember(exactMap, normalizeFolded(key), genre);
      remember(looseMap, normalizeLooseKey(key), genre);
      remember(compactMap, normalizeCompactKey(key), genre);
    }
  }

  return { byId, exactMap, looseMap, compactMap };
};

const matchGenreLabel = (label: string, index: GenreIndex): LabelMatch | null => {
  const input = normalizeText(label);
  if (!input) return null;

  const exactKey = normalizeFolded(input);
  const looseKey = normalizeLooseKey(input);
  const compactKey = normalizeCompactKey(input);

  const matchedExact = index.byId.get(input)
    || index.exactMap.get(exactKey)
    || null;
  if (matchedExact) {
    const strategy =
      matchedExact.id === input
        ? 'id'
        : normalizeFolded(matchedExact.slug) === exactKey
          ? 'slug'
          : normalizeFolded(matchedExact.path) === exactKey
            ? 'path'
            : 'name_exact';
    return {
      input,
      normalized: looseKey,
      genreId: matchedExact.id,
      genreName: matchedExact.name,
      genrePath: matchedExact.path,
      strategy,
    };
  }

  const matchedLoose = index.looseMap.get(looseKey) || null;
  if (matchedLoose) {
    return {
      input,
      normalized: looseKey,
      genreId: matchedLoose.id,
      genreName: matchedLoose.name,
      genrePath: matchedLoose.path,
      strategy: 'name_loose',
    };
  }

  const matchedCompact = index.compactMap.get(compactKey) || null;
  if (matchedCompact) {
    return {
      input,
      normalized: looseKey,
      genreId: matchedCompact.id,
      genreName: matchedCompact.name,
      genrePath: matchedCompact.path,
      strategy: 'name_compact',
    };
  }

  return null;
};

const topCounts = (values: string[], take = 20): Array<{ value: string; count: number }> => {
  const counter = new Map<string, number>();
  for (const value of values) {
    counter.set(value, (counter.get(value) || 0) + 1);
  }
  return Array.from(counter.entries())
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, take)
    .map(([value, count]) => ({ value, count }));
};

const normalizePersonalityBindings = (value: unknown): GenreBindingCandidate[] => {
  if (!Array.isArray(value)) return [];
  const result: GenreBindingCandidate[] = [];
  const seen = new Set<string>();

  for (const raw of value) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
    const row = raw as Record<string, unknown>;
    const label = normalizeText(row.label);
    const genreId = normalizeText(row.genreId);
    const pathText = normalizeText(row.path) || null;
    const normalizedLabel = label || (pathText ? pathText.split('/').map((part) => normalizeText(part)).filter(Boolean).at(-1) || '' : '');
    if (!normalizedLabel) continue;

    const key = genreId ? `genre:${genreId}` : `custom:${normalizeLooseKey(normalizedLabel)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push({
      genreId,
      label: normalizedLabel,
      path: pathText,
    });
  }

  return result;
};

async function buildDJPlans(index: GenreIndex): Promise<DJPlan[]> {
  const rows = await prisma.dJ.findMany({
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      id: true,
      name: true,
      genres: true,
      genreBindings: {
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        select: {
          genreId: true,
        },
      },
    },
  });

  return rows.map((row) => {
    const labels = splitGenreLabels(row.genres);
    const matches: LabelMatch[] = [];
    const unmatched: string[] = [];
    const matchedGenreIds = new Set<string>();

    for (const label of labels) {
      const resolution = resolveDJLabel(label, index);

      for (const matched of resolution.matches) {
        if (matchedGenreIds.has(matched.genreId)) continue;
        matchedGenreIds.add(matched.genreId);
        matches.push(matched);
      }

      for (const unresolved of resolution.unmatched) {
        unmatched.push(unresolved);
      }
    }

    return {
      djId: row.id,
      djName: row.name,
      labels,
      matches,
      unmatched,
      nextBindings: matches.map((match, indexValue) => ({
        genreId: match.genreId,
        displayName: match.input !== match.genreName ? match.input : null,
        sortOrder: indexValue + 1,
      })),
      skippedBecauseExisting: !OVERWRITE_EXISTING && row.genreBindings.length > 0,
    };
  });
}

async function applyDJPlans(plans: DJPlan[]) {
  for (const plan of plans) {
    if (plan.skippedBecauseExisting) continue;
    await prisma.$transaction(async (tx) => {
      await tx.dJGenreBinding.deleteMany({
        where: { djId: plan.djId },
      });
      if (plan.nextBindings.length > 0) {
        await tx.dJGenreBinding.createMany({
          data: plan.nextBindings.map((binding) => ({
            djId: plan.djId,
            genreId: binding.genreId,
            displayName: binding.displayName,
            sortOrder: binding.sortOrder,
          })),
          skipDuplicates: true,
        });
      }
    });
  }
}

async function buildPersonalityPlans(index: GenreIndex): Promise<PersonalityPlan[]> {
  const rows = await prisma.personalityResultType.findMany({
    orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      id: true,
      code: true,
      title: true,
      genreMapping: true,
      genreBindings: true,
    },
  });

  return rows.map((row) => {
    const existingBindings = normalizePersonalityBindings(row.genreBindings);
    const sourceLabels = existingBindings.length > 0
      ? existingBindings.map((item) => item.label)
      : splitGenreLabels(row.genreMapping);

    const matches: LabelMatch[] = [];
    const unmatched: string[] = [];
    const nextBindings: GenreBindingCandidate[] = [];
    const seen = new Set<string>();

    for (const sourceLabel of sourceLabels) {
      const existing = existingBindings.find((item) => normalizeLooseKey(item.label) === normalizeLooseKey(sourceLabel)) || null;
      if (existing?.genreId && index.byId.has(existing.genreId)) {
        const boundGenre = index.byId.get(existing.genreId)!;
        const key = `genre:${boundGenre.id}`;
        if (!seen.has(key)) {
          seen.add(key);
          nextBindings.push({
            genreId: boundGenre.id,
            label: existing.label || boundGenre.name,
            path: boundGenre.path,
          });
        }
        continue;
      }

      const matched = matchGenreLabel(sourceLabel, index);
      if (matched) {
        const key = `genre:${matched.genreId}`;
        if (!seen.has(key)) {
          seen.add(key);
          matches.push(matched);
          nextBindings.push({
            genreId: matched.genreId,
            label: sourceLabel,
            path: matched.genrePath,
          });
        }
      } else {
        const key = `custom:${normalizeLooseKey(sourceLabel)}`;
        if (!seen.has(key)) {
          seen.add(key);
          unmatched.push(sourceLabel);
          nextBindings.push({
            genreId: '',
            label: sourceLabel,
            path: null,
          });
        }
      }
    }

    return {
      resultTypeId: row.id,
      code: row.code,
      title: row.title,
      labels: sourceLabels,
      matches,
      unmatched,
      nextBindings,
      skippedBecauseExisting: !OVERWRITE_EXISTING && existingBindings.some((item) => item.genreId),
    };
  });
}

async function applyPersonalityPlans(plans: PersonalityPlan[]) {
  for (const plan of plans) {
    if (plan.skippedBecauseExisting) continue;
    await prisma.personalityResultType.update({
      where: { id: plan.resultTypeId },
      data: {
        genreBindings: plan.nextBindings.map((binding) => ({
          label: binding.label,
          genreId: binding.genreId || null,
          path: binding.path,
        })) as Prisma.InputJsonValue,
      },
    });
  }
}

async function buildUserPlans(index: GenreIndex): Promise<UserPlan[]> {
  const rows = await prisma.userGenrePreference.findMany({
    orderBy: [{ userId: 'asc' }, { sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      userId: true,
      genreKey: true,
    },
  });

  const grouped = new Map<string, string[]>();
  for (const row of rows) {
    const bucket = grouped.get(row.userId) ?? [];
    bucket.push(row.genreKey);
    grouped.set(row.userId, bucket);
  }

  return Array.from(grouped.entries()).map(([userId, beforeKeys]) => {
    const nextKeys: string[] = [];
    const matches: LabelMatch[] = [];
    const unmatched: string[] = [];
    const seen = new Set<string>();

    for (const rawKey of beforeKeys) {
      const matched = matchGenreLabel(rawKey, index);
      const nextKey = matched?.genreId || normalizeText(rawKey);
      if (!nextKey || seen.has(nextKey)) {
        if (!matched && rawKey) unmatched.push(rawKey);
        continue;
      }
      seen.add(nextKey);
      nextKeys.push(nextKey);
      if (matched) {
        matches.push(matched);
      } else {
        unmatched.push(rawKey);
      }
    }

    const changed =
      beforeKeys.length !== nextKeys.length ||
      beforeKeys.some((value, indexValue) => value !== nextKeys[indexValue]);

    return {
      userId,
      beforeKeys,
      nextKeys,
      matches,
      unmatched,
      changed,
    };
  });
}

async function applyUserPlans(plans: UserPlan[]) {
  for (const plan of plans) {
    if (!plan.changed) continue;
    await prisma.$transaction(async (tx) => {
      await tx.userGenrePreference.deleteMany({
        where: { userId: plan.userId },
      });
      if (plan.nextKeys.length > 0) {
        await tx.userGenrePreference.createMany({
          data: plan.nextKeys.map((genreKey, index) => ({
            userId: plan.userId,
            genreKey,
            sortOrder: index + 1,
          })),
          skipDuplicates: true,
        });
      }
    });
  }
}

async function writeReport(payload: ReportPayload) {
  await fs.promises.mkdir(path.dirname(REPORT_PATH), { recursive: true });
  await fs.promises.writeFile(REPORT_PATH, JSON.stringify(payload, null, 2), 'utf8');
}

async function main() {
  const startedAt = new Date().toISOString();
  console.log('[genre-bindings-backfill] start', {
    target: TARGET,
    apply: APPLY,
    overwriteExisting: OVERWRITE_EXISTING,
    limit: LIMIT,
    report: REPORT_PATH,
  });

  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      name: true,
      slug: true,
      path: true,
    },
  });
  const index = buildGenreIndex(genres);

  const report: ReportPayload = {
    startedAt,
    finishedAt: startedAt,
    apply: APPLY,
    overwriteExisting: OVERWRITE_EXISTING,
    target: TARGET,
    limit: LIMIT,
    summary: {
      genreCount: genres.length,
    },
  };

  if (TARGET === 'djs' || TARGET === 'all') {
    const plans = await buildDJPlans(index);
    const actionable = plans.filter((plan) => !plan.skippedBecauseExisting);
    const matchedCount = plans.reduce((sum, plan) => sum + plan.matches.length, 0);
    const unmatchedLabels = plans.flatMap((plan) => plan.unmatched);

    report.djs = {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
      topUnmatchedLabels: topCounts(unmatchedLabels),
      samples: plans.slice(0, 20),
    };

    console.log('[genre-bindings-backfill] djs', {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
    });

    if (APPLY) {
      await applyDJPlans(plans);
    }
  }

  if (TARGET === 'personality' || TARGET === 'all') {
    const plans = await buildPersonalityPlans(index);
    const actionable = plans.filter((plan) => !plan.skippedBecauseExisting);
    const matchedCount = plans.reduce((sum, plan) => sum + plan.matches.length, 0);
    const unmatchedLabels = plans.flatMap((plan) => plan.unmatched);

    report.personality = {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
      topUnmatchedLabels: topCounts(unmatchedLabels),
      samples: plans.slice(0, 20),
    };

    console.log('[genre-bindings-backfill] personality', {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
    });

    if (APPLY) {
      await applyPersonalityPlans(plans);
    }
  }

  if (TARGET === 'users' || TARGET === 'all') {
    const plans = await buildUserPlans(index);
    const changed = plans.filter((plan) => plan.changed);
    const matchedCount = plans.reduce((sum, plan) => sum + plan.matches.length, 0);
    const unmatchedLabels = plans.flatMap((plan) => plan.unmatched);

    report.users = {
      scanned: plans.length,
      changed: changed.length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
      topUnmatchedLabels: topCounts(unmatchedLabels),
      samples: plans.slice(0, 20),
    };

    console.log('[genre-bindings-backfill] users', {
      scanned: plans.length,
      changed: changed.length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
    });

    if (APPLY) {
      await applyUserPlans(plans);
    }
  }

  report.finishedAt = new Date().toISOString();
  await writeReport(report);
  console.log('[genre-bindings-backfill] done', {
    report: REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-bindings-backfill] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
