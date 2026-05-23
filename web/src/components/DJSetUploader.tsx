'use client';

import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import Image from 'next/image';
import { getApiUrl } from '@/lib/config';
import { SpotifyAPI } from '@/lib/music-api';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';

interface DJItem {
  id: string;
  name: string;
}

interface TrackInput {
  position: number;
  startTime: string;
  endTime?: string;
  title: string;
  artist: string;
  status: 'released' | 'id' | 'remix' | 'edit';
  spotifyUrl?: string;
  spotifyId?: string;
  spotifyUri?: string;
  neteaseUrl?: string;
  neteaseId?: string;
}

interface SpotifyResultItem {
  id: string;
  name: string;
  artist: string;
  album: string;
  url: string;
  uri?: string;
}

interface TrackSearchState {
  loading: boolean;
  keyword: string;
  spotifyResults: SpotifyResultItem[];
  error: string;
}

interface SpotifyAuthState {
  loading: boolean;
  authenticated: boolean;
  hasCredentials: boolean;
  message: string;
  authUrl: string;
}

interface ParsedVideo {
  platform: 'youtube' | 'bilibili';
  videoId: string;
  embedUrl: string;
}

const emptySearchState: TrackSearchState = {
  loading: false,
  keyword: '',
  spotifyResults: [],
  error: '',
};

const emptySpotifyAuth: SpotifyAuthState = {
  loading: true,
  authenticated: false,
  hasCredentials: false,
  message: '检查中...',
  authUrl: 'https://developer.spotify.com/dashboard',
};

const parseNeteaseIdFromUrl = (url: string): string | undefined => {
  if (!url) {
    return undefined;
  }

  const hashMatch = url.match(/song\?id=(\d+)/);
  if (hashMatch) {
    return hashMatch[1];
  }

  const plainMatch = url.match(/id=(\d+)/);
  if (plainMatch) {
    return plainMatch[1];
  }

  return undefined;
};

const parseTimeParts = (time: string): number | null => {
  const trimmed = time.trim();
  if (!trimmed) {
    return null;
  }

  const parts = trimmed.split(':').map((item) => Number(item.trim()));
  if (parts.some((value) => Number.isNaN(value))) {
    return null;
  }

  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }

  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  return null;
};

const formatSecondsToTime = (seconds: number): string => {
  const safe = Math.max(0, Math.floor(seconds));
  const h = Math.floor(safe / 3600);
  const m = Math.floor((safe % 3600) / 60);
  const s = safe % 60;

  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
};

const inferTrackStatus = (text: string): TrackInput['status'] => {
  const normalized = text.toLowerCase();
  if (
    normalized.includes('unreleased') ||
    /\bid\b/.test(normalized) ||
    normalized.includes('accidentally presses stop')
  ) {
    return 'id';
  }
  if (
    normalized.includes(' edit') ||
    normalized.includes('(edit') ||
    normalized.includes(' x ') ||
    normalized.includes(' vs ')
  ) {
    return 'edit';
  }
  if (
    normalized.includes('remix') ||
    normalized.includes(' flip') ||
    normalized.includes(' vip')
  ) {
    return 'remix';
  }
  return 'released';
};

const parseTrackLine = (
  line: string
): { startSeconds: number; title: string; artist: string; status: TrackInput['status'] } | null => {
  const cleaned = line.trim();
  if (!cleaned) {
    return null;
  }

  const match = cleaned.match(/^(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*(.+)$/);
  if (!match) {
    return null;
  }

  const startSeconds = parseTimeParts(match[1]);
  if (startSeconds === null) {
    return null;
  }

  const details = match[2].trim();
  const splitIndex = details.indexOf(' - ');
  const artist = splitIndex > -1 ? details.slice(0, splitIndex).trim() : 'Unknown';
  const title = splitIndex > -1 ? details.slice(splitIndex + 3).trim() : details;

  return {
    startSeconds,
    title,
    artist,
    status: inferTrackStatus(details),
  };
};

const parseVideoUrl = (url: string): ParsedVideo | null => {
  const youtubePatterns = [
    /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
  ];

  for (const pattern of youtubePatterns) {
    const match = url.match(pattern);
    if (match) {
      const videoId = match[1];
      return {
        platform: 'youtube',
        videoId,
        embedUrl: `https://www.youtube.com/embed/${videoId}`,
      };
    }
  }

  const bilibiliMatch = url.match(/bilibili\.com\/video\/(BV[a-zA-Z0-9]+)/);
  if (bilibiliMatch) {
    const videoId = bilibiliMatch[1];
    return {
      platform: 'bilibili',
      videoId,
      embedUrl: `https://player.bilibili.com/player.html?bvid=${videoId}`,
    };
  }

  return null;
};

function SectionCard({
  step,
  title,
  description,
  children,
  badge,
  active = false,
}: {
  step: string;
  title: string;
  description: string;
  children: ReactNode;
  badge?: string;
  active?: boolean;
}) {
  return (
    <section className={`rounded-xl border p-6 ${active ? 'border-bg-tertiary bg-bg-secondary' : 'border-bg-tertiary bg-bg-secondary'}`}>
      <div className="mb-5 flex items-start justify-between gap-4">
        <div>
          <p className="mb-2 text-xs font-medium uppercase tracking-[0.2em] text-primary-blue">{step}</p>
          <h2 className="text-xl font-semibold text-text-primary">{title}</h2>
          <p className="mt-1 text-sm leading-6 text-text-secondary">{description}</p>
        </div>
        {badge && (
          <span className="shrink-0 rounded-full border border-bg-primary bg-bg-tertiary px-3 py-1 text-xs text-text-secondary">
            {badge}
          </span>
        )}
      </div>
      {children}
    </section>
  );
}

export default function DJSetUploader() {
  const router = useRouter();
  const { user, token, isLoading } = useAuth();
  const [djs, setDjs] = useState<DJItem[]>([]);
  const [selectedDjIds, setSelectedDjIds] = useState<string[]>([]);
  const [djSearchKeyword, setDjSearchKeyword] = useState('');
  const [customDJName, setCustomDJName] = useState('');
  const [addingCustomDj, setAddingCustomDj] = useState(false);
  const [title, setTitle] = useState('');
  const [videoUrl, setVideoUrl] = useState('');
  const [thumbnailUrl, setThumbnailUrl] = useState('');
  const [description, setDescription] = useState('');
  const [previewMessage, setPreviewMessage] = useState('');
  const [previewLoading, setPreviewLoading] = useState(false);
  const [thumbnailUploading, setThumbnailUploading] = useState(false);
  const [thumbnailDragging, setThumbnailDragging] = useState(false);
  const [bulkTrackText, setBulkTrackText] = useState('');
  const [bulkParseMessage, setBulkParseMessage] = useState('');
  const [tracks, setTracks] = useState<TrackInput[]>([]);
  const [trackSearch, setTrackSearch] = useState<Record<number, TrackSearchState>>({});
  const [spotifyAuth, setSpotifyAuth] = useState<SpotifyAuthState>(emptySpotifyAuth);
  const [loading, setLoading] = useState(false);
  const [activeStep, setActiveStep] = useState(1);

  const parsedVideo = useMemo(() => parseVideoUrl(videoUrl), [videoUrl]);
  const readyToSubmit = Boolean(title.trim() && videoUrl.trim() && selectedDjIds.length > 0 && thumbnailUrl.trim());
  const steps = useMemo(
    () => [
      { id: 1, title: '基础信息', subtitle: '标题、封面和简介', done: Boolean(title.trim() && thumbnailUrl.trim()) },
      { id: 2, title: 'DJ 与视频', subtitle: '关联 DJ 并确认视频来源', done: Boolean(selectedDjIds.length > 0 && videoUrl.trim()) },
      { id: 3, title: '歌曲标记', subtitle: '批量导入并逐首校对曲目', done: tracks.length > 0 },
      { id: 4, title: '检查提交', subtitle: '确认信息无误后创建 Set', done: readyToSubmit },
    ],
    [title, thumbnailUrl, selectedDjIds.length, videoUrl, tracks.length, readyToSubmit]
  );
  const completionCount = steps.filter((step) => step.done).length;
  const progressPercent = Math.round((completionCount / steps.length) * 100);
  const selectedDjNames = useMemo(
    () =>
      selectedDjIds
        .map((id) => djs.find((dj) => dj.id === id)?.name || id)
        .filter((name) => Boolean(name)),
    [selectedDjIds, djs]
  );
  const primaryDjName = selectedDjNames[0] || '未选择';
  const filteredDJs = useMemo(() => {
    const keyword = djSearchKeyword.trim().toLowerCase();
    if (!keyword) {
      return [];
    }
    return djs.filter((dj) => dj.name.toLowerCase().includes(keyword)).slice(0, 120);
  }, [djs, djSearchKeyword]);

  const loadDJs = useCallback(async () => {
    try {
      const response = await fetch(getApiUrl('/djs?limit=400&sortBy=followerCount&live=false'));
      const data = await response.json();
      const list: DJItem[] = Array.isArray(data?.djs)
        ? data.djs.map((item: any) => ({ id: item.id, name: item.name }))
        : [];
      setDjs(list);
    } catch (error) {
      console.error('Load DJs error:', error);
    }
  }, []);

  const addSelectedDj = (id: string) => {
    setSelectedDjIds((prev) => (prev.includes(id) ? prev : [...prev, id]));
  };

  const removeSelectedDj = (id: string) => {
    setSelectedDjIds((prev) => prev.filter((item) => item !== id));
  };

  const addCustomDjToLibrary = async () => {
    const trimmed = customDJName.trim();
    if (!trimmed) {
      setPreviewMessage('请输入 DJ 名称');
      return;
    }

    setAddingCustomDj(true);
    try {
      const response = await fetch(getApiUrl('/djs/ensure'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ names: [trimmed] }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.error || '添加自定义 DJ 失败');
      }

      const ensured = Array.isArray(data.djs) ? data.djs[0] : null;
      if (!ensured?.id) {
        throw new Error('未能创建或找到该 DJ');
      }

      setDjs((prev) => {
        if (prev.some((dj) => dj.id === ensured.id)) {
          return prev;
        }
        return [{ id: ensured.id, name: ensured.name || trimmed }, ...prev];
      });
      setSelectedDjIds((prev) => (prev.includes(ensured.id) ? prev : [...prev, ensured.id]));
      setCustomDJName('');
      setPreviewMessage(`已添加并选中 DJ：${ensured.name || trimmed}`);
    } catch (error) {
      setPreviewMessage(error instanceof Error ? error.message : '添加自定义 DJ 失败');
    } finally {
      setAddingCustomDj(false);
    }
  };

  const checkSpotifyAuth = useCallback(async () => {
    setSpotifyAuth((prev) => ({ ...prev, loading: true }));
    try {
      const status = await SpotifyAPI.getAuthStatus();
      setSpotifyAuth({
        loading: false,
        authenticated: Boolean(status.authenticated),
        hasCredentials: Boolean(status.hasCredentials),
        message: status.message || '未知状态',
        authUrl: status.authUrl || 'https://developer.spotify.com/dashboard',
      });
    } catch (error) {
      setSpotifyAuth({
        loading: false,
        authenticated: false,
        hasCredentials: false,
        message: error instanceof Error ? error.message : '无法获取 Spotify 鉴权状态',
        authUrl: 'https://developer.spotify.com/dashboard',
      });
    }
  }, []);

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
      return;
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    if (!user) {
      return;
    }
    loadDJs();
    checkSpotifyAuth();
  }, [loadDJs, checkSpotifyAuth, user]);

  const fetchVideoPreview = async (url: string) => {
    if (!url) {
      setPreviewMessage('请先输入视频链接');
      return;
    }

    setPreviewLoading(true);
    setPreviewMessage('正在提取网页信息...');

    try {
      const response = await fetch(getApiUrl(`/dj-sets/preview?videoUrl=${encodeURIComponent(url)}`));
      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        throw new Error(data.error || '提取视频信息失败');
      }

      if (data.title) {
        setTitle(data.title);
      }
      if (data.description) {
        setDescription(data.description);
      }

      setPreviewMessage(data.title ? '已自动提取标题和介绍' : '已解析视频链接，但未提取到标题');
    } catch (error) {
      setPreviewMessage(error instanceof Error ? error.message : '提取失败，请手动填写');
    } finally {
      setPreviewLoading(false);
    }
  };

  const uploadThumbnail = async (file: File) => {
    if (!token) {
      alert('请先登录后再上传封面');
      router.push('/login');
      return;
    }

    setThumbnailUploading(true);
    try {
      const formData = new FormData();
      formData.append('image', file);

      const response = await fetch(getApiUrl('/dj-sets/upload-thumbnail'), {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
        },
        body: formData,
      });

      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.error || '封面上传失败');
      }

      setThumbnailUrl(data.url || '');
      setPreviewMessage('封面上传成功');
    } catch (error) {
      setPreviewMessage(error instanceof Error ? error.message : '封面上传失败');
    } finally {
      setThumbnailUploading(false);
    }
  };

  const handlePasteAndExtract = async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (!text) {
        setPreviewMessage('剪贴板为空');
        return;
      }
      setVideoUrl(text.trim());
      await fetchVideoPreview(text.trim());
    } catch (error) {
      setPreviewMessage(error instanceof Error ? `无法读取剪贴板：${error.message}` : '无法读取剪贴板');
    }
  };

  const addTrack = () => {
    setTracks([
      ...tracks,
      {
        position: tracks.length + 1,
        startTime: '',
        title: '',
        artist: '',
        status: 'released',
      },
    ]);
  };

  const updateTrack = (index: number, field: keyof TrackInput, value: string) => {
    const newTracks = [...tracks];
    const nextTrack: TrackInput = { ...newTracks[index], [field]: value };

    if (field === 'neteaseUrl') {
      nextTrack.neteaseId = parseNeteaseIdFromUrl(value);
    }

    newTracks[index] = nextTrack;
    setTracks(newTracks);

    if (field === 'title' || field === 'artist') {
      const keyword = `${nextTrack.artist} ${nextTrack.title}`.trim();
      setTrackSearch((prev) => ({
        ...prev,
        [index]: {
          ...(prev[index] || emptySearchState),
          keyword,
          error: '',
        },
      }));
    }
  };

  const removeTrack = (index: number) => {
    const filteredTracks = tracks
      .filter((_, i) => i !== index)
      .map((track, i) => ({ ...track, position: i + 1 }));

    setTracks(filteredTracks);

    const newSearchState: Record<number, TrackSearchState> = {};
    Object.entries(trackSearch).forEach(([key, value]) => {
      const numericKey = Number(key);
      if (numericKey < index) {
        newSearchState[numericKey] = value;
      }
      if (numericKey > index) {
        newSearchState[numericKey - 1] = value;
      }
    });
    setTrackSearch(newSearchState);
  };

  const parseTimeToSeconds = (time: string): number => parseTimeParts(time) ?? 0;

  const parseBulkTracklist = (mode: 'replace' | 'append') => {
    if (!bulkTrackText.trim()) {
      setBulkParseMessage('请先粘贴歌单文本');
      return;
    }

    const parsedLines = bulkTrackText
      .split('\n')
      .map((line) => parseTrackLine(line))
      .filter((item): item is NonNullable<ReturnType<typeof parseTrackLine>> => item !== null)
      .sort((a, b) => a.startSeconds - b.startSeconds);

    if (parsedLines.length === 0) {
      setBulkParseMessage('未识别到可解析行，请使用“时间戳 - 歌手 - 歌名”格式');
      return;
    }

    const generatedTracks: TrackInput[] = parsedLines.map((item, index) => ({
      position: index + 1,
      startTime: formatSecondsToTime(item.startSeconds),
      endTime:
        index < parsedLines.length - 1
          ? formatSecondsToTime(parsedLines[index + 1].startSeconds)
          : undefined,
      title: item.title,
      artist: item.artist,
      status: item.status,
    }));

    if (mode === 'append' && tracks.length > 0) {
      const merged = [...tracks, ...generatedTracks].map((track, index) => ({
        ...track,
        position: index + 1,
      }));
      setTracks(merged);
      setBulkParseMessage(`已追加 ${generatedTracks.length} 首歌曲`);
      return;
    }

    setTracks(generatedTracks);
    setTrackSearch({});
    setBulkParseMessage(`解析成功：${generatedTracks.length} 首歌曲（结束时间自动按下一首开始时间补全）`);
  };

  const searchSpotifyTrack = async (index: number) => {
    if (!spotifyAuth.authenticated) {
      setTrackSearch((prev) => ({
        ...prev,
        [index]: {
          ...(prev[index] || emptySearchState),
          error: 'Spotify 未鉴权，请先点击“去鉴权”并完成配置',
        },
      }));
      return;
    }

    const track = tracks[index];
    if (!track) {
      return;
    }

    const keyword = `${track.artist} ${track.title}`.trim();
    if (!keyword) {
      setTrackSearch((prev) => ({
        ...prev,
        [index]: {
          ...(prev[index] || emptySearchState),
          error: '请先填写歌曲名和艺术家后再搜索',
        },
      }));
      return;
    }

    setTrackSearch((prev) => ({
      ...prev,
      [index]: {
        ...(prev[index] || emptySearchState),
        loading: true,
        keyword,
        error: '',
      },
    }));

    try {
      const spotifyData = await SpotifyAPI.searchTrack(keyword);
      setTrackSearch((prev) => ({
        ...prev,
        [index]: {
          ...(prev[index] || emptySearchState),
          loading: false,
          keyword,
          spotifyResults: (spotifyData.tracks || []).map((item: any) => ({
            id: String(item.id),
            name: item.name || '',
            artist: item.artist || '',
            album: item.album || '',
            url: item.url || '',
            uri: item.uri || '',
          })),
          error: '',
        },
      }));
    } catch (error) {
      setTrackSearch((prev) => ({
        ...prev,
        [index]: {
          ...(prev[index] || emptySearchState),
          loading: false,
          error: error instanceof Error ? error.message : 'Spotify 搜索失败，请稍后重试',
        },
      }));
    }
  };

  const selectSpotifyResult = (index: number, result: SpotifyResultItem) => {
    const newTracks = [...tracks];
    newTracks[index] = {
      ...newTracks[index],
      spotifyId: result.id,
      spotifyUrl: result.url,
      spotifyUri: result.uri,
    };
    setTracks(newTracks);
  };

  const clearSpotifyBinding = (index: number) => {
    const newTracks = [...tracks];
    newTracks[index] = {
      ...newTracks[index],
      spotifyId: undefined,
      spotifyUrl: undefined,
      spotifyUri: undefined,
    };
    setTracks(newTracks);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) {
      alert('请先登录后再上传 Set');
      router.push('/login');
      return;
    }
    setLoading(true);

    try {
      if (!thumbnailUrl) {
        throw new Error('请先上传 DJ Set 封面图片');
      }

      if (selectedDjIds.length === 0) {
        throw new Error('请至少从 DJ 库中选择 1 位 DJ');
      }

      const targetDjId = selectedDjIds[0];
      const setResponse = await fetch(getApiUrl('/dj-sets'), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          djId: targetDjId,
          djIds: selectedDjIds,
          customDjNames: [],
          title,
          videoUrl,
          thumbnailUrl,
          description,
        }),
      });

      const setData = await setResponse.json().catch(() => ({}));
      if (!setResponse.ok) {
        throw new Error(setData.error || 'Failed to create DJ set');
      }

      const djSet = setData;

      const tracksData = tracks.map((track) => ({
        position: track.position,
        startTime: parseTimeToSeconds(track.startTime),
        endTime: track.endTime ? parseTimeToSeconds(track.endTime) : undefined,
        title: track.title,
        artist: track.artist,
        status: track.status,
        spotifyUrl: track.spotifyUrl,
        spotifyId: track.spotifyId,
        spotifyUri: track.spotifyUri,
        neteaseUrl: track.neteaseUrl,
        neteaseId: track.neteaseId,
      }));

      const addTracksResponse = await fetch(getApiUrl(`/dj-sets/${djSet.id}/tracks/batch`), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ tracks: tracksData }),
      });

      const tracksDataResponse = await addTracksResponse.json().catch(() => ({}));
      if (!addTracksResponse.ok) {
        throw new Error(tracksDataResponse.error || 'Failed to add tracks');
      }

      alert('DJ Set created successfully!');
      setSelectedDjIds([]);
      setCustomDJName('');
      setTitle('');
      setVideoUrl('');
      setThumbnailUrl('');
      setDescription('');
      setBulkTrackText('');
      setBulkParseMessage('');
      setTracks([]);
      setTrackSearch({});
      setPreviewMessage('');
    } catch (error) {
      console.error('Error:', error);
      alert(error instanceof Error ? error.message : 'Failed to create DJ set');
    } finally {
      setLoading(false);
    }
  };

  const canAdvanceStep =
    (activeStep === 1 && Boolean(title.trim())) ||
    (activeStep === 2 && Boolean(selectedDjIds.length && videoUrl.trim())) ||
    (activeStep === 3 && Boolean(tracks.length || bulkTrackText.trim())) ||
    activeStep === 4;

  const inputClassName =
    'w-full rounded-xl border border-bg-primary bg-bg-primary/60 px-4 py-3 text-text-primary outline-none transition-colors focus:border-primary-blue';
  const textareaClassName =
    'w-full rounded-xl border border-bg-primary bg-bg-primary/60 px-4 py-3 text-text-primary outline-none transition-colors focus:border-primary-blue';
  const panelClassName = 'rounded-2xl border border-bg-primary bg-bg-primary/40 p-4';
  const primaryActionClassName =
    'px-5 py-2.5 rounded-lg bg-primary-blue hover:bg-primary-purple text-white disabled:opacity-50';
  const secondaryActionClassName =
    'px-5 py-2.5 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary disabled:opacity-50';

  return (
    <div className="min-h-screen bg-bg-primary">
      <div className="pt-[44px]">
        <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
          <div className="mb-8">
            <p className="text-xs font-medium uppercase tracking-[0.24em] text-primary-blue">DJ 上传</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-text-primary sm:text-4xl">上传 DJ Set</h1>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-text-secondary">按步骤完成上传：先补齐基础信息，再关联 DJ，最后整理歌单并提交。</p>
          </div>

          {user && (
            <div className="mb-6 rounded-xl border border-primary-blue/20 bg-primary-blue/10 px-4 py-3 text-sm text-text-secondary">
              当前登录身份：<span className="font-semibold text-text-primary">{user.displayName || user.username}</span>
            </div>
          )}

          <div className="mb-6 rounded-xl border border-bg-tertiary bg-bg-secondary p-6">
            <div className="mb-3 flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-text-primary">完成进度</p>
                <p className="text-xs text-text-tertiary">{completionCount}/{steps.length} 个步骤已完成</p>
              </div>
              <span className="text-xs text-text-secondary">{progressPercent}%</span>
            </div>
            <div className="h-2 overflow-hidden rounded-full bg-bg-primary">
              <div className="h-full rounded-full bg-gradient-to-r from-primary-blue to-primary-purple" style={{ width: progressPercent + '%' }} />
            </div>
            <div className="mt-4 grid gap-2 sm:grid-cols-4">
              {steps.map((step) => (
                <button
                  key={step.id}
                  type="button"
                  onClick={() => setActiveStep(step.id)}
                  className={
                    activeStep === step.id
                      ? 'rounded-xl border border-primary-blue/40 bg-primary-blue/10 px-3 py-3 text-left transition-colors'
                      : 'rounded-xl border border-bg-primary bg-bg-primary/40 px-3 py-3 text-left transition-colors hover:border-bg-secondary'
                  }
                >
                  <p className="text-xs uppercase tracking-[0.2em] text-text-tertiary">Step {step.id}</p>
                  <p className="mt-1 text-sm font-medium text-text-primary">{step.title}</p>
                  <p className="mt-1 text-xs text-text-tertiary">{step.subtitle}</p>
                  <p className={step.done ? 'mt-2 text-xs text-accent-green' : 'mt-2 text-xs text-text-tertiary'}>{step.done ? '已完成' : '进行中'}</p>
                </button>
              ))}
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            {activeStep === 1 && (
              <SectionCard step="Step 01" title="基础信息" description="标题、封面和简介决定第一印象。" badge="先完成这里" active>
                <div className="grid gap-5 lg:grid-cols-[1.2fr_0.8fr]">
                  <div className="space-y-5">
                    <div>
                      <label className="mb-2 block text-sm font-medium text-text-primary">Set 标题</label>
                      <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} className={inputClassName} placeholder="例如：Boiler Room Berlin 2024" required />
                      <p className="mt-1 text-xs text-text-tertiary">建议写清楚场景、地点或主题。</p>
                    </div>
                    <div>
                      <label className="mb-2 block text-sm font-medium text-text-primary">介绍</label>
                      <textarea value={description} onChange={(e) => setDescription(e.target.value)} className={`min-h-[120px] ${textareaClassName}`} placeholder="补充一句这个 set 的风格、亮点、来源或者备注" rows={4} />
                    </div>
                  </div>
                  <div className={thumbnailDragging ? 'rounded-2xl border-2 border-dashed border-primary-blue bg-primary-blue/10 p-4 transition-colors' : 'rounded-2xl border-2 border-dashed border-primary-blue/30 bg-primary-blue/5 p-4 transition-colors'} onDragOver={(e) => { e.preventDefault(); setThumbnailDragging(true); }} onDragLeave={() => setThumbnailDragging(false)} onDrop={(e) => { e.preventDefault(); setThumbnailDragging(false); const file = e.dataTransfer.files?.[0]; if (file) uploadThumbnail(file); }}>
                    <label className="mb-2 block text-sm font-medium text-text-primary">DJ Set 封面</label>
                    <p className="mb-4 text-xs leading-5 text-text-tertiary">上传后的封面会用于外层卡片展示。</p>
                    <div className="flex flex-wrap items-center gap-2">
                      <label className="cursor-pointer rounded-xl border border-bg-primary bg-bg-tertiary px-4 py-2 text-sm text-text-primary transition-colors hover:border-primary-blue">
                        {thumbnailUploading ? '上传中...' : '选择图片'}
                        <input type="file" accept="image/*" className="hidden" onChange={(e) => { const file = e.target.files?.[0]; if (file) uploadThumbnail(file); }} />
                      </label>
                      <span className="text-xs text-text-tertiary">也可以直接拖拽到这里</span>
                    </div>
                    {thumbnailUrl ? <div className="relative mt-4 aspect-video overflow-hidden rounded-xl border border-bg-primary"><Image src={thumbnailUrl} alt="视频封面" fill className="object-cover" sizes="480px" /></div> : <div className="mt-4 flex aspect-video items-center justify-center rounded-xl border border-bg-primary bg-bg-primary/50 text-sm text-text-tertiary">还没有封面预览</div>}
                  </div>
                </div>
              </SectionCard>
            )}

            {activeStep === 2 && (
              <SectionCard step="Step 02" title="DJ 关联与视频链接" description="先把创作者和来源链接确认好。" badge={selectedDjIds.length + ' 位 DJ'} active>
                <div className="space-y-6">
                  <div>
                    <label className="mb-2 block text-sm font-medium text-text-primary">DJ 关联</label>
                    <div className="space-y-3">
                      <p className="text-xs text-text-tertiary">可搜索 DJ 库并多选，第一位会作为主 DJ。</p>
                      <input type="text" value={djSearchKeyword} onChange={(e) => setDjSearchKeyword(e.target.value)} className={inputClassName} placeholder="搜索 DJ 库（例如 Avicii / Martin Garrix）" />
                      <div className="flex min-h-8 flex-wrap gap-2">{selectedDjIds.length === 0 ? <span className="text-xs text-text-tertiary">尚未选择 DJ</span> : selectedDjIds.map((id) => { const matched = djs.find((dj) => dj.id === id); return <span key={id} className="inline-flex items-center gap-1 rounded-full border border-primary-blue/30 bg-primary-blue/15 px-3 py-1 text-xs text-primary-blue"><span>{matched?.name || id}</span><button type="button" onClick={() => removeSelectedDj(id)} className="text-primary-blue hover:text-white" aria-label="remove dj">×</button></span>; })}</div>
                      {djSearchKeyword.trim() && <div className="max-h-56 space-y-1 overflow-y-auto rounded-xl border border-bg-primary bg-bg-primary/40 p-2">{filteredDJs.length === 0 ? <p className="px-1 py-2 text-xs text-text-tertiary">DJ 库中暂无匹配结果，可在下方自定义添加。</p> : filteredDJs.map((dj) => { const added = selectedDjIds.includes(dj.id); return <div key={dj.id} className="flex items-center justify-between gap-2 rounded-lg px-2 py-2 hover:bg-bg-secondary/60"><span className="text-sm text-text-primary">{dj.name}</span><button type="button" onClick={() => addSelectedDj(dj.id)} disabled={added} className={added ? 'rounded-lg border border-bg-secondary bg-bg-primary px-3 py-1.5 text-xs text-text-tertiary cursor-not-allowed' : 'rounded-lg border border-primary-blue/40 bg-primary-blue/10 px-3 py-1.5 text-xs text-primary-blue hover:bg-primary-blue/20'}>{added ? '已添加' : '添加'}</button></div>; })}</div>}
                      <div className="grid grid-cols-1 gap-2 md:grid-cols-[1fr_auto]"><input type="text" value={customDJName} onChange={(e) => setCustomDJName(e.target.value)} className={inputClassName} placeholder="库中没有？输入 DJ 名称后添加" /><button type="button" onClick={addCustomDjToLibrary} disabled={addingCustomDj} className="rounded-xl border border-bg-primary bg-bg-tertiary px-4 py-3 text-sm text-text-primary transition-colors hover:border-primary-blue disabled:opacity-50">{addingCustomDj ? '添加中...' : '添加并选中'}</button></div>
                    </div>
                  </div>
                  <div>
                    <label className="mb-2 block text-sm font-medium text-text-primary">视频 URL</label>
                    <div className="flex flex-col gap-2 md:flex-row"><input type="url" value={videoUrl} onChange={(e) => setVideoUrl(e.target.value)} className={`flex-1 ${inputClassName}`} placeholder="YouTube 或 Bilibili URL" required /><button type="button" onClick={handlePasteAndExtract} className="rounded-xl bg-primary-blue px-4 py-3 text-sm text-white transition-colors hover:bg-primary-purple">一键粘贴</button><button type="button" onClick={() => fetchVideoPreview(videoUrl)} disabled={previewLoading || !videoUrl} className="rounded-xl border border-bg-primary bg-bg-tertiary px-4 py-3 text-sm text-text-primary transition-colors disabled:opacity-50">{previewLoading ? '提取中...' : '提取信息'}</button></div>
                    {previewMessage && <p className="mt-2 text-xs text-text-tertiary">{previewMessage}</p>}
                  </div>
                  <div className={panelClassName}><div className="mb-3 flex items-center justify-between gap-3"><h3 className="text-sm font-medium text-text-primary">视频预览</h3>{parsedVideo && <span className="text-xs uppercase tracking-[0.18em] text-text-tertiary">{parsedVideo.platform}</span>}</div>{parsedVideo ? <iframe src={parsedVideo.embedUrl} className="aspect-video w-full rounded-xl border border-bg-primary" allowFullScreen /> : <p className="text-sm text-text-tertiary">请输入有效的 YouTube 或 Bilibili 链接以预览</p>}</div>
                </div>
              </SectionCard>
            )}

            {activeStep === 3 && (
              <SectionCard step="Step 03" title="歌曲标记" description="批量导入后再做微调。" badge={tracks.length + ' 首歌曲'} active>
                <div className="space-y-6">
                  <div className="grid gap-4 lg:grid-cols-[1.15fr_0.85fr]">
                    <div className={panelClassName}>
                      <div className="flex flex-wrap items-center justify-between gap-3">
                        <div>
                          <h3 className="text-sm font-medium text-text-primary">批量粘贴歌单</h3>
                          <p className="mt-1 text-xs text-text-tertiary">每行格式：`开始时间 - 歌手 - 歌曲名`，适合先快速导入。</p>
                        </div>
                        <button type="button" onClick={addTrack} className="rounded-xl bg-primary-purple px-4 py-2.5 text-sm text-white transition-colors hover:bg-primary-blue">
                          + 手动添加歌曲
                        </button>
                      </div>
                      <textarea
                        value={bulkTrackText}
                        onChange={(e) => setBulkTrackText(e.target.value)}
                        className="mt-4 min-h-[220px] w-full rounded-xl border border-bg-secondary bg-bg-primary px-4 py-3 font-mono text-xs text-text-primary outline-none transition-colors focus:border-primary-blue"
                        rows={8}
                        placeholder={"0:00 - DAB THE SKY INTRO (In the End x Hero)\n1:40 - Said the Sky - Stay (Afinity Remix)\n2:32 - Said the Sky - Spider x Dabin - Holding On"}
                      />
                      <div className="mt-3 flex flex-wrap gap-2">
                        <button type="button" onClick={() => parseBulkTracklist('replace')} className="rounded-xl bg-primary-blue px-4 py-2 text-xs text-white transition-colors hover:bg-primary-purple">
                          解析并替换
                        </button>
                        <button type="button" onClick={() => parseBulkTracklist('append')} className="rounded-xl border border-bg-primary bg-bg-tertiary px-4 py-2 text-xs text-text-primary">
                          解析并追加
                        </button>
                      </div>
                      {bulkParseMessage && <p className="mt-2 text-xs text-text-secondary">{bulkParseMessage}</p>}
                    </div>

                    <div className={`${panelClassName} space-y-4`}>
                      <div>
                        <h3 className="text-sm font-medium text-text-primary">信息校对提示</h3>
                        <p className="mt-1 text-xs leading-5 text-text-tertiary">导入后建议逐首确认时间、标题、艺人以及 Spotify / 网易云绑定，避免提交后再返工。</p>
                      </div>
                      <div className="rounded-xl border border-bg-secondary bg-bg-secondary/50 p-4">
                        <p className="text-xs uppercase tracking-[0.18em] text-text-tertiary">Spotify 状态</p>
                        <p className="mt-2 text-sm text-text-primary">
                          {spotifyAuth.loading ? '检查中...' : spotifyAuth.authenticated ? '已完成鉴权，可直接搜索绑定' : '尚未鉴权'}
                        </p>
                        <p className="mt-1 text-xs text-text-tertiary">{spotifyAuth.message}</p>
                        {!spotifyAuth.authenticated && spotifyAuth.hasCredentials && (
                          <a
                            href={spotifyAuth.authUrl}
                            target="_blank"
                            rel="noreferrer"
                            className="mt-3 inline-flex rounded-lg border border-primary-blue/30 bg-primary-blue/10 px-3 py-2 text-xs text-primary-blue transition-colors hover:bg-primary-blue/20"
                          >
                            去鉴权
                          </a>
                        )}
                      </div>
                      <div className="rounded-xl border border-bg-secondary bg-bg-secondary/50 p-4">
                        <p className="text-xs uppercase tracking-[0.18em] text-text-tertiary">当前歌曲数</p>
                        <p className="mt-2 text-2xl font-semibold text-text-primary">{tracks.length}</p>
                        <p className="mt-1 text-xs text-text-tertiary">至少保留一首能让最终预览更完整。</p>
                      </div>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <h3 className="text-sm font-medium text-text-primary">逐首校对</h3>
                        <p className="mt-1 text-xs text-text-tertiary">每首歌都带标题字段，方便继续完善平台链接和状态。</p>
                      </div>
                    </div>

                    {tracks.length === 0 ? (
                      <div className="rounded-2xl border border-dashed border-bg-primary bg-bg-primary/30 px-5 py-10 text-center text-sm text-text-tertiary">
                        还没有歌曲。你可以先批量粘贴歌单，或者点击“手动添加歌曲”开始录入。
                      </div>
                    ) : (
                      <div className="space-y-4">
                        {tracks.map((track, index) => {
                          const searchState = trackSearch[index] || emptySearchState;

                          return (
                            <div key={`${track.position}-${index}`} className="rounded-2xl border border-bg-primary bg-bg-primary/30 p-4">
                              <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                                <div>
                                  <p className="text-xs uppercase tracking-[0.18em] text-text-tertiary">Track {track.position}</p>
                                  <h4 className="mt-1 text-sm font-medium text-text-primary">{track.title || '未命名歌曲'}</h4>
                                </div>
                                <button
                                  type="button"
                                  onClick={() => removeTrack(index)}
                                  className="rounded-lg border border-bg-primary bg-bg-tertiary px-3 py-2 text-xs text-text-secondary transition-colors hover:border-red-400 hover:text-red-300"
                                >
                                  删除
                                </button>
                              </div>

                              <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                                <div>
                                  <label className="mb-2 block text-sm font-medium text-text-primary">开始时间</label>
                                  <input type="text" value={track.startTime} onChange={(e) => updateTrack(index, 'startTime', e.target.value)} className={inputClassName} placeholder="0:00" />
                                </div>
                                <div>
                                  <label className="mb-2 block text-sm font-medium text-text-primary">结束时间</label>
                                  <input type="text" value={track.endTime || ''} onChange={(e) => updateTrack(index, 'endTime', e.target.value)} className={inputClassName} placeholder="可选，例如 2:35" />
                                </div>
                                <div>
                                  <label className="mb-2 block text-sm font-medium text-text-primary">歌曲标题</label>
                                  <input type="text" value={track.title} onChange={(e) => updateTrack(index, 'title', e.target.value)} className={inputClassName} placeholder="输入歌曲名" />
                                </div>
                                <div>
                                  <label className="mb-2 block text-sm font-medium text-text-primary">艺人名称</label>
                                  <input type="text" value={track.artist} onChange={(e) => updateTrack(index, 'artist', e.target.value)} className={inputClassName} placeholder="输入艺人名" />
                                </div>
                              </div>

                              <div className="mt-4 grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
                                <div className="space-y-4">
                                  <div>
                                    <label className="mb-2 block text-sm font-medium text-text-primary">歌曲状态</label>
                                    <select value={track.status} onChange={(e) => updateTrack(index, 'status', e.target.value)} className={inputClassName}>
                                      <option value="released">Released</option>
                                      <option value="id">ID / Unreleased</option>
                                      <option value="remix">Remix / VIP / Flip</option>
                                      <option value="edit">Edit / Mashup</option>
                                    </select>
                                  </div>
                                  <div>
                                    <label className="mb-2 block text-sm font-medium text-text-primary">网易云链接</label>
                                    <input type="url" value={track.neteaseUrl || ''} onChange={(e) => updateTrack(index, 'neteaseUrl', e.target.value)} className={inputClassName} placeholder="可选，粘贴网易云歌曲链接" />
                                    {track.neteaseId && <p className="mt-1 text-xs text-text-tertiary">已识别歌曲 ID：{track.neteaseId}</p>}
                                  </div>
                                </div>

                                <div className="rounded-xl border border-bg-secondary bg-bg-secondary/40 p-4">
                                  <div className="flex flex-wrap items-center justify-between gap-3">
                                    <div>
                                      <p className="text-sm font-medium text-text-primary">Spotify 绑定</p>
                                      <p className="mt-1 text-xs text-text-tertiary">根据标题和艺人搜索后，选中最匹配的结果。</p>
                                    </div>
                                    <div className="flex gap-2">
                                      <button
                                        type="button"
                                        onClick={() => searchSpotifyTrack(index)}
                                        disabled={searchState.loading}
                                        className="rounded-lg bg-primary-blue px-3 py-2 text-xs text-white transition-colors hover:bg-primary-purple disabled:opacity-50"
                                      >
                                        {searchState.loading ? '搜索中...' : '搜索 Spotify'}
                                      </button>
                                      {track.spotifyId && (
                                        <button
                                          type="button"
                                          onClick={() => clearSpotifyBinding(index)}
                                          className="rounded-lg border border-bg-primary bg-bg-tertiary px-3 py-2 text-xs text-text-secondary"
                                        >
                                          清除绑定
                                        </button>
                                      )}
                                    </div>
                                  </div>

                                  {track.spotifyUrl && (
                                    <a href={track.spotifyUrl} target="_blank" rel="noreferrer" className="mt-3 inline-flex text-xs text-primary-blue hover:text-white">
                                      查看当前已绑定歌曲
                                    </a>
                                  )}

                                  {searchState.error && <p className="mt-3 text-xs text-red-300">{searchState.error}</p>}

                                  {searchState.spotifyResults.length > 0 && (
                                    <div className="mt-3 space-y-2">
                                      {searchState.spotifyResults.slice(0, 5).map((result) => {
                                        const selected = track.spotifyId === result.id;

                                        return (
                                          <button
                                            key={result.id}
                                            type="button"
                                            onClick={() => selectSpotifyResult(index, result)}
                                            className={selected ? 'w-full rounded-xl border border-primary-blue/40 bg-primary-blue/10 p-3 text-left' : 'w-full rounded-xl border border-bg-primary bg-bg-primary/40 p-3 text-left transition-colors hover:border-primary-blue/30'}
                                          >
                                            <p className="text-sm font-medium text-text-primary">{result.name}</p>
                                            <p className="mt-1 text-xs text-text-secondary">{result.artist}</p>
                                            <p className="mt-1 text-xs text-text-tertiary">{result.album}</p>
                                          </button>
                                        );
                                      })}
                                    </div>
                                  )}
                                </div>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </div>
              </SectionCard>
            )}

            {activeStep === 4 && (
              <SectionCard step="Step 04" title="检查并提交" description="最后快速看一眼关键内容。" badge={readyToSubmit ? '可以提交' : '仍有必填项'} active>
                <div className="space-y-6">
                  <div className="grid gap-4 lg:grid-cols-2">
                    <div className={panelClassName}>
                      <p className="text-xs uppercase tracking-[0.18em] text-text-tertiary">基础信息</p>
                      <div className="mt-3 space-y-2 text-sm text-text-secondary">
                        <p><span className="text-text-tertiary">标题：</span>{title || '未填写'}</p>
                        <p><span className="text-text-tertiary">主 DJ：</span>{primaryDjName}</p>
                        <p><span className="text-text-tertiary">视频：</span>{videoUrl || '未填写'}</p>
                        <p><span className="text-text-tertiary">封面：</span>{thumbnailUrl ? '已上传' : '未上传'}</p>
                      </div>
                    </div>

                    <div className={panelClassName}>
                      <p className="text-xs uppercase tracking-[0.18em] text-text-tertiary">歌单状态</p>
                      <div className="mt-3 space-y-2 text-sm text-text-secondary">
                        <p><span className="text-text-tertiary">歌曲数：</span>{tracks.length}</p>
                        <p><span className="text-text-tertiary">Spotify：</span>{spotifyAuth.authenticated ? '已鉴权' : '未鉴权'}</p>
                        <p><span className="text-text-tertiary">DJ 列表：</span>{selectedDjNames.length ? selectedDjNames.join(' · ') : '未选择'}</p>
                      </div>
                    </div>
                  </div>

                  {tracks.length > 0 && (
                    <div className={panelClassName}>
                      <p className="text-xs uppercase tracking-[0.18em] text-text-tertiary">曲目预览</p>
                      <div className="mt-3 space-y-2 text-sm text-text-secondary">
                        {tracks.slice(0, 5).map((track) => (
                          <p key={`${track.position}-${track.title}`}>
                            <span className="text-text-tertiary">{track.position}. </span>
                            {track.startTime || '--:--'} · {track.artist || '未知艺人'} - {track.title || '未命名歌曲'}
                          </p>
                        ))}
                        {tracks.length > 5 && <p className="text-xs text-text-tertiary">其余 {tracks.length - 5} 首会一并提交。</p>}
                      </div>
                    </div>
                  )}

                  {!readyToSubmit && (
                    <div className="rounded-2xl border border-amber-500/20 bg-amber-500/10 px-4 py-3 text-sm text-text-secondary">
                      还缺少必填项：标题、封面、视频链接或 DJ 关联。
                    </div>
                  )}

                  <div className="flex items-center gap-3">
                    <button type="submit" disabled={loading || !readyToSubmit} className={primaryActionClassName}>
                      {loading ? '创建中...' : '创建 DJ Set'}
                    </button>
                    <button type="button" onClick={() => setActiveStep(Math.max(1, activeStep - 1))} className={secondaryActionClassName}>
                      上一步
                    </button>
                  </div>
                </div>
              </SectionCard>
            )}

            {activeStep < 4 && (
              <div className="flex items-center gap-3">
                <button type="button" onClick={() => setActiveStep((prev) => Math.min(4, prev + 1))} disabled={!canAdvanceStep} className={primaryActionClassName}>
                  下一步
                </button>
                <button type="button" onClick={() => setActiveStep((prev) => Math.max(1, prev - 1))} disabled={activeStep === 1} className={secondaryActionClassName}>
                  上一步
                </button>
              </div>
            )}
          </form>
        </div>
      </div>
    </div>
  );
}
