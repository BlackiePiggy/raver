function flattenQueuedEventImageUploads(queuedZoneUploads) {
  const rows = [];
  const source = queuedZoneUploads && typeof queuedZoneUploads === 'object' ? queuedZoneUploads : {};
  for (const zone of EVENT_IMAGE_ZONES) {
    const items = Array.isArray(source[zone.key]) ? source[zone.key] : [];
    for (const item of items) {
      if (!item?.file) continue;
      rows.push({
        zoneKey: zone.key,
        file: item.file,
        fileName: sanitizeEventImageFileName(item.fileName || item.file.name || ''),
      });
    }
  }
  return rows;
}

async function syncExistingEventCacheFileNames(eventId, renamePlans) {
  const plans = Array.isArray(renamePlans) ? renamePlans : [];
  for (const plan of plans) {
    const oldName = sanitizeEventImageFileName(plan?.oldFileName || '', '');
    const nextName = sanitizeEventImageFileName(plan?.newFileName || '', '');
    const remoteUrl = String(plan?.url || '').trim();
    if (!nextName) continue;
    if (oldName && oldName !== nextName) {
      const oldFile = await readEventCacheFile(eventId, oldName);
      if (oldFile) {
        await writeEventCacheFile(eventId, nextName, oldFile);
        await deleteEventCacheFile(eventId, oldName);
      }
      await removeEventCacheMetaEntry(eventId, oldName);
      releaseEventImageBlobObjectUrl(eventId, oldName);
    }
    if (remoteUrl) {
      await upsertEventCacheMetaEntry(eventId, nextName, remoteUrl);
    }
    releaseEventImageBlobObjectUrl(eventId, nextName);
  }
}

async function syncArchiveEventImagesToBackend({
  eventId,
  authHeaders,
  existingAssets,
  queuedZoneUploads,
  existingAssetDraft,
}) {
  const existingDraftRows = Array.isArray(existingAssetDraft) ? existingAssetDraft : null;
  const normalizedExistingBefore = parseBackendEventImageAssets(existingAssets)
    .map((item) => {
      const fileName = sanitizeEventImageFileName(
        item.fileName || pathBaseNameFromUrl(item.url) || `asset${guessImageExtFromNameOrUrl(item.url)}`
      );
      return { ...item, fileName };
    });
  const normalizedExisting = existingDraftRows
    ? existingDraftRows
        .map((row) => {
          const type = String(row?.type || '').trim().toLowerCase();
          const url = String(row?.url || '').trim();
          if (!type || !url) return null;
          const fileName = sanitizeEventImageFileName(
            row?.fileName || pathBaseNameFromUrl(url) || `asset${guessImageExtFromNameOrUrl(url)}`
          );
          if (!fileName) return null;
          const order = Number.isFinite(row?.order) ? Number(row.order) : undefined;
          const sort = Number.isFinite(row?.sort) ? Number(row.sort) : undefined;
          return {
            type,
            label: String(row?.label || '').trim() || type.toUpperCase(),
            url,
            source: String(row?.source || '').trim() || undefined,
            originalUrl: String(row?.originalUrl || '').trim() || undefined,
            fileName,
            ...(order !== undefined ? { order } : {}),
            ...(sort !== undefined ? { sort } : {}),
          };
        })
        .filter(Boolean)
    : normalizedExistingBefore;

  if (existingDraftRows && existingDraftRows.length) {
    const renamePlans = [];
    for (const draftRow of existingDraftRows) {
      const url = String(draftRow?.url || '').trim();
      if (!url) continue;
      const oldFileName = sanitizeEventImageFileName(
        draftRow?._oldFileName || draftRow?.oldFileName || '',
        ''
      );
      const newFileName = sanitizeEventImageFileName(
        draftRow?.fileName || pathBaseNameFromUrl(url) || `asset${guessImageExtFromNameOrUrl(url)}`,
        ''
      );
      if (!newFileName) continue;
      renamePlans.push({
        oldFileName,
        newFileName,
        url,
      });
    }
    await syncExistingEventCacheFileNames(eventId, renamePlans);
  }

  if (existingDraftRows) {
    const nextUrlKeys = new Set(
      normalizedExisting
        .map((item) => String(item?.url || '').trim().toLowerCase())
        .filter(Boolean)
    );
    const removedAssets = normalizedExistingBefore.filter((item) => {
      const key = String(item?.url || '').trim().toLowerCase();
      if (!key) return false;
      return !nextUrlKeys.has(key);
    });
    for (const asset of removedAssets) {
      const oldName = sanitizeEventImageFileName(
        asset?.fileName || pathBaseNameFromUrl(asset?.url || '') || '',
        ''
      );
      if (!oldName) continue;
      await deleteEventCacheFile(eventId, oldName);
      await removeEventCacheMetaEntry(eventId, oldName);
      releaseEventImageBlobObjectUrl(eventId, oldName);
    }
  }

  const zoneSortCounters = Object.fromEntries(EVENT_IMAGE_ZONES.map((zone) => [zone.key, 0]));
  normalizedExisting.forEach((item) => {
    const zoneKey = inferEventImageZoneFromAsset(item);
    zoneSortCounters[zoneKey] = (zoneSortCounters[zoneKey] || 0) + 1;
  });

  const assetsByKey = new Map();
  for (const asset of normalizedExisting) {
    const type = String(asset.type || '').trim().toLowerCase();
    const fileName = sanitizeEventImageFileName(asset.fileName || '');
    if (!type || !fileName) continue;
    const key = `${type}::${fileName.toLowerCase()}`;
    if (!assetsByKey.has(key)) {
      assetsByKey.set(key, { ...asset, type, fileName });
    }
  }

  let uploaded = 0;
  let reused = 0;
  let failed = 0;
  const failedFiles = [];
  const queuedRows = flattenQueuedEventImageUploads(queuedZoneUploads);

  for (const row of queuedRows) {
    const zoneKey = normalizeEventImageZoneKey(row.zoneKey);
    const type = backendTypeForImageZone(zoneKey);
    const fileName = sanitizeEventImageFileName(
      row.fileName || row.file?.name || `${zoneKey}${guessImageExtFromNameOrUrl('', row.file?.type || '')}`
    );
    const dedupeKey = `${type}::${fileName.toLowerCase()}`;

    if (assetsByKey.has(dedupeKey)) {
      reused += 1;
      continue;
    }

    try {
      const form = new FormData();
      form.append('image', row.file, fileName || 'image.jpg');
      form.append('eventId', eventId);
      form.append('usage', type);
      const uploadResp = await apiPostForm('/api/raver/events/upload-image', form, authHeaders);
      const uploadedData = uploadResp?.data || uploadResp || {};
      const uploadedUrl = String(uploadedData?.url || '').trim();
      if (!uploadedUrl) throw new Error('上传成功但未返回图片 URL');

      zoneSortCounters[zoneKey] = (zoneSortCounters[zoneKey] || 0) + 1;
      const order = Number(EVENT_IMAGE_ZONE_MAP[zoneKey]?.order ?? 99);
      const sort = zoneSortCounters[zoneKey];
      const asset = {
        type,
        label: defaultImageLabelForZone(zoneKey),
        url: uploadedUrl,
        source: 'archive-local',
        fileName,
        order,
        sort,
      };
      assetsByKey.set(dedupeKey, asset);
      uploaded += 1;

      try {
        await writeEventCacheFile(eventId, fileName, row.file);
        await upsertEventCacheMetaEntry(eventId, fileName, uploadedUrl);
        releaseEventImageBlobObjectUrl(eventId, fileName);
      } catch (_error) {
        // cache write failure does not block DB update
      }
    } catch (error) {
      failed += 1;
      failedFiles.push({
        fileName,
        message: String(error?.message || 'unknown upload error'),
      });
    }
  }

  const assets = Array.from(assetsByKey.values()).sort((a, b) => {
    const ao = Number.isFinite(a.order) ? Number(a.order) : 99;
    const bo = Number.isFinite(b.order) ? Number(b.order) : 99;
    if (ao !== bo) return ao - bo;
    const as = Number.isFinite(a.sort) ? Number(a.sort) : 99;
    const bs = Number.isFinite(b.sort) ? Number(b.sort) : 99;
    if (as !== bs) return as - bs;
    return String(a.fileName || '').localeCompare(String(b.fileName || ''));
  });

  return { assets, uploaded, reused, failed, failedFiles };
}

async function syncFestivalPayloadToBackend(fest, payload, options = {}) {
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    throw new Error('未登录或登录已失效，请先登录后再保存');
  }

  const archiveFestivalId = String(payload?.festivalId || '').trim();
  if (!archiveFestivalId) {
    throw new Error('festivalId 为空，无法同步到后端 events');
  }

  const source = mergeSourceMeta(payload?.source, fest?.info?.source);
  const backendEventIdFromSource = String(source?.backendEventId || source?.backend_event_id || '').trim();

  let existingEvent = null;
  if (backendEventIdFromSource) {
    try {
      const detailResp = await apiGet(`/api/raver/events/${encodeURIComponent(backendEventIdFromSource)}`, authHeaders);
      existingEvent = detailResp?.data || detailResp || null;
    } catch (_error) {
      existingEvent = null;
    }
  }
  if (!existingEvent) {
    existingEvent = await findBackendEventByArchiveFestivalId(archiveFestivalId, authHeaders);
  }

  const eventPayload = buildBackendEventUpsertPayload(fest, payload);
  if (!String(eventPayload.name || '').trim()) {
    throw new Error('活动名称为空，无法同步到后端 events');
  }
  if (!String(eventPayload.startDate || '').trim() || !String(eventPayload.endDate || '').trim()) {
    throw new Error('活动开始/结束日期为空，无法同步到后端 events');
  }

  let savedEvent = null;
  let created = false;
  if (existingEvent?.id) {
    const updateResp = await apiPost(
      `/api/raver/events/${encodeURIComponent(String(existingEvent.id))}/update`,
      eventPayload,
      authHeaders
    );
    savedEvent = updateResp?.data || updateResp || null;
  } else {
    const createResp = await apiPost('/api/raver/events', eventPayload, authHeaders);
    savedEvent = createResp?.data || createResp || null;
    created = true;
  }

  const eventId = String(savedEvent?.id || existingEvent?.id || '').trim();
  if (!eventId) {
    throw new Error('后端保存成功但未返回 eventId');
  }

  const imageSync = await syncArchiveEventImagesToBackend({
    eventId,
    authHeaders,
    existingAssets: savedEvent?.imageAssets ?? existingEvent?.imageAssets ?? null,
    queuedZoneUploads: options?.imageZoneDraft || null,
    existingAssetDraft: options?.existingAssetDraft || null,
  });
  const primaryImageUrls = pickPrimaryEventImageUrls(imageSync.assets);

  const imagePatchPayload = {
    imageAssets: imageSync.assets,
    coverImageUrl: primaryImageUrls.coverImageUrl,
    lineupImageUrl: primaryImageUrls.lineupImageUrl,
  };
  const imagePatchResp = await apiPost(
    `/api/raver/events/${encodeURIComponent(eventId)}/update`,
    imagePatchPayload,
    authHeaders
  );
  const patchedEvent = imagePatchResp?.data || imagePatchResp || savedEvent;

  return {
    eventId,
    created,
    uploadedImages: imageSync.uploaded,
    reusedImages: imageSync.reused,
    failedImages: imageSync.failed,
    failedFiles: imageSync.failedFiles,
    event: patchedEvent,
  };
}

async function persistFestivalPayload(fest, payload, options = {}) {
  payload = payload || {};
  const hasPayloadCityField = Object.prototype.hasOwnProperty.call(payload, 'cityI18n')
    || Object.prototype.hasOwnProperty.call(payload, 'city');
  const hasPayloadCountryField = Object.prototype.hasOwnProperty.call(payload, 'countryI18n')
    || Object.prototype.hasOwnProperty.call(payload, 'country');
  const hasPayloadManualLocationField = Object.prototype.hasOwnProperty.call(payload, 'manualLocation');
  payload.canceled = normalizeBoolFlag(payload.canceled, fest?.info?.canceled);
  payload.nameI18n = normalizeBiTextValue(payload.nameI18n ?? payload.name, fest?.info?.name || '');
  const detailAddressBi = normalizeBiTextValue(
    payload?.manualLocation?.detailAddressI18n
      ?? payload?.detailAddressI18n
      ?? '',
    ''
  );
  payload.cityI18n = normalizeBiTextValue(
    payload.cityI18n ?? payload.city,
    hasPayloadCityField ? '' : (fest?.info?.cityI18n ?? fest?.info?.city ?? '')
  );
  payload.countryI18n = normalizeCountryBiTextValue(
    payload.countryI18n ?? payload.country,
    hasPayloadCountryField ? '' : (fest?.info?.countryI18n ?? fest?.info?.country ?? '')
  );
  payload.name = String(payload.name || payload.nameI18n.en || payload.nameI18n.zh || '').trim();
  payload.city = String(payload.city || payload.cityI18n.zh || payload.cityI18n.en || '').trim();
  payload.country = String(payload.country || payload.countryI18n.en || payload.countryI18n.zh || '').trim();
  if (!hasPayloadManualLocationField && !payload.manualLocation && (detailAddressBi.en || detailAddressBi.zh)) {
    const formattedZh = [payload.countryI18n.zh || payload.countryI18n.enFull || payload.countryI18n.en, payload.cityI18n.zh || payload.cityI18n.en, detailAddressBi.zh || detailAddressBi.en]
      .filter(Boolean)
      .join(' · ');
    const formattedEn = [payload.countryI18n.enFull || payload.countryI18n.en || payload.countryI18n.zh, payload.cityI18n.en || payload.cityI18n.zh, detailAddressBi.en || detailAddressBi.zh]
      .filter(Boolean)
      .join(' · ');
    payload.manualLocation = {
      detailAddressI18n: detailAddressBi,
      formattedAddressI18n: normalizeBiTextValue({ en: formattedEn, zh: formattedZh }, formattedZh || formattedEn),
      selectedAt: new Date().toISOString(),
    };
  }
  payload.source = mergeSourceMeta(payload.source, fest.info.source);
  payload.festivalId = buildFestivalId(
    payload.startDate,
    payload.nameI18n?.en || payload.name,
    payload.countryI18n?.en || payload.country
  ) || String(payload.festivalId || fest.info.festivalId || '').trim();
  payload.relatedLinks = dedupeStrings(payload.relatedLinks || []);
  payload.socialLinks = normalizeSocialLinks(payload.socialLinks || []);
  payload.lineupArtists = buildEventLineupArtistsFromArchive(
    (Array.isArray(payload.lineupArtists) && payload.lineupArtists.length)
      ? payload.lineupArtists
      : (fest?.info?.lineupArtists ?? payload.lineupArtists ?? []),
    payload.lineup || []
  );
  const split = splitReferenceLinks(payload.relatedLinks, payload.socialLinks);
  payload.relatedLinks = split.refs;
  payload.socialLinks = split.social;
  payload.lineup = dedupeLineupEntries(payload.lineup || []);
  payload.stageOrder = normalizeStageOrderForSync(
    payload.stageOrder ?? payload.stage_order,
    fest?.info?.stageOrder ?? deriveStageOrderFromLineupForSync(payload.lineup)
  );

  let handle = fest.infoHandle;
  if (!handle && fest?.dirHandle) {
    handle = await fest.dirHandle.getFileHandle(DEFAULT_INFO_FILENAME, { create: true });
    fest.infoHandle = handle;
    fest.infoFilename = DEFAULT_INFO_FILENAME;
  }
  if (!handle && rootDirHandle) {
    const tempEventId = String(payload?.source?.backendEventId || fest?.backendEventId || payload?.festivalId || 'event-cache')
      .replace(/[^a-zA-Z0-9-_]/g, '')
      .slice(0, 80);
    const eventCacheDir = await getEventCacheEventDirHandle(tempEventId || 'event-cache', true);
    if (eventCacheDir) {
      handle = await eventCacheDir.getFileHandle(DEFAULT_INFO_FILENAME, { create: true });
      fest.infoHandle = handle;
      fest.infoFilename = `${EVENT_IMAGE_CACHE_DIRNAME}/${EVENT_IMAGE_CACHE_EVENTS_DIRNAME}/${tempEventId || 'event-cache'}/${DEFAULT_INFO_FILENAME}`;
    }
  }
  if (handle) {
    const granted = await verifyPermission(handle, true);
    if (!granted) throw new Error('没有获得写入权限');
    const writable = await handle.createWritable();
    await writable.write(JSON.stringify(payload, null, 2));
    await writable.close();
  }

  fest.info = normalizeFestivalInfo(payload, fest.info);
  fest.name = fest.info.name || fest.name;
  fest.location = fest.info.location || fest.location;

  let backendSyncResult = null;
  try {
    backendSyncResult = await syncFestivalPayloadToBackend(fest, payload, options);
  } catch (error) {
    throw new Error(`本地 JSON 已保存，但后端同步失败：${error?.message || error}`);
  }

  if (backendSyncResult?.eventId) {
    const nextSource = mergeSourceMeta(
      { ...(payload.source || {}), backendEventId: backendSyncResult.eventId },
      fest.info.source
    );
    const prevBackendId = String(payload?.source?.backendEventId || '').trim();
    payload.source = nextSource;
    if (prevBackendId !== backendSyncResult.eventId && handle) {
      const writable2 = await handle.createWritable();
      await writable2.write(JSON.stringify(payload, null, 2));
      await writable2.close();
      fest.info = normalizeFestivalInfo(payload, fest.info);
      fest.name = fest.info.name || fest.name;
      fest.location = fest.info.location || fest.location;
    }
  }

  if (backendSyncResult?.event) {
    patchFestivalFromBackendEvent(fest, backendSyncResult.event);
  }

  return backendSyncResult;
}
