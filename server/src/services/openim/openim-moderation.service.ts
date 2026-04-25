import { openIMConfig } from './openim-config';

export interface OpenIMImageModerationJobDraft {
  imageUrl: string;
  status: 'pending' | 'rejected';
  reason: string;
  host: string | null;
  matchedKeyword: string | null;
}

export interface OpenIMModerationResult {
  blocked: boolean;
  reason: string;
  matchedWord: string | null;
  matchedWords: string[];
  matchedPatterns: string[];
  imageModeration: {
    enabled: boolean;
    detectedCount: number;
    pendingCount: number;
    rejectedCount: number;
    jobs: OpenIMImageModerationJobDraft[];
  };
}

const MAX_PAYLOAD_TRAVERSAL_NODES = 4000;
const MAX_PAYLOAD_STRINGS = 1000;
const URL_REGEX = /https?:\/\/[^\s"'<>\\]+/gi;
const IMAGE_EXT_REGEX = /\.(png|jpe?g|gif|webp|heic|heif|bmp|svg)(\?|#|$)/i;
const IMAGE_KEY_HINT_REGEX = /(^|\.)(image|images|picture|pictures|pic|photo|cover|thumb|thumbnail|snapshot|sourcepicture|bigpicture)$/i;

const safeNormalize = (value: string): string => {
  try {
    return value.normalize('NFKC');
  } catch (_error) {
    return value;
  }
};

const normalizeForLooseMatch = (value: string): string => {
  return safeNormalize(value)
    .toLowerCase()
    .replace(/[\s\W_]+/g, '');
};

const parsePatternToken = (token: string): RegExp | null => {
  const trimmed = token.trim();
  if (!trimmed) {
    return null;
  }

  const slashWrapped = /^\/(.+)\/([a-z]*)$/i.exec(trimmed);
  const source = slashWrapped ? slashWrapped[1] : trimmed;
  const rawFlags = slashWrapped ? slashWrapped[2] : 'iu';
  const flags = Array.from(new Set(rawFlags.replace(/[gy]/g, '').split(''))).join('') || 'iu';

  try {
    return new RegExp(source, flags);
  } catch (_error) {
    return null;
  }
};

const compiledSensitivePatterns: RegExp[] = openIMConfig.sensitivePatterns
  .map(parsePatternToken)
  .filter((pattern): pattern is RegExp => Boolean(pattern));

const extractUrls = (text: string): string[] => {
  const matches = text.match(URL_REGEX);
  if (!matches || matches.length === 0) {
    return [];
  }
  return matches.map((item) => item.trim());
};

const parseUrlHost = (url: string): string | null => {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch (_error) {
    return null;
  }
};

const isLikelyImageUrl = (url: string, pathHint: string): boolean => {
  if (IMAGE_KEY_HINT_REGEX.test(pathHint)) {
    return true;
  }
  if (IMAGE_EXT_REGEX.test(url)) {
    return true;
  }
  const normalized = url.toLowerCase();
  return (
    normalized.includes('/image/') ||
    normalized.includes('/images/') ||
    normalized.includes('image=') ||
    normalized.includes('img=')
  );
};

const collectPayloadStrings = (payload: unknown): Array<{ text: string; path: string }> => {
  const queue: Array<{ value: unknown; path: string }> = [{ value: payload, path: '$' }];
  const seen = new WeakSet<object>();
  const strings: Array<{ text: string; path: string }> = [];
  let visited = 0;

  while (queue.length > 0 && visited < MAX_PAYLOAD_TRAVERSAL_NODES && strings.length < MAX_PAYLOAD_STRINGS) {
    const item = queue.shift();
    if (!item) {
      break;
    }
    visited += 1;

    const { value, path } = item;
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed) {
        strings.push({ text: trimmed.slice(0, 5000), path });
      }
      continue;
    }

    if (!value || typeof value !== 'object') {
      continue;
    }
    if (seen.has(value as object)) {
      continue;
    }
    seen.add(value as object);

    if (Array.isArray(value)) {
      for (let index = 0; index < value.length; index += 1) {
        queue.push({ value: value[index], path: `${path}[${index}]` });
      }
      continue;
    }

    for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
      queue.push({ value: child, path: `${path}.${key}` });
    }
  }

  return strings;
};

const matchSensitiveWords = (strings: string[]): string[] => {
  if (openIMConfig.sensitiveWords.length === 0 || strings.length === 0) {
    return [];
  }

  const fullText = strings.join('\n').slice(0, 100_000);
  const loweredText = fullText.toLowerCase();
  const normalizedText = normalizeForLooseMatch(fullText);

  const matched = new Set<string>();
  for (const word of openIMConfig.sensitiveWords) {
    const normalizedWord = normalizeForLooseMatch(word);
    if (!normalizedWord) {
      continue;
    }
    if (loweredText.includes(word) || normalizedText.includes(normalizedWord)) {
      matched.add(word);
    }
  }

  return Array.from(matched);
};

const matchSensitivePatterns = (strings: string[]): string[] => {
  if (compiledSensitivePatterns.length === 0 || strings.length === 0) {
    return [];
  }
  const fullText = strings.join('\n').slice(0, 100_000);
  const matched = new Set<string>();
  for (const pattern of compiledSensitivePatterns) {
    if (pattern.test(fullText)) {
      matched.add(pattern.toString());
    }
  }
  return Array.from(matched);
};

const buildImageJobs = (payloadStrings: Array<{ text: string; path: string }>): OpenIMImageModerationJobDraft[] => {
  if (!openIMConfig.imageModerationEnabled) {
    return [];
  }

  const candidates: Array<{ url: string; path: string }> = [];
  for (const { text, path } of payloadStrings) {
    const urls = extractUrls(text);
    for (const url of urls) {
      if (isLikelyImageUrl(url, path)) {
        candidates.push({ url, path });
      }
    }
  }

  const uniqueUrls = Array.from(new Set(candidates.map((item) => item.url))).slice(
    0,
    Math.max(1, openIMConfig.imageModerationMaxUrls)
  );

  return uniqueUrls.map((url) => {
    const loweredUrl = url.toLowerCase();
    const matchedKeyword =
      openIMConfig.imageModerationBlockKeywords.find((keyword) => loweredUrl.includes(keyword)) || null;
    const host = parseUrlHost(url);

    const hasAllowList = openIMConfig.imageModerationAllowedHosts.length > 0;
    const hostAllowed =
      !hasAllowList ||
      (host
        ? openIMConfig.imageModerationAllowedHosts.some(
            (allowed) => host === allowed || host.endsWith(`.${allowed}`)
          )
        : false);

    if (matchedKeyword) {
      return {
        imageUrl: url,
        status: 'rejected',
        reason: `keyword-hit:${matchedKeyword}`,
        host,
        matchedKeyword,
      };
    }

    if (hasAllowList && !hostAllowed) {
      return {
        imageUrl: url,
        status: 'rejected',
        reason: 'host-not-allowlisted',
        host,
        matchedKeyword: null,
      };
    }

    return {
      imageUrl: url,
      status: 'pending',
      reason: 'pending-manual-review',
      host,
      matchedKeyword: null,
    };
  });
};

export const openIMModerationService = {
  evaluatePayload(payload: unknown): OpenIMModerationResult {
    const payloadStrings = collectPayloadStrings(payload);
    const textValues = payloadStrings.map((item) => item.text);

    const matchedWords = matchSensitiveWords(textValues);
    const matchedPatterns = matchSensitivePatterns(textValues);
    const imageJobs = buildImageJobs(payloadStrings);

    const sensitiveBlocked =
      openIMConfig.webhookBlockSensitiveWords && (matchedWords.length > 0 || matchedPatterns.length > 0);
    const rejectedImageCount = imageJobs.filter((job) => job.status === 'rejected').length;
    const imageBlocked = openIMConfig.webhookBlockImageHits && rejectedImageCount > 0;
    const blocked = sensitiveBlocked || imageBlocked;

    let reason = 'clean';
    if (sensitiveBlocked && matchedWords.length > 0) {
      reason = `sensitive-word-detected:${matchedWords[0]}`;
    } else if (sensitiveBlocked && matchedPatterns.length > 0) {
      reason = `sensitive-pattern-detected:${matchedPatterns[0]}`;
    } else if (imageBlocked) {
      const firstRejected = imageJobs.find((job) => job.status === 'rejected');
      reason = `image-moderation-blocked:${firstRejected?.reason || 'rejected'}`;
    }

    const matchedWord = matchedWords.length > 0 ? matchedWords[0] : null;
    const pendingImageCount = imageJobs.filter((job) => job.status === 'pending').length;

    return {
      blocked,
      reason,
      matchedWord,
      matchedWords,
      matchedPatterns,
      imageModeration: {
        enabled: openIMConfig.imageModerationEnabled,
        detectedCount: imageJobs.length,
        pendingCount: pendingImageCount,
        rejectedCount: rejectedImageCount,
        jobs: imageJobs,
      },
    };
  },
};
