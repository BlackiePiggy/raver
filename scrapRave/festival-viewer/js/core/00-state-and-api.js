// Core module extracted from monolith (state/api)
const MONTHS_CN = ['','一月','二月','三月','四月','五月','六月','七月','八月','九月','十月','十一月','十二月'];
const TYPE_COLOR = { cover:'#f59e0b', luall:'#00f5c8', tt:'#ff2d78', other:'#6b6b8a' };
const DEFAULT_INFO_FILENAME = 'festival-info.json';

let allData = {};
let activeYear = null;
let archiveYearMeta = [];
let archiveYearLoadState = {};
let archiveLazyObserver = null;
let archiveLazyLoading = false;
let archiveLazyPageSize = 24;
let activeMonths = new Set();
let searchQuery = '';
let globalSearchQuery = '';
let activeCountryFilterKeys = new Set();
let activeEventTypeFilterKeys = new Set();
let lbImages = [];
let lbIndex = 0;
let rootDirHandle = null;
let importSearchResults = [];
let importJobId = null;
let importPollTimer = null;
let importProgressSince = 0;
let importLiveImportedKeys = new Set();
let importLiveQueue = [];
let importLiveImporting = false;
let importLiveInRunIndex = new Map();
let importLiveWrittenCount = 0;
let importLiveSkippedCount = 0;
let importLivePhotoCount = 0;
let importLivePhotoFailedCount = 0;
let importPersistStatusByKey = new Map();
let importPhotoFailureDetails = [];
let importLastProgress = null;
let cozeReviewState = null;
let cozeRowIdSeed = 1;
let posterReviewState = null;
let translateBatchState = null;
let activeEventEditPanel = null;
let addEventDraftFest = null;
let addEventModalInitialized = false;
let addEventSaveRunning = false;
let djProfileState = {
  djId: null,
  detail: null,
  sets: [],
  events: [],
  saving: false,
  translating: false,
  deleting: false,
  sourceReplace: null,
  avatarFile: null,
  avatarPreviewUrl: '',
};
const DJ_PROFILE_REPLACE_FIELDS = [
  { key: 'name', label: '名称', inputId: 'dj-edit-name' },
  { key: 'aliases', label: '别名', inputId: 'dj-edit-aliases' },
  { key: 'genres', label: 'GENRES', inputId: 'dj-edit-genres' },
  { key: 'bio', label: '简介(EN)', inputId: 'dj-edit-bio-en' },
  { key: 'country', label: '国家(EN)', inputId: 'dj-edit-country-en' },
  { key: 'countryEnFull', label: '国家(EN FULL)', inputId: 'dj-edit-country-en-full' },
  { key: 'website', label: '官网链接', inputId: 'dj-edit-website' },
  { key: 'spotifyUrl', label: 'Spotify URL', inputId: 'dj-edit-spotify-url' },
  { key: 'spotifyId', label: 'Spotify ID', inputId: 'dj-edit-spotify-id' },
  { key: 'spotifyFollowers', label: 'Spotify Followers', inputId: 'dj-edit-spotify-followers' },
  { key: 'appleMusicId', label: 'Apple Music ID', inputId: 'dj-edit-apple-music-id' },
  { key: 'instagramUrl', label: 'Instagram URL', inputId: 'dj-edit-instagram-url' },
  { key: 'facebookUrl', label: 'Facebook URL', inputId: 'dj-edit-facebook-url' },
  { key: 'twitterUrl', label: 'X / Twitter URL', inputId: 'dj-edit-twitter-url' },
  { key: 'youtubeUrl', label: 'YouTube URL', inputId: 'dj-edit-youtube-url' },
  { key: 'soundcloudUrl', label: 'SoundCloud URL', inputId: 'dj-edit-soundcloud-url' },
  { key: 'soundcloudId', label: 'SoundCloud ID', inputId: 'dj-edit-soundcloud-id' },
  { key: 'neteaseUrl', label: '网易云 URL', inputId: 'dj-edit-netease-url' },
  { key: 'qqMusicUrl', label: 'QQ 音乐 URL', inputId: 'dj-edit-qqmusic-url' },
  { key: 'sourceWikipedia', label: 'Wikipedia 来源', inputId: 'dj-edit-source-wikipedia' },
  { key: 'sourceWebsite', label: '官网来源', inputId: 'dj-edit-source-website' },
  { key: 'sourceSameAs', label: 'SameAs', inputId: 'dj-edit-source-sameas' },
  { key: 'trackCount', label: '发歌数量', inputId: 'dj-edit-track-count' },
  { key: 'playlistCount', label: '专辑数量', inputId: 'dj-edit-playlist-count' },
  { key: 'soundCloudFollowers', label: 'SoundCloud 粉丝数量', inputId: 'dj-edit-soundcloud-followers' },
  { key: 'soundCloudFavorites', label: 'SoundCloud 点赞数量', inputId: 'dj-edit-soundcloud-favorites' },
];
const POSTER_INFO_FIELDS = [
  'name_en',
  'name_zh',
  'start_date',
  'end_date',
  'country_en',
  'country_en_full',
  'country_zh',
  'city_en',
  'city_zh',
  'detail_address_en',
  'detail_address_zh',
];
const HANDLE_DB_NAME = 'rave_archive_fs_handles_v1';
const HANDLE_DB_STORE = 'kv';
const HANDLE_DB_ROOT_KEY = 'root_dir_handle';
const HANDLE_DB_META_KEY = 'root_dir_meta';
const DJ_SOURCE_CACHE_DB_NAME = 'rave_archive_dj_source_cache_v1';
const DJ_SOURCE_CACHE_DB_VERSION = 1;
const DJ_SOURCE_CACHE_STORE_QUERY = 'query_cache';
const DJ_SOURCE_CACHE_STORE_AVATAR = 'avatar_cache';
const DJ_SOURCE_CACHE_STORE_LOG = 'request_logs';
const DJ_SOURCE_CACHE_SCHEMA_VERSION = 1;
const DJ_SOURCE_CACHE_MAX_ITEMS_PER_SOURCE = 3;
const DJ_SOURCE_CACHE_DJ_INTERVAL_MS = 5000;
const DJ_SOURCE_CACHE_RETRY_INTERVAL_MS = 2000;
const DJ_SOURCE_CACHE_RETRY_TIMES = 1;
const EVENT_SYNC_LOOKUP_LIMIT = 200;
const EVENT_SYNC_LOOKUP_MAX_PAGES = 60;
const EVENT_IMAGE_CACHE_DIRNAME = '.raver_event_cache';
const EVENT_IMAGE_CACHE_EVENTS_DIRNAME = 'events';
const EVENT_IMAGE_CACHE_META_FILENAME = '.cache-meta.json';
const EVENT_IMAGE_PLACEHOLDER_DATA_URL = 'data:image/gif;base64,R0lGODlhAQABAAAAACw=';
const EVENT_IMAGE_ZONES = [
  { key: 'poster', label: 'Poster', backendType: 'other', defaultLabel: 'POSTER', order: 0 },
  { key: 'lineup', label: 'Lineup', backendType: 'luall', defaultLabel: 'LINE-UP', order: 1 },
  { key: 'timetable', label: 'Timetable', backendType: 'tt', defaultLabel: 'TIMETABLE', order: 2 },
  { key: 'cover', label: 'Cover', backendType: 'cover', defaultLabel: 'COVER', order: 3 },
  { key: 'map', label: 'Map', backendType: 'other', defaultLabel: 'MAP', order: 4 },
  { key: 'other', label: 'Other', backendType: 'other', defaultLabel: 'OTHER', order: 5 },
];
const EVENT_IMAGE_ZONE_MAP = Object.fromEntries(EVENT_IMAGE_ZONES.map((zone) => [zone.key, zone]));
const RAVER_AUTH_TOKEN_KEY = 'raver_viewer_auth_token';
const RAVER_AUTH_USER_KEY = 'raver_viewer_auth_user';
const DJ_LIBRARY_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
let currentAppPage = 'archive';
let appBootstrapped = false;
let countryFilterHandlersBound = false;
let eventTypeFilterHandlersBound = false;
let djLibraryState = {
  loaded: false,
  loading: false,
  loadError: '',
  allItems: [],
  allItemsComplete: false,
  filteredItems: [],
  pageItems: [],
  totalItems: 0,
  letterCounts: {},
  pageRequestSeq: 0,
  searchTimer: null,
  showAvatar: false,
  selectionMode: false,
  activeLetter: 'ALL',
  searchQuery: '',
  page: 1,
  perPage: 42,
  selectedIds: new Set(),
  translating: false,
};
let brandPageState = {
  loaded: false,
  loading: false,
  loadError: '',
  allItems: [],
  filteredItems: [],
  searchQuery: '',
  editorOpen: false,
  editorSaving: false,
  editorUploading: false,
  editorDeleting: false,
  editorDraft: null,
};
let eventBrandBindingState = {
  initialized: false,
  loading: false,
  saving: false,
  allRows: [],
  filteredRows: [],
  searchQuery: '',
  filterMode: 'all',
  viewMode: 'list',
  selectedEventIds: new Set(),
};
let rankingPageState = {
  loaded: false,
  loadingBoards: false,
  loadingEntries: false,
  loadError: '',
  boards: [],
  activeBoardId: '',
  activeYear: null,
  entries: [],
  boardEditorOpen: false,
  boardEditorSaving: false,
  boardEditorUploading: false,
  boardEditorDraft: null,
  entriesEditorOpen: false,
  entriesEditorSaving: false,
  entriesEditorRows: [],
  entriesEditorCatalog: [],
  entriesEditorYear: null,
  entriesEditorSearchTimer: null,
  entriesEditorSearchSeq: 0,
  entriesEditorSearchResults: [],
  entriesEditorSearchQuery: '',
  entriesEditorUnmatchedViewMode: 'all',
};
let newsPageState = {
  loaded: false,
  loading: false,
  loadError: '',
  allItems: [],
  filteredItems: [],
  searchQuery: '',
  sortMode: 'published_desc',
  groupMode: 'none',
  categoryFilter: 'all',
  sourceFilter: 'all',
  bindingFilter: 'all',
  brandFilter: 'all',
  editorOpen: false,
  editorSaving: false,
  editorUploading: false,
  editorDeleting: false,
  editorDraft: null,
  brandLookupById: {},
  eventLookupById: {},
  djLookupById: {},
  bindSearch: {
    dj: [],
    brand: [],
    event: [],
  },
};
let reviewPageState = {
  loaded: false,
  loading: false,
  saving: false,
  loadError: '',
  items: [],
  selectedId: '',
  selectedDetail: null,
  statusFilter: 'pending',
  processingStatusFilter: '',
  entityFilter: '',
  sourceFilter: 'content_submission',
  page: 1,
  pageSize: 50,
  total: 0,
  selectedIds: new Set(),
  selectedAllMatching: false,
  selectedAllMatchingMode: '',
  bulkSaving: false,
  pendingCount: 0,
  pendingCountsByType: {},
  reviewNotes: {},
  expandedNoteFields: new Set(),
  reason: '',
};
let rankingEntriesRowSeed = 1;
let djBilingualJobState = {
  jobId: '',
  since: 0,
  pollTimer: null,
  polling: false,
  running: false,
  initialSelectedIds: [],
  rows: [],
  lastProgressLogKey: '',
  lastProgressLogAt: 0,
};
let djEnrichmentJobState = {
  submitting: false,
  loadingJobs: false,
  lastJobId: '',
  lastAcceptedCount: 0,
  pollTimer: null,
  polling: false,
  lastJob: null,
  jobs: [],
};
let authState = {
  token: '',
  user: null,
  loggingIn: false,
};
let ttDJSourceCacheState = {
  running: false,
  stopRequested: false,
  startedAt: 0,
  total: 0,
  processed: 0,
  success: 0,
  failed: 0,
  skipped: 0,
};
const ttAvatarBlobObjectUrlMap = new Map();
const eventImageBlobObjectUrlMap = new Map();
const eventImageCacheMetaByEventId = new Map();

function getScraperApiBase() {
  if (window.SCRAPER_API_BASE && String(window.SCRAPER_API_BASE).trim()) {
    return String(window.SCRAPER_API_BASE).trim().replace(/\/+$/,'');
  }
  if (location.protocol === 'http:' || location.protocol === 'https:') return '';
  return 'http://127.0.0.1:8000';
}

function getRaverBffBase() {
  const explicit = String(window.RAVER_BFF_BASE || '').trim();
  if (explicit) return explicit.replace(/\/+$/, '');
  if (location.protocol === 'http:' || location.protocol === 'https:') {
    const origin = String(location.origin || '').trim();
    if (origin) return origin.replace(/\/+$/, '');
  }
  return 'http://127.0.0.1:3001';
}

async function apiPost(path, body, extraHeaders = null) {
  const url = `${getScraperApiBase()}${path}`;
  const headers = { 'Content-Type': 'application/json' };
  if (extraHeaders && typeof extraHeaders === 'object') {
    Object.assign(headers, extraHeaders);
  }
  const resp = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body || {})
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data.error || `请求失败 (${resp.status})`);
  return data;
}

async function apiPostForm(path, formData, extraHeaders = null) {
  const url = `${getScraperApiBase()}${path}`;
  const headers = {};
  if (extraHeaders && typeof extraHeaders === 'object') {
    Object.assign(headers, extraHeaders);
  }
  const resp = await fetch(url, {
    method: 'POST',
    headers,
    body: formData,
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data.error || `请求失败 (${resp.status})`);
  return data;
}

async function apiGet(path, extraHeaders = null) {
  const url = `${getScraperApiBase()}${path}`;
  const headers = {};
  if (extraHeaders && typeof extraHeaders === 'object') {
    Object.assign(headers, extraHeaders);
  }
  const resp = await fetch(url, { headers });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data.error || `请求失败 (${resp.status})`);
  return data;
}
