const importRuntimeStatePersist = (function resolveImportRuntimeStateForPersist() {
  const facade = window.ImportStateFacade;
  if (facade && typeof facade.runtimeState === 'function') return facade.runtimeState();
  return {
    get liveWrittenCount() {
      return importLiveWrittenCount;
    },
    get liveSkippedCount() {
      return importLiveSkippedCount;
    },
    get livePhotoCount() {
      return importLivePhotoCount;
    },
    get livePhotoFailedCount() {
      return importLivePhotoFailedCount;
    },
    get lastProgress() {
      return importLastProgress;
    },
  };
})();

function scrapeDateFromDatetime(dt) {
  const m = String(dt || '').match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : '';
}

function dedupeStrings(arr) {
  const seen = new Set();
  const out = [];
  for (const s of arr) {
    const v = String(s || '').trim();
    if (!v || seen.has(v)) continue;
    seen.add(v);
    out.push(v);
  }
  return out;
}

function extractCountryFromScraped(event) {
  const list = Array.isArray(event.jsonld) ? event.jsonld : [];
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    const t = item['@type'];
    if (t !== 'Event') continue;
    const addr = item.location?.address || {};
    const fromCountry = String(addr.addressCountry || '').trim();
    if (fromCountry) return fromCountry;
    const name = String(addr.name || '').trim();
    if (name) {
      const parts = name.split(',').map(v => v.trim()).filter(Boolean);
      if (parts.length) return parts[parts.length - 1];
    }
  }
  return '';
}

function sanitizeFolderToken(text, fallback) {
  const v = String(text || '')
    .replace(/[\\/:*?"<>|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return (v || fallback || 'unknown').slice(0, 70);
}

function sanitizePhotoLabel(label, fallback = 'photo') {
  const raw = String(label || '').trim().toLowerCase();
  const cleaned = raw
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60);
  return cleaned || fallback;
}

function guessPhotoExt(url) {
  try {
    const u = new URL(String(url || ''));
    const m = u.pathname.match(/\.([a-zA-Z0-9]{2,5})$/);
    if (!m) return 'jpg';
    const ext = m[1].toLowerCase();
    if (ext === 'jpeg') return 'jpg';
    return ext;
  } catch (_) {
    return 'jpg';
  }
}

async function downloadPhotoBlob(photoUrl) {
  const proxy = `${getScraperApiBase()}/api/proxy-image?url=${encodeURIComponent(photoUrl)}`;
  const resp = await fetch(proxy);
  if (!resp.ok) throw new Error(`下载失败 (${resp.status})`);
  return await resp.blob();
}

async function saveImportedPhotos(festHandle, event) {
  const photos = Array.isArray(event?.photos) ? event.photos : [];
  let saved = 0;
  let failed = 0;
  const failures = [];
  const used = new Map();

  for (let i = 0; i < photos.length; i += 1) {
    const p = photos[i] || {};
    const imageUrl = String(p.image_url || '').trim();
    if (!imageUrl) continue;

    const base = sanitizePhotoLabel(p.label || p.alt || `photo_${i + 1}`, 'photo');
    const serial = (used.get(base) || 0) + 1;
    used.set(base, serial);
    const nameCore = serial === 1 ? base : `${base}-${serial}`;
    const ext = guessPhotoExt(imageUrl);
    const filename = `${nameCore}.${ext}`;

    try {
      const blob = await downloadPhotoBlob(imageUrl);
      const fh = await festHandle.getFileHandle(filename, { create: true });
      const w = await fh.createWritable();
      await w.write(blob);
      await w.close();
      saved += 1;
    } catch (err) {
      failed += 1;
      failures.push({
        label: p.label || p.alt || '',
        image_url: imageUrl,
        error: err?.message || '下载失败'
      });
    }
  }
  return { saved, failed, failures };
}

function mapScrapedEventToInfo(event) {
  const startDate = scrapeDateFromDatetime(event.start_datetime);
  const endDate = scrapeDateFromDatetime(event.end_datetime) || startDate;
  const eventName = String(event.title || event.slug || '').trim();
  const location = String(event.venue || '').trim();
  const country = extractCountryFromScraped(event);
  const slug = String(event.slug || '').trim();
  const provider = 'festtimetable';
  const scrapedSocial = Array.isArray(event.social_links)
    ? event.social_links.map(x => ({ type: String(x?.type || '').toLowerCase(), url: x?.url, label: x?.text || x?.type || '' }))
    : [];
  const socialLinks = normalizeSocialLinks(scrapedSocial);
  const socialSet = new Set(socialLinks.map(s => s.url));
  const links = dedupeStrings([
    event.event_url,
    ...(Array.isArray(event.stream_platforms) ? event.stream_platforms.map(x => x?.url) : []),
    ...(Array.isArray(event.quick_links) ? event.quick_links.map(x => x?.url) : [])
  ]).filter(u => !socialSet.has(u));

  const lineup = [];
  const details = Array.isArray(event.timetable_details) ? event.timetable_details : [];
  for (const day of details) {
    const dayDate = String(day?.date_text || '').trim();
    for (const stage of (day?.stages || [])) {
      const stageName = String(stage?.stage_name || '').trim();
      for (const set of (stage?.sets || [])) {
        const musician = String(set?.artist || '').trim();
        if (!musician) continue;
        const d = scrapeDateFromDatetime(set?.start_datetime) || dayDate;
        const st = String(set?.start_time || '').trim();
        const et = String(set?.end_time || '').trim();
        const tm = st && et ? `${st}—${et}` : (st || et || '');
        lineup.push({
          musician,
          date: d,
          time: tm,
          stage: stageName,
          avatar: String(set?.artist_image_url || '').trim()
        });
      }
    }
  }

  const source = {
    provider,
    slug,
    eventUrl: String(event.event_url || '').trim(),
    photos: Array.isArray(event.photos) ? event.photos.map(p => ({ label: p.label, image_url: p.image_url })) : []
  };
  const festivalId = buildFestivalId(startDate, eventName, country);

  return {
    name: eventName,
    nameI18n: { en: eventName, zh: eventName },
    location,
    locationI18n: { en: location, zh: location },
    country,
    countryI18n: { en: country, zh: country },
    canceled: false,
    startDate,
    endDate,
    relatedLinks: links,
    socialLinks,
    lineup,
    festivalId,
    source
  };
}

function countTotalFestivals() {
  return Object.values(allData).reduce((sumYear, byMonth) => (
    sumYear + Object.values(byMonth).reduce((sumMonth, list) => sumMonth + list.length, 0)
  ), 0);
}

async function rebuildLibraryIndex(detail = '重建本地档案索引...', options = {}) {
  if (!rootDirHandle) return;
  await loadArchiveEventsFromBackend({
    preserveView: !!options.preserveView,
    detail: detail || '正在从后端重建活动索引...',
  });
}

function findFestivalByIdentity(festivalId) {
  const targetId = String(festivalId || '').trim();
  if (!targetId) return null;

  for (const yearData of Object.values(allData)) {
    for (const list of Object.values(yearData)) {
      for (const fest of list) {
        const festId = String(fest?.info?.festivalId || '').trim();
        if (targetId && festId && festId === targetId) return fest;
      }
    }
  }
  return null;
}

async function writeImportedFestival(event, inRunIndex = new Map()) {
  const imported = mapScrapedEventToInfo(event);
  let existingFest = null;
  if (imported.festivalId && inRunIndex.has(imported.festivalId)) {
    existingFest = inRunIndex.get(imported.festivalId);
  } else {
    existingFest = findFestivalByIdentity(imported.festivalId);
  }
  if (existingFest) {
    return {
      skipped: true,
      reason: 'duplicate_slug',
      festivalId: imported.festivalId || '',
      name: imported.name || existingFest.info?.name || existingFest.name || '',
      year: existingFest.year,
      folder: existingFest.folder,
      photosSaved: 0,
      photosFailed: 0,
      photoFailures: []
    };
  }
  const info = imported;

  const start = info.startDate || scrapeDateFromDatetime(event.start_datetime);
  const year = Number((start || '').slice(0,4)) || new Date().getFullYear();
  const month = Number((start || '').slice(5,7)) || 1;
  const folder = `${month}-${sanitizeFolderToken(info.name, event.slug)}-${sanitizeFolderToken(info.location || info.country, 'unknown')}`;
  const yearHandle = await rootDirHandle.getDirectoryHandle(String(year), { create: true });
  const festHandle = await yearHandle.getDirectoryHandle(folder, { create: true });

  const infoHandle = await festHandle.getFileHandle(DEFAULT_INFO_FILENAME, { create: true });
  const writable = await infoHandle.createWritable();
  await writable.write(JSON.stringify(info, null, 2));
  await writable.close();

  if (info.festivalId) {
    inRunIndex.set(info.festivalId, { year, folder, dirHandle: festHandle, info });
  }

  const photoRes = await saveImportedPhotos(festHandle, event);
  return {
    skipped: false,
    year,
    folder,
    name: info.name,
    festivalId: info.festivalId || '',
    photosSaved: Number(photoRes?.saved || 0),
    photosFailed: Number(photoRes?.failed || 0),
    photoFailures: Array.isArray(photoRes?.failures) ? photoRes.failures : []
  };
}

async function importScrapedEventsToLibrary(events, options = {}) {
  const preserveView = !!options.preserveView;
  const serverSkippedCount = Number(options.serverSkippedCount || 0);
  const imported = [];
  const skipped = [];
  const errors = [];
  const inRunIndex = new Map();
  setImportStatus('正在写入本地档案...');

  for (const event of events) {
    try {
      setImportPersistStatus(event, 'writing', '');
      const res = await writeImportedFestival(event, inRunIndex);
      if (res.skipped) {
        skipped.push(res);
        setImportPersistStatus(event, 'skipped', res.festivalId || 'slug 重复');
      } else {
        imported.push(res);
        appendPhotoFailureDetails(event, res.photoFailures || []);
        const photoFailMsg = Number(res.photosFailed || 0) > 0 ? `图片失败 ${res.photosFailed} 张` : (res.folder || '');
        setImportPersistStatus(event, 'saved', photoFailMsg);
      }
    } catch (e) {
      errors.push(`${event?.title || event?.slug || 'unknown'}: ${e.message}`);
      setImportPersistStatus(event, 'failed', e?.message || '未知错误');
    }
  }

  await rebuildLibraryIndex('重建本地档案索引...', { preserveView });

  if (errors.length) {
    const totalWrittenErr = imported.length + importRuntimeStatePersist.liveWrittenCount;
    const totalSkippedErr = skipped.length + importRuntimeStatePersist.liveSkippedCount + serverSkippedCount;
    setImportStatus(`入库完成：写入 ${totalWrittenErr}，重复 slug 跳过 ${totalSkippedErr}，失败 ${errors.length}。首个错误：${errors[0]}`, true);
  } else {
    const liveWritten = importRuntimeStatePersist.liveWrittenCount;
    const liveSkipped = importRuntimeStatePersist.liveSkippedCount + serverSkippedCount;
    const totalWritten = imported.length + liveWritten;
    const totalSkipped = skipped.length + liveSkipped;
    const photoTotal = imported.reduce((s, x) => s + Number(x.photosSaved || 0), 0) + importRuntimeStatePersist.livePhotoCount;
    const photoFailed = imported.reduce((s, x) => s + Number(x.photosFailed || 0), 0) + importRuntimeStatePersist.livePhotoFailedCount;
    if (!imported.length && !skipped.length && (liveWritten > 0 || liveSkipped > 0)) {
      const photoFailText = photoFailed > 0 ? `，图片失败 ${photoFailed} 张（见下方明细）` : '';
      setImportStatus(`入库完成：实时写入 ${liveWritten} 个，重复 slug 跳过 ${liveSkipped} 个，下载图片 ${photoTotal} 张${photoFailText}。`);
    } else {
      const photoFailText = photoFailed > 0 ? `，图片失败 ${photoFailed} 张（见下方明细）` : '';
      setImportStatus(`入库完成：写入 ${totalWritten} 个，重复 slug 跳过 ${totalSkipped} 个，下载图片 ${photoTotal} 张${photoFailText}。`);
    }
  }
  renderImportProgress(importRuntimeStatePersist.lastProgress);
}
