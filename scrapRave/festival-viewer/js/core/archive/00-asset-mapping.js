// Core module extracted from monolith (archive sync/cache)
function sanitizeEventImageFileName(name, fallback = 'image.jpg') {
  const raw = String(name || '').trim().replace(/[/\\?%*:|"<>]/g, '-');
  if (!raw) return fallback;
  return raw.slice(0, 180);
}

function normalizeEventImageZoneKey(value) {
  const key = String(value || '').trim().toLowerCase();
  if (EVENT_IMAGE_ZONE_MAP[key]) return key;
  return 'other';
}

function inferEventImageZoneFromAsset(asset) {
  const type = String(asset?.type || '').trim().toLowerCase();
  const label = String(asset?.label || '').trim().toUpperCase();
  if (type === 'cover') return 'cover';
  if (type === 'luall' || type === 'lineup') return 'lineup';
  if (type === 'tt' || type === 'timetable') return 'timetable';
  if (type === 'poster') return 'poster';
  if (type === 'map') return 'map';
  if (type === 'other') {
    if (label.includes('POSTER')) return 'poster';
    if (label.includes('MAP')) return 'map';
    if (label.includes('LINE-UP') || label.includes('LINEUP')) return 'lineup';
    if (label.includes('TIMETABLE')) return 'timetable';
    if (label.includes('COVER')) return 'cover';
    return 'other';
  }
  return 'other';
}

function backendTypeForImageZone(zoneKey) {
  const zone = EVENT_IMAGE_ZONE_MAP[normalizeEventImageZoneKey(zoneKey)];
  return zone?.backendType || 'other';
}

function defaultImageLabelForZone(zoneKey) {
  const zone = EVENT_IMAGE_ZONE_MAP[normalizeEventImageZoneKey(zoneKey)];
  return zone?.defaultLabel || 'OTHER';
}

function guessImageExtFromNameOrUrl(nameOrUrl, mimeType = '') {
  const fromName = String(nameOrUrl || '').match(/\.([a-z0-9]{2,8})(?:$|[?#])/i);
  if (fromName) return `.${fromName[1].toLowerCase()}`;
  const mime = String(mimeType || '').toLowerCase();
  if (mime.includes('png')) return '.png';
  if (mime.includes('webp')) return '.webp';
  if (mime.includes('gif')) return '.gif';
  if (mime.includes('bmp')) return '.bmp';
  if (mime.includes('svg')) return '.svg';
  return '.jpg';
}

function formatArchiveLineupTimeRange(startTime, endTime) {
  const start = new Date(startTime);
  const end = new Date(endTime);
  if (Number.isNaN(start.getTime()) && Number.isNaN(end.getTime())) return '未知';
  const fmt = (date) => {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) return '00:00';
    const h = String(date.getHours()).padStart(2, '0');
    const m = String(date.getMinutes()).padStart(2, '0');
    return `${h}:${m}`;
  };
  return `${fmt(start)}—${fmt(end)}`;
}

function mapBackendLineupSlotsToArchiveRows(slots, eventStartDateText = '') {
  if (!Array.isArray(slots)) return [];
  const eventStartDay = parseArchiveDateOnlyForSync(eventStartDateText);
  return slots
    .map((slot) => {
      if (!slot || typeof slot !== 'object') return null;
      const djName = String(slot.djName || slot?.dj?.name || '').trim();
      if (!djName) return null;
      const start = new Date(slot.startTime);
      const explicitDayIndex = Number(slot.festivalDayIndex);
      const logicalDayDate = (
        Number.isInteger(explicitDayIndex)
        && explicitDayIndex > 0
        && eventStartDay instanceof Date
        && !Number.isNaN(eventStartDay.getTime())
      )
        ? new Date(eventStartDay.getTime() + (explicitDayIndex - 1) * 24 * 60 * 60 * 1000)
        : start;
      const dateText = Number.isNaN(logicalDayDate.getTime())
        ? '未知'
        : `${logicalDayDate.getFullYear()}-${String(logicalDayDate.getMonth() + 1).padStart(2, '0')}-${String(logicalDayDate.getDate()).padStart(2, '0')}`;
      const rawDjIds = Array.isArray(slot?.djIds) ? slot.djIds : [];
      const djIds = rawDjIds
        .map((id) => String(id || '').trim())
        .filter(Boolean);
      const fallbackDjId = String(slot.djId || slot?.dj?.id || '').trim();
      const mergedDjIds = djIds.length ? djIds : (fallbackDjId ? [fallbackDjId] : []);
      const row = normalizeLineupEntry({
        musician: djName,
        date: dateText,
        time: formatArchiveLineupTimeRange(slot.startTime, slot.endTime),
        stage: String(slot.stageName || '').trim(),
        djId: fallbackDjId,
        djIds: mergedDjIds,
        festivalDayIndex: Number.isInteger(explicitDayIndex) && explicitDayIndex > 0 ? explicitDayIndex : undefined,
      });
      return row;
    })
    .filter(Boolean);
}

function normalizeBackendEventImageAssets(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const url = String(item.url || '').trim();
      if (!url) return null;
      const type = String(item.type || '').trim().toLowerCase() || 'other';
      const label = String(item.label || '').trim() || type.toUpperCase();
      const order = Number.isFinite(item.order) ? Number(item.order) : undefined;
      const sort = Number.isFinite(item.sort) ? Number(item.sort) : undefined;
      return {
        type,
        label,
        url,
        fileName: sanitizeEventImageFileName(item.fileName || pathBaseNameFromUrl(url)),
        source: String(item.source || '').trim() || undefined,
        originalUrl: String(item.originalUrl || '').trim() || undefined,
        ...(order !== undefined ? { order } : {}),
        ...(sort !== undefined ? { sort } : {}),
      };
    })
    .filter(Boolean)
    .sort((a, b) => {
      const ao = Number.isFinite(a.order) ? Number(a.order) : 99;
      const bo = Number.isFinite(b.order) ? Number(b.order) : 99;
      if (ao !== bo) return ao - bo;
      const as = Number.isFinite(a.sort) ? Number(a.sort) : 99;
      const bs = Number.isFinite(b.sort) ? Number(b.sort) : 99;
      if (as !== bs) return as - bs;
      return String(a.fileName || '').localeCompare(String(b.fileName || ''));
    });
}

function mergeBackendEventTopLevelImageAssets(event, baseAssets) {
  const merged = Array.isArray(baseAssets) ? [...baseAssets] : [];
  const existsByUrl = new Set(
    merged
      .map((asset) => String(asset?.url || '').trim().toLowerCase())
      .filter(Boolean)
  );
  const candidates = [
    { type: 'cover', label: 'COVER', url: String(event?.coverImageUrl || '').trim() },
    { type: 'luall', label: 'LINE-UP', url: String(event?.lineupImageUrl || '').trim() },
  ].filter((item) => !!item.url);
  for (const candidate of candidates) {
    const urlKey = candidate.url.toLowerCase();
    if (existsByUrl.has(urlKey)) continue;
    existsByUrl.add(urlKey);
    merged.push({
      ...candidate,
      source: 'backend-event-field',
      fileName: '',
      order: Number(EVENT_IMAGE_ZONE_MAP[inferEventImageZoneFromAsset(candidate)]?.order ?? 99),
      sort: 0,
    });
  }
  return merged.sort((a, b) => {
    const ao = Number.isFinite(a.order) ? Number(a.order) : 99;
    const bo = Number.isFinite(b.order) ? Number(b.order) : 99;
    if (ao !== bo) return ao - bo;
    const as = Number.isFinite(a.sort) ? Number(a.sort) : 99;
    const bs = Number.isFinite(b.sort) ? Number(b.sort) : 99;
    if (as !== bs) return as - bs;
    return String(a.fileName || '').localeCompare(String(b.fileName || ''));
  });
}

function pathBaseNameFromUrl(url) {
  const raw = String(url || '').trim();
  if (!raw) return '';
  try {
    const pathname = new URL(raw).pathname || '';
    const parts = pathname.split('/').filter(Boolean);
    return parts.length ? parts[parts.length - 1] : '';
  } catch (_error) {
    const cleaned = raw.split('?')[0].split('#')[0];
    const parts = cleaned.split('/').filter(Boolean);
    return parts.length ? parts[parts.length - 1] : '';
  }
}

function buildFestivalImageEntriesFromBackendAssets(eventId, assets) {
  const zoneCount = Object.fromEntries(EVENT_IMAGE_ZONES.map((zone) => [zone.key, 0]));
  return (Array.isArray(assets) ? assets : []).map((asset) => {
    const zoneKey = inferEventImageZoneFromAsset(asset);
    zoneCount[zoneKey] += 1;
    const fileName = sanitizeEventImageFileName(
      asset.fileName || `${zoneKey}${zoneCount[zoneKey] > 1 ? `-${zoneCount[zoneKey]}` : ''}${guessImageExtFromNameOrUrl(asset.url)}`
    );
    const classified = classifyImage(fileName);
    return {
      file: null,
      url: String(asset.url || '').trim(),
      remoteUrl: String(asset.url || '').trim(),
      filename: fileName,
      zoneKey,
      classified,
      sourceAsset: { ...asset, eventId },
      cacheHydrated: false,
    };
  }).filter((img) => !!img.url);
}

function mapBackendEventToFestival(event) {
  const eventId = String(event?.id || '').trim();
  const archiveFestivalId = String(event?.archiveFestivalId || '').trim();
  const startDate = normalizeArchiveDateTextForSync(event?.startDate || '');
  const endDate = normalizeArchiveDateTextForSync(event?.endDate || '') || startDate;
  const parsedStart = parseArchiveDateOnlyForSync(startDate);
  const fallbackStart = event?.startDate ? new Date(event.startDate) : null;
  const start = (parsedStart && !Number.isNaN(parsedStart.getTime()))
    ? parsedStart
    : ((fallbackStart instanceof Date && !Number.isNaN(fallbackStart.getTime())) ? fallbackStart : new Date());
  const year = start.getFullYear();
  const month = start.getMonth() + 1;
  const nameBi = normalizeBiTextValue(event?.nameI18n ?? event?.name, String(event?.name || '').trim() || 'Unknown Festival');
  const citySeed = normalizeScalarText(event?.city);
  const cityBi = normalizeBiTextValue(event?.cityI18n ?? citySeed, citySeed);
  const locationSeed = String(
    event?.manualLocation?.detailAddressI18n?.zh
    || event?.manualLocation?.detailAddressI18n?.en
    || cityBi.zh
    || cityBi.en
    || ''
  ).trim();
  const locationBi = normalizeBiTextValue(event?.manualLocation?.detailAddressI18n ?? locationSeed, locationSeed);
  const countrySeed = normalizeScalarText(event?.country);
  const countryBi = normalizeCountryBiTextValue(event?.countryI18n ?? countrySeed, countrySeed);
  const normalizedAssets = mergeBackendEventTopLevelImageAssets(
    event,
    normalizeBackendEventImageAssets(event?.imageAssets)
  );
  const lineup = mapBackendLineupSlotsToArchiveRows(event?.lineupSlots, startDate);
  const lineupArtists = Array.isArray(event?.lineupArtists)
    ? event.lineupArtists
        .map((artist, index) => {
          const djName = String(artist?.djName || artist?.name || '').trim();
          if (!djName) return null;
          return {
            id: String(artist?.id || '').trim() || undefined,
            djId: String(artist?.djId || '').trim() || undefined,
            djIds: Array.isArray(artist?.djIds) ? artist.djIds.map((id) => String(id || '').trim()).filter(Boolean) : [],
            djName,
            sortOrder: Number.isFinite(Number(artist?.sortOrder)) ? Number(artist.sortOrder) : index + 1,
          };
        })
        .filter(Boolean)
    : buildEventLineupArtistsFromArchive([], lineup);
  const fallbackFestivalId = buildFestivalId(startDate, nameBi.en || nameBi.zh, countryBi.en || countryBi.zh);
  const festivalId = archiveFestivalId || fallbackFestivalId || eventId;
  const source = mergeSourceMeta({
    provider: event?.sourceProvider || '',
    eventUrl: event?.sourceEventUrl || '',
    backendEventId: eventId,
  });
  const info = normalizeFestivalInfo({
    name: nameBi.en || nameBi.zh,
    nameI18n: nameBi,
    location: locationBi.en || locationBi.zh,
    locationI18n: locationBi,
    country: countryBi.en || countryBi.zh,
    countryI18n: countryBi,
    city: cityBi.en || cityBi.zh,
    cityI18n: cityBi,
    canceled: String(event?.status || '').trim().toLowerCase() === 'cancelled',
    startDate,
    endDate,
    timeZone: String(event?.timeZone || event?.timezone || 'UTC').trim() || 'UTC',
    relatedLinks: Array.isArray(event?.referenceLinks) ? event.referenceLinks : [],
    socialLinks: Array.isArray(event?.socialLinks) ? event.socialLinks : [],
    lineupArtists,
    lineup,
    festivalId,
    source,
    imageAssets: normalizedAssets,
    archiveFestivalId,
    backendEventId: eventId,
    wikiFestivalId: String(event?.wikiFestivalId || '').trim(),
    wikiFestival: event?.wikiFestival || null,
    slug: String(event?.slug || '').trim(),
    status: String(event?.status || '').trim(),
    dayRolloverHour: Number.isFinite(Number(event?.dayRolloverHour)) ? Number(event.dayRolloverHour) : 6,
    stageOrder: normalizeStageOrderList(event?.stageOrder ?? event?.stage_order, []),
    eventType: String(event?.eventType || '').trim(),
    organizerName: String(event?.organizerName || '').trim(),
    manualLocation: event?.manualLocation || null,
    locationPoint: event?.locationPoint || null,
    officialWebsite: String(event?.officialWebsite || '').trim(),
    ticketPriceMin: event?.ticketPriceMin,
    ticketPriceMax: event?.ticketPriceMax,
    ticketCurrency: String(event?.ticketCurrency || '').trim(),
    ticketUrl: String(event?.ticketUrl || '').trim(),
    ticketNotes: String(event?.ticketNotes || '').trim(),
    ticketTiers: Array.isArray(event?.ticketTiers) ? event.ticketTiers : [],
    description: String(event?.description || '').trim(),
    descriptionI18n: event?.descriptionI18n ?? null,
    createdAt: String(event?.createdAt || '').trim(),
    updatedAt: String(event?.updatedAt || '').trim(),
  });

  return {
    folder: String(event?.slug || festivalId || eventId || `${year}-${month}`).trim(),
    year,
    month,
    name: info.name || nameBi.en || nameBi.zh,
    location: info.location || locationBi.en || locationBi.zh,
    images: buildFestivalImageEntriesFromBackendAssets(eventId, normalizedAssets),
    yearHandle: rootDirHandle,
    dirHandle: null,
    infoHandle: null,
    infoFilename: DEFAULT_INFO_FILENAME,
    backendEventId: eventId,
    sourceMode: 'backend',
    info: {
      ...info,
      imageAssets: normalizedAssets,
      source: mergeSourceMeta(info.source, { backendEventId: eventId }),
    },
  };
}

async function fetchAllBackendEvents() {
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    throw new Error('未登录，无法读取后端 events');
  }
  let page = 1;
  let totalPages = 1;
  const events = [];
  while (page <= totalPages) {
    const params = new URLSearchParams({
      page: String(page),
      limit: '100',
      status: 'all',
    });
    const resp = await apiGet(`/api/raver/events?${params.toString()}`, headers);
    const items = Array.isArray(resp?.data?.items) ? resp.data.items : [];
    events.push(...items);
    const nextTotalPages = Number(resp?.pagination?.totalPages || 1);
    totalPages = Number.isFinite(nextTotalPages) && nextTotalPages > 0 ? nextTotalPages : 1;
    page += 1;
  }
  return events;
}

async function fetchBackendEventYears() {
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    throw new Error('未登录，无法读取后端 events');
  }
  const resp = await apiGet('/api/raver/events/years', headers);
  const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
  const rows = Array.isArray(data?.years) ? data.years : [];
  return rows
    .map((row) => ({ year: Number(row?.year), count: Number(row?.count || 0) }))
    .filter((row) => Number.isInteger(row.year))
    .sort((a, b) => b.year - a.year);
}

async function fetchBackendEventsPage({ year, page = 1, limit = archiveLazyPageSize } = {}) {
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    throw new Error('未登录，无法读取后端 events');
  }
  const params = new URLSearchParams({
    page: String(Math.max(1, Number(page || 1))),
    limit: String(Math.max(1, Math.min(100, Number(limit || archiveLazyPageSize)))),
    status: 'all',
  });
  if (Number.isInteger(Number(year))) params.set('year', String(year));
  const resp = await apiGet(`/api/raver/events?${params.toString()}`, headers);
  const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
  const items = Array.isArray(data?.items) ? data.items : (Array.isArray(data?.events) ? data.events : []);
  const pagination = resp?.pagination || data?.pagination || {};
  return {
    items,
    pagination: {
      page: Number(pagination.page || page || 1),
      limit: Number(pagination.limit || limit || archiveLazyPageSize),
      total: Number(pagination.total || items.length),
      totalPages: Number(pagination.totalPages || 1),
    },
  };
}
