// Timetable import compare: candidate normalization and field resolution.
function ttGetTimetableBindStateFromFacade() {
  if (window.TimetableStateFacade && typeof window.TimetableStateFacade.bindState === 'function') {
    return window.TimetableStateFacade.bindState();
  }
  return ttDJBindState;
}

function ttGetImportStateFromFacade() {
  if (window.TimetableStateFacade && typeof window.TimetableStateFacade.importState === 'function') {
    return window.TimetableStateFacade.importState();
  }
  const bindState = ttGetTimetableBindStateFromFacade();
  return bindState && typeof bindState === 'object' ? (bindState.importState || null) : null;
}

function ttNormalizeImportCandidate(source, raw) {
  const toArray = (value) => (Array.isArray(value) ? value : []);
  const collectServiceProfiles = (candidate) => {
    const list = [];
    const directProfiles = [...toArray(candidate?.webProfiles), ...toArray(candidate?.web_profiles)];
    list.push(...directProfiles);

    const nestedRaw = candidate?.raw;
    list.push(...toArray(nestedRaw?.webProfiles));
    list.push(...toArray(nestedRaw?.web_profiles));
    list.push(...toArray(nestedRaw?.user?.webProfiles));
    list.push(...toArray(nestedRaw?.user?.web_profiles));

    return list.filter((item) => item && typeof item === 'object');
  };
  const pickServiceUrl = (profiles, services) => {
    const serviceSet = new Set(
      (Array.isArray(services) ? services : [services])
        .map((item) => String(item || '').trim().toLowerCase())
        .filter(Boolean)
    );
    for (const profile of profiles) {
      const service = String(profile?.service || profile?.type || '').trim().toLowerCase();
      const url = String(profile?.url || profile?.href || profile?.link || '').trim();
      if (service && serviceSet.has(service) && url) return url;
    }
    return '';
  };
  const pickFirstUrlByHosts = (urls, hosts) => {
    if (!Array.isArray(urls)) return '';
    const hostList = Array.isArray(hosts) ? hosts : [hosts];
    const found = urls.find((u) => {
      const normalized = String(u || '').toLowerCase();
      return hostList.some((host) => normalized.includes(String(host || '').toLowerCase()));
    });
    return String(found || '').trim();
  };
  const pickFirstWebsiteUrl = (urls) => {
    if (!Array.isArray(urls)) return '';
    const knownSocialHosts = [
      'instagram.com',
      'facebook.com',
      'fb.com',
      'twitter.com',
      'x.com',
      'soundcloud.com',
      'spotify.com',
      'spotify.link',
      'youtube.com',
      'youtu.be',
      'tiktok.com',
      'weibo.com',
      'bilibili.com',
    ];
    const found = urls.find((url) => {
      const normalized = String(url || '').trim();
      if (!normalized) return false;
      const lowered = normalized.toLowerCase();
      return !knownSocialHosts.some((host) => lowered.includes(host));
    });
    return String(found || '').trim();
  };
  const serviceProfiles = collectServiceProfiles(raw);
  const servicePersonalUrl = pickServiceUrl(serviceProfiles, ['personal']);
  const serviceInstagramUrl = pickServiceUrl(serviceProfiles, ['instagram']);
  const serviceTwitterUrl = pickServiceUrl(serviceProfiles, ['twitter', 'x']);
  const serviceFacebookUrl = pickServiceUrl(serviceProfiles, ['facebook']);
  const serviceYoutubeUrl = pickServiceUrl(serviceProfiles, ['youtube']);
  const serviceSpotifyUrl = pickServiceUrl(serviceProfiles, ['spotify']);
  const serviceSoundCloudUrl = pickServiceUrl(serviceProfiles, ['soundcloud']);
  if (source === 'spotify') {
    const genres = Array.isArray(raw?.genres) ? raw.genres.filter(Boolean) : [];
    const spotifyFollowersRaw = Number(raw?.followers ?? raw?.followersCount ?? raw?.followers_count ?? raw?.spotifyFollowers);
    const spotifyUrl = String(
      raw?.spotifyUrl
      || raw?.url
      || raw?.external_urls?.spotify
      || serviceSpotifyUrl
      || ''
    ).trim();
    const spotifyId = String(raw?.spotifyId || raw?.id || ttExtractSpotifyArtistId(spotifyUrl) || '').trim();
    let avatarUrl = String(raw?.imageUrl || raw?.avatarUrl || raw?.avatar_url || '').trim();
    if (!avatarUrl && Array.isArray(raw?.images)) {
      const firstImage = raw.images.find((img) => typeof img?.url === 'string' && img.url.trim());
      avatarUrl = String(firstImage?.url || '').trim();
    }
    return {
      source: 'spotify',
      sourceId: spotifyId,
      name: String(raw?.name || '').trim(),
      aliases: [],
      genres: Array.isArray(raw?.genres) ? raw.genres.filter(Boolean) : [],
      bio: genres.length ? `Genres: ${genres.join(', ')}` : '',
      country: '',
      website: String(raw?.website || servicePersonalUrl || '').trim(),
      spotifyId,
      spotifyUrl,
      spotifyFollowers: Number.isFinite(spotifyFollowersRaw) && spotifyFollowersRaw > 0
        ? Math.floor(spotifyFollowersRaw)
        : null,
      instagramUrl: '',
      facebookUrl: '',
      youtubeUrl: '',
      soundcloudUrl: '',
      soundcloudId: '',
      trackCount: null,
      playlistCount: null,
      soundCloudFollowers: null,
      soundCloudFavorites: null,
      twitterUrl: '',
      avatarUrl,
      raw,
    };
  }
  if (source === 'discogs') {
    const urls = Array.isArray(raw?.urls) ? raw.urls : [];
    const spotifyUrl = pickFirstUrlByHosts(urls, ['spotify.com', 'spotify.link']);
    const spotifyId = ttExtractSpotifyArtistId(spotifyUrl);
    return {
      source: 'discogs',
      sourceId: String(raw?.artistId || '').trim(),
      name: String(raw?.name || '').trim(),
      aliases: Array.isArray(raw?.aliases) ? raw.aliases : [],
      genres: [],
      bio: String(raw?.profile || '').trim(),
      country: '',
      website: pickFirstWebsiteUrl(urls),
      spotifyId,
      spotifyUrl,
      spotifyFollowers: null,
      instagramUrl: pickFirstUrlByHosts(urls, ['instagram.com']),
      facebookUrl: pickFirstUrlByHosts(urls, ['facebook.com', 'fb.com']),
      twitterUrl: pickFirstUrlByHosts(urls, ['twitter.com', 'x.com']),
      youtubeUrl: pickFirstUrlByHosts(urls, ['youtube.com', 'youtu.be']),
      soundcloudUrl: pickFirstUrlByHosts(urls, ['soundcloud.com']),
      soundcloudId: '',
      trackCount: null,
      playlistCount: null,
      soundCloudFollowers: null,
      soundCloudFavorites: null,
      avatarUrl: String(raw?.primaryImageUrl || raw?.thumbnailImageUrl || raw?.thumbUrl || raw?.coverImageUrl || '').trim(),
      raw,
    };
  }
  const trackCount = Number.isFinite(Number(raw?.trackCount ?? raw?.track_count))
    ? Math.max(0, Math.floor(Number(raw?.trackCount ?? raw?.track_count)))
    : 0;
  const playlistCount = Number.isFinite(Number(raw?.playlistCount ?? raw?.playlist_count))
    ? Math.max(0, Math.floor(Number(raw?.playlistCount ?? raw?.playlist_count)))
    : 0;
  const soundCloudFollowers = Number.isFinite(Number(raw?.soundCloudFollowers ?? raw?.followersCount ?? raw?.followers_count))
    ? Math.max(0, Math.floor(Number(raw?.soundCloudFollowers ?? raw?.followersCount ?? raw?.followers_count)))
    : 0;
  const soundCloudFavorites = Number.isFinite(Number(raw?.soundCloudFavorites ?? raw?.publicFavoritesCount ?? raw?.public_favorites_count))
    ? Math.max(0, Math.floor(Number(raw?.soundCloudFavorites ?? raw?.publicFavoritesCount ?? raw?.public_favorites_count)))
    : 0;
  const spotifyUrl = String(raw?.spotifyUrl || serviceSpotifyUrl || '').trim();
  const instagramUrl = String(raw?.instagramUrl || serviceInstagramUrl || '').trim();
  const facebookUrl = String(raw?.facebookUrl || serviceFacebookUrl || '').trim();
  const twitterUrl = String(raw?.twitterUrl || serviceTwitterUrl || '').trim();
  const youtubeUrl = String(raw?.youtubeUrl || serviceYoutubeUrl || '').trim();
  const website = String(raw?.website || servicePersonalUrl || '').trim();
  const soundcloudUrl = String(raw?.permalinkUrl || raw?.permalink_url || raw?.soundcloudUrl || serviceSoundCloudUrl || '').trim();
  const spotifyId = String(raw?.spotifyId || raw?.spotifyID || ttExtractSpotifyArtistId(spotifyUrl) || '').trim();
  return {
    source: 'soundcloud',
    sourceId: String(raw?.soundcloudid || raw?.soundcloudId || raw?.sourceId || raw?.id || '').trim(),
    soundcloudId: String(raw?.soundcloudid || raw?.soundcloudId || raw?.sourceId || raw?.id || '').trim(),
    name: String(raw?.name || raw?.username || '').trim(),
    aliases: Array.isArray(raw?.aliases) ? raw.aliases : [],
    genres: Array.isArray(raw?.genres) ? raw.genres : [],
    bio: String(raw?.description || raw?.bio || '').trim(),
    description: String(raw?.description || raw?.bio || '').trim(),
    city: String(raw?.city || '').trim(),
    country: String(raw?.country || '').trim(),
    website,
    spotifyId,
    spotifyUrl,
    spotifyFollowers: Number.isFinite(Number(raw?.spotifyFollowers)) ? Math.max(0, Math.floor(Number(raw?.spotifyFollowers))) : null,
    instagramUrl,
    facebookUrl,
    soundcloudUrl,
    twitterUrl,
    youtubeUrl,
    avatarUrl: String(raw?.avatarUrl || raw?.avatar_url || '').trim(),
    followersCount: soundCloudFollowers,
    soundCloudFollowers,
    trackCount,
    playlistCount,
    publicFavoritesCount: soundCloudFavorites,
    soundCloudFavorites,
    raw,
  };
}

function ttGetSelectedImportCandidate(source) {
  const st = ttGetImportStateFromFacade();
  if (!st) return null;
  const group = st.sources?.[source];
  if (!group || group.selectedIndex < 0) return null;
  return group.items[group.selectedIndex] || null;
}

function ttGetImportSourceFieldValue(fieldKey, sourceKey, manualDraft = null) {
  const manual = manualDraft || ttReadImportDraftFromForm();
  if (sourceKey === 'manual') return manual[fieldKey] ?? '';
  const selected = ttGetSelectedImportCandidate(sourceKey);
  if (!selected) return '';
  const value = selected[fieldKey];
  if (fieldKey === 'aliases' || fieldKey === 'genres') {
    const list = Array.isArray(value) ? value : [];
    return list.join(', ');
  }
  return String(value ?? '').trim();
}

function ttGetImportAvatarUrlFromSource(sourceKey) {
  if (!['spotify', 'discogs', 'soundcloud'].includes(sourceKey)) return '';
  const selected = ttGetSelectedImportCandidate(sourceKey);
  return String(selected?.avatarUrl || '').trim();
}

function ttGetImportAvatarDisplayUrlFromSource(sourceKey) {
  if (!['spotify', 'discogs', 'soundcloud'].includes(sourceKey)) return '';
  const selected = ttGetSelectedImportCandidate(sourceKey);
  return String(selected?.avatarDisplayUrl || selected?.avatarUrl || '').trim();
}

function ttCanSelectImportSource(sourceKey, fieldKey) {
  const st = ttGetImportStateFromFacade();
  if (!st) return false;
  if (sourceKey === 'manual') return true;
  if (!st.sourceEnabled?.[sourceKey]) return false;
  const selected = ttGetSelectedImportCandidate(sourceKey);
  if (!selected) return false;
  if (fieldKey === 'avatar') {
    return !!ttGetImportAvatarUrlFromSource(sourceKey);
  }
  return true;
}

function ttNormalizeImportSelections() {
  const st = ttGetImportStateFromFacade();
  if (!st) return;
  for (const field of TT_DJ_IMPORT_FIELDS) {
    const current = String(st.fieldSource?.[field.key] || 'manual');
    if (!ttCanSelectImportSource(current, field.key)) {
      st.fieldSource[field.key] = 'manual';
    }
  }
  const avatarChoice = String(st.avatarSource || 'manual');
  if (!ttCanSelectImportSource(avatarChoice, 'avatar')) {
    st.avatarSource = 'manual';
  }
}

function ttResolveImportFieldValue(fieldKey) {
  const st = ttGetImportStateFromFacade();
  const manual = ttReadImportDraftFromForm();
  if (!st) return manual[fieldKey] ?? '';
  let sourceChoice = String(st.fieldSource?.[fieldKey] || 'manual');
  if (!ttCanSelectImportSource(sourceChoice, fieldKey)) {
    sourceChoice = 'manual';
    st.fieldSource[fieldKey] = 'manual';
  }
  return ttGetImportSourceFieldValue(fieldKey, sourceChoice, manual);
}
