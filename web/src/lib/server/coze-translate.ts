type JsonRecord = Record<string, unknown>;

const cozeTranslateRunUrl = String(process.env.COZE_TRANSLATE_RUN_URL || '').trim();
const cozeTranslateToken = String(
  process.env.COZE_TOKEN_TRANSLATE ||
    process.env.COZE_WORKFLOW_TOKEN ||
    process.env.COZE_TIMETABLE_WORKFLOW_TOKEN ||
    process.env.COZE_LINEUP_WORKFLOW_TOKEN ||
    ''
).trim();
const cozeTranslateTimeoutMs = (() => {
  const parsed = Number(
    process.env.COZE_TRANSLATE_TIMEOUT_MS || process.env.COZE_TRANSLATE_TIMEOUT_SEC || 90_000
  );
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed < 1000 ? Math.floor(parsed * 1000) : Math.floor(parsed);
  }
  return 90_000;
})();

const cozeDjTranslateRunUrl = String(process.env.COZE_DJ_TRANS_RUN_URL || '').trim();
const cozeDjTranslateToken = String(
  process.env.COZE_DJ_TRANS_TOKEN ||
    process.env.COZE_TOKEN_DJ_TRANS ||
    process.env.COZE_TOKEN_TRANSLATE ||
    process.env.COZE_WORKFLOW_TOKEN ||
    process.env.COZE_TIMETABLE_WORKFLOW_TOKEN ||
    process.env.COZE_LINEUP_WORKFLOW_TOKEN ||
    ''
).trim();
const cozeDjTranslateTimeoutMs = (() => {
  const parsed = Number(
    process.env.COZE_DJ_TRANS_TIMEOUT_MS || process.env.COZE_DJ_TRANS_TIMEOUT_SEC || 90_000
  );
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed < 1000 ? Math.floor(parsed * 1000) : Math.floor(parsed);
  }
  return 90_000;
})();

const asRecord = (value: unknown): JsonRecord => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value as JsonRecord;
};

const cleanText = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

const normalizeKey = (value: string): string => String(value || '').replace(/[^a-z0-9]/gi, '').toLowerCase();

const parsePossibleJson = (rawText: string): unknown => {
  const trimmed = String(rawText || '').trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    const firstBrace = trimmed.indexOf('{');
    const lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      try {
        return JSON.parse(trimmed.slice(firstBrace, lastBrace + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
};

const extractJsonFragment = (value: string): unknown => parsePossibleJson(value);

const parseKvText = (value: string): JsonRecord | null => {
  const lines = String(value || '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (!lines.length) return null;
  const out: JsonRecord = {};
  for (const line of lines) {
    const match = line.match(/^["']?([A-Za-z0-9_.-]+)["']?\s*[:=]\s*(.+)$/);
    if (!match) continue;
    out[match[1]] = match[2].trim().replace(/^["']|["']$/g, '');
  }
  return Object.keys(out).length ? out : null;
};

const normalizeCountryI18n = (value: unknown): { en: string; zh: string; enFull: string } => {
  const record = asRecord(value);
  const en = cleanText(record.en || record.english);
  const zh = cleanText(record.zh || record.cn || record.chinese);
  const enFull = cleanText(record.enFull || record.en_full || record.englishFull);
  const fallback = en || zh || enFull;
  return {
    en: en || zh || fallback,
    zh: zh || en || fallback,
    enFull: enFull || en || zh || fallback,
  };
};

const postCozeJson = async (
  url: string,
  token: string,
  payload: unknown,
  timeoutMs: number,
  label: string
): Promise<unknown> => {
  if (!url || !token) {
    throw new Error(`${label} is not configured`);
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  let rawText = '';
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    rawText = await response.text();
    if (!response.ok) {
      throw new Error(`${label} request failed (${response.status}): ${rawText.slice(0, 500)}`);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`${label} timeout after ${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
  const parsed = parsePossibleJson(rawText);
  if (!parsed) {
    throw new Error(`${label} returned non-JSON content`);
  }
  return parsed;
};

export const extractFestivalTranslationInfo = (payload: unknown) => {
  const out = {
    nameI18n: { en: '', zh: '' },
    cityI18n: { en: '', zh: '' },
    detailAddressI18n: { en: '', zh: '' },
    countryI18n: { en: '', zh: '', enFull: '' },
  };
  const keyMap: Record<string, [keyof typeof out, string]> = {
    nameen: ['nameI18n', 'en'],
    namezh: ['nameI18n', 'zh'],
    festivalnameen: ['nameI18n', 'en'],
    festivalnamezh: ['nameI18n', 'zh'],
    eventnameen: ['nameI18n', 'en'],
    eventnamezh: ['nameI18n', 'zh'],
    titleen: ['nameI18n', 'en'],
    titlezh: ['nameI18n', 'zh'],
    cityen: ['cityI18n', 'en'],
    cityzh: ['cityI18n', 'zh'],
    detailaddressen: ['detailAddressI18n', 'en'],
    detailaddresszh: ['detailAddressI18n', 'zh'],
    countryen: ['countryI18n', 'en'],
    countryzh: ['countryI18n', 'zh'],
    countryenfull: ['countryI18n', 'enFull'],
    countryenglishfull: ['countryI18n', 'enFull'],
    countryfullnameen: ['countryI18n', 'enFull'],
    countryfullen: ['countryI18n', 'enFull'],
  };
  const objectAlias: Record<string, keyof typeof out> = {
    namei18n: 'nameI18n',
    festivalnamei18n: 'nameI18n',
    eventnamei18n: 'nameI18n',
    name: 'nameI18n',
    title: 'nameI18n',
    cityi18n: 'cityI18n',
    city: 'cityI18n',
    detailaddressi18n: 'detailAddressI18n',
    detailaddress: 'detailAddressI18n',
    countryi18n: 'countryI18n',
    country: 'countryI18n',
  };

  const setField = (field: keyof typeof out, lang: string, value: unknown) => {
    const text = cleanText(value);
    if (!text) return;
    const target = out[field] as Record<string, string>;
    if (!target[lang]) target[lang] = text;
  };

  const tryFillFromObj = (aliasKey: string, obj: JsonRecord) => {
    const field = objectAlias[aliasKey];
    if (!field) return;
    setField(field, 'en', obj.en || obj.english || obj.name_en);
    setField(field, 'zh', obj.zh || obj.chinese || obj.name_zh || obj.cn);
    if (field === 'countryI18n') {
      setField(field, 'enFull', obj.enFull || obj.en_full || obj.englishFull || obj.country_en_full);
    }
  };

  const walk = (node: unknown) => {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (typeof node === 'string') {
      const parsed = extractJsonFragment(node) || parseKvText(node);
      if (parsed) walk(parsed);
      return;
    }
    const record = asRecord(node);
    for (const [key, value] of Object.entries(record)) {
      const normalizedKey = normalizeKey(key);
      if (typeof value === 'string') {
        const mapped = keyMap[normalizedKey];
        if (mapped) setField(mapped[0], mapped[1], value);
        const parsed = extractJsonFragment(value) || parseKvText(value);
        if (parsed) walk(parsed);
        continue;
      }
      if (Array.isArray(value)) {
        walk(value);
        continue;
      }
      const valueRecord = asRecord(value);
      if (normalizedKey === 'manuallocation' || normalizedKey === 'manuallocationi18n') {
        const detailObj = asRecord(valueRecord.detailAddressI18n || valueRecord.detail_address_i18n);
        if (Object.keys(detailObj).length) {
          tryFillFromObj('detailaddressi18n', detailObj);
        }
      }
      tryFillFromObj(normalizedKey, valueRecord);
      const mapped = keyMap[normalizedKey];
      if (mapped) setField(mapped[0], mapped[1], value);
      walk(valueRecord);
    }
  };

  walk(payload);

  for (const field of ['nameI18n', 'cityI18n', 'detailAddressI18n'] as const) {
    if (out[field].en && !out[field].zh) out[field].zh = out[field].en;
    if (out[field].zh && !out[field].en) out[field].en = out[field].zh;
  }
  out.countryI18n = normalizeCountryI18n(out.countryI18n);
  return out;
};

const isDjTranslationHintText = (value: string): boolean => {
  const text = cleanText(value);
  if (!text) return false;
  const lowered = text.toLowerCase();
  if (
    [
      'please provide',
      'missing',
      'not provided',
      'no input',
      'input required',
      'invalid input',
      'cannot translate',
    ].some((token) => lowered.includes(token))
  ) {
    return true;
  }
  return ['n/a', 'na', 'none', 'null', 'undefined'].includes(lowered);
};

const cleanDjTranslationText = (value: unknown, sourceValue: string): string => {
  const text = cleanText(value);
  if (!text || !sourceValue || isDjTranslationHintText(text)) return '';
  return text;
};

export const extractDjTranslationInfo = (payload: unknown) => {
  const out = {
    fields_cn: { country: '', bio: '' },
    fields_en: { country: '', bio: '' },
  };

  const setField = (langKey: keyof typeof out, fieldKey: 'country' | 'bio', value: unknown) => {
    const text = cleanText(value);
    if (!text || out[langKey][fieldKey]) return;
    out[langKey][fieldKey] = text;
  };

  const fillLangFields = (langKey: keyof typeof out, obj: JsonRecord) => {
    setField(langKey, 'country', obj.country || obj.countryName || obj.nation || obj.country_cn || obj.country_en);
    setField(langKey, 'bio', obj.bio || obj.profile || obj.description || obj.intro || obj.biography);
  };

  const maybeFillByDictKey = (key: string, value: JsonRecord): boolean => {
    const normalizedKey = normalizeKey(key);
    if (['fieldscn', 'fieldzh', 'zhfields', 'chinesefields', 'cnfields'].includes(normalizedKey)) {
      fillLangFields('fields_cn', value);
      return true;
    }
    if (['fieldsen', 'fieldeng', 'enfields', 'englishfields'].includes(normalizedKey)) {
      fillLangFields('fields_en', value);
      return true;
    }
    if (['countryi18n', 'bioi18n', 'fieldsi18n', 'i18n'].includes(normalizedKey)) {
      fillLangFields('fields_cn', asRecord(value.zh || value.cn));
      fillLangFields('fields_en', asRecord(value.en));
      return true;
    }
    return false;
  };

  const walk = (node: unknown) => {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (typeof node === 'string') {
      const parsed = extractJsonFragment(node) || parseKvText(node);
      if (parsed) walk(parsed);
      return;
    }
    const record = asRecord(node);
    for (const [key, value] of Object.entries(record)) {
      const normalizedKey = normalizeKey(key);
      if (typeof value === 'string') {
        if (['fieldscncountry', 'countrycn', 'cncountry', 'zhcountry'].includes(normalizedKey)) {
          setField('fields_cn', 'country', value);
        } else if (['fieldscnbio', 'biocn', 'cnbio', 'zhbio'].includes(normalizedKey)) {
          setField('fields_cn', 'bio', value);
        } else if (['fieldsencountry', 'countryen', 'encountry'].includes(normalizedKey)) {
          setField('fields_en', 'country', value);
        } else if (['fieldsenbio', 'bioen', 'enbio'].includes(normalizedKey)) {
          setField('fields_en', 'bio', value);
        }
        const parsed = extractJsonFragment(value) || parseKvText(value);
        if (parsed) walk(parsed);
        continue;
      }
      if (Array.isArray(value)) {
        walk(value);
        continue;
      }
      const valueRecord = asRecord(value);
      if (!maybeFillByDictKey(key, valueRecord)) {
        if (['fieldscncountry', 'countrycn', 'cncountry', 'zhcountry'].includes(normalizedKey)) {
          setField('fields_cn', 'country', valueRecord.value);
        } else if (['fieldscnbio', 'biocn', 'cnbio', 'zhbio'].includes(normalizedKey)) {
          setField('fields_cn', 'bio', valueRecord.value);
        } else if (['fieldsencountry', 'countryen', 'encountry'].includes(normalizedKey)) {
          setField('fields_en', 'country', valueRecord.value);
        } else if (['fieldsenbio', 'bioen', 'enbio'].includes(normalizedKey)) {
          setField('fields_en', 'bio', valueRecord.value);
        }
      }
      walk(valueRecord);
    }
  };

  walk(payload);
  return out;
};

export const runCozeFestivalTranslate = async (festival: unknown) => {
  const festivalRecord = asRecord(festival);
  if (!Object.keys(festivalRecord).length) {
    throw new Error('festival object is required');
  }
  const raw = await postCozeJson(
    cozeTranslateRunUrl,
    cozeTranslateToken,
    { festival: festivalRecord },
    cozeTranslateTimeoutMs,
    'COZE_TRANSLATE'
  );
  return {
    raw,
    translated: extractFestivalTranslationInfo(raw),
  };
};

export const runCozeDjFieldTranslate = async (fields: unknown) => {
  const fieldRecord = asRecord(fields);
  const sourceCountry = cleanText(fieldRecord.country);
  const sourceBio = cleanText(fieldRecord.bio);
  if (!sourceCountry && !sourceBio) {
    throw new Error('fields.country or fields.bio is required');
  }
  const raw = await postCozeJson(
    cozeDjTranslateRunUrl,
    cozeDjTranslateToken,
    {
      fields: {
        country: sourceCountry,
        bio: sourceBio,
      },
      instruction:
        'If country or bio is empty, return empty strings in fields_cn/fields_en for the corresponding fields and do not return explanatory text.',
    },
    cozeDjTranslateTimeoutMs,
    'COZE_DJ_TRANSLATE'
  );
  const translated = extractDjTranslationInfo(raw);
  return {
    raw,
    translated: {
      fields_cn: {
        country: sourceCountry ? cleanDjTranslationText(translated.fields_cn.country, sourceCountry) : '',
        bio: sourceBio ? cleanDjTranslationText(translated.fields_cn.bio, sourceBio) : '',
      },
      fields_en: {
        country: sourceCountry ? cleanDjTranslationText(translated.fields_en.country, sourceCountry) : '',
        bio: sourceBio ? cleanDjTranslationText(translated.fields_en.bio, sourceBio) : '',
      },
    },
  };
};
