'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
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

  const parsedVideo = useMemo(() => parseVideoUrl(videoUrl), [videoUrl]);
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

  return (
    <div className="max-w-5xl mx-auto p-6">
      <h1 className="text-3xl font-bold text-text-primary mb-6">上传 DJ Set</h1>
      {user && (
        <div className="mb-4 rounded-lg border border-primary-blue/30 bg-primary-blue/10 px-4 py-3 text-sm text-text-secondary">
          当前登录身份：<span className="text-text-primary font-semibold">{user.displayName || user.username}</span>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="bg-bg-secondary rounded-xl p-6 space-y-4 border border-bg-tertiary">
          <h2 className="text-xl font-semibold text-text-primary">1. 提交视频链接</h2>

          <div>
            <label className="block text-text-secondary mb-2">DJ</label>
            <div className="space-y-3">
              <p className="text-xs text-text-tertiary">可从 DJ 库搜索并多选；主 DJ 将采用你选择列表中的第 1 位。</p>
              <input
                type="text"
                value={djSearchKeyword}
                onChange={(e) => setDjSearchKeyword(e.target.value)}
                className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
                placeholder="搜索 DJ 库（例如 Avicii / Martin Garrix）"
              />
              <div className="flex flex-wrap gap-2 min-h-8">
                {selectedDjIds.length === 0 ? (
                  <span className="text-xs text-text-tertiary">尚未选择 DJ</span>
                ) : (
                  selectedDjIds.map((id) => {
                    const matched = djs.find((dj) => dj.id === id);
                    return (
                      <span key={id} className="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-full bg-primary-blue/20 text-primary-blue border border-primary-blue/30">
                        <span>{matched?.name || id}</span>
                        <button
                          type="button"
                          onClick={() => removeSelectedDj(id)}
                          className="text-primary-blue hover:text-white"
                          aria-label="remove dj"
                        >
                          ×
                        </button>
                      </span>
                    );
                  })
                )}
              </div>
              {djSearchKeyword.trim() && (
                <div className="rounded-lg border border-bg-primary bg-bg-tertiary/40 p-2 max-h-56 overflow-y-auto space-y-1">
                  {filteredDJs.length === 0 ? (
                    <p className="text-xs text-text-tertiary px-1 py-2">DJ 库中暂无匹配结果，可在下方自定义添加。</p>
                  ) : (
                    filteredDJs.map((dj) => {
                      const added = selectedDjIds.includes(dj.id);
                      return (
                        <div key={dj.id} className="flex items-center justify-between gap-2 px-2 py-1 rounded hover:bg-bg-primary/50">
                          <span className="text-sm text-text-primary">{dj.name}</span>
                          <button
                            type="button"
                            onClick={() => addSelectedDj(dj.id)}
                            disabled={added}
                            className={`px-2 py-1 rounded text-xs border ${
                              added
                                ? 'bg-bg-primary text-text-tertiary border-bg-secondary cursor-not-allowed'
                                : 'bg-primary-blue/10 text-primary-blue border-primary-blue/40 hover:bg-primary-blue/20'
                            }`}
                          >
                            {added ? 'Added' : '+ Add'}
                          </button>
                        </div>
                      );
                    })
                  )}
                </div>
              )}
              <div className="grid grid-cols-1 md:grid-cols-[1fr_auto] gap-2">
                <input
                  type="text"
                  value={customDJName}
                  onChange={(e) => setCustomDJName(e.target.value)}
                  className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
                  placeholder="库中没有？输入 DJ 名称后添加到 DJ 库"
                />
                <button
                  type="button"
                  onClick={addCustomDjToLibrary}
                  disabled={addingCustomDj}
                  className="px-3 py-2 rounded-lg bg-bg-tertiary border border-bg-primary text-text-primary hover:border-primary-blue disabled:opacity-50"
                >
                  {addingCustomDj ? '添加中...' : '添加并选中'}
                </button>
              </div>
            </div>
          </div>

          <div>
            <label className="block text-text-secondary mb-2">视频 URL</label>
            <div className="flex gap-2">
              <input
                type="url"
                value={videoUrl}
                onChange={(e) => setVideoUrl(e.target.value)}
                className="flex-1 bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
                placeholder="YouTube 或 Bilibili URL"
                required
              />
              <button
                type="button"
                onClick={handlePasteAndExtract}
                className="px-3 py-2 bg-primary-blue hover:bg-primary-purple text-white rounded-lg text-sm"
              >
                一键粘贴
              </button>
              <button
                type="button"
                onClick={() => fetchVideoPreview(videoUrl)}
                disabled={previewLoading || !videoUrl}
                className="px-3 py-2 bg-bg-tertiary border border-bg-primary text-text-primary rounded-lg text-sm disabled:opacity-50"
              >
                {previewLoading ? '提取中...' : '提取信息'}
              </button>
            </div>
            {previewMessage && <p className="text-xs text-text-tertiary mt-1">{previewMessage}</p>}
          </div>

          <div
            className={`rounded-lg border-2 border-dashed p-3 transition-colors ${
              thumbnailDragging
                ? 'border-primary-blue bg-primary-blue/10'
                : 'border-primary-blue/30 bg-primary-blue/10'
            }`}
            onDragOver={(e) => {
              e.preventDefault();
              setThumbnailDragging(true);
            }}
            onDragLeave={() => setThumbnailDragging(false)}
            onDrop={(e) => {
              e.preventDefault();
              setThumbnailDragging(false);
              const file = e.dataTransfer.files?.[0];
              if (file) {
                uploadThumbnail(file);
              }
            }}
          >
            <label className="block text-text-secondary mb-2 text-sm">DJ Set 封面图片（手动上传）</label>
            <div className="flex flex-wrap items-center gap-2">
              <label className="px-3 py-2 bg-bg-tertiary border border-bg-primary text-text-primary rounded-lg text-sm cursor-pointer hover:border-primary-blue">
                {thumbnailUploading ? '上传中...' : '点击上传文件'}
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      uploadThumbnail(file);
                    }
                  }}
                />
              </label>
              <span className="text-xs text-text-tertiary">或者把图片拖到这个区域</span>
            </div>
            <p className="text-[11px] text-text-tertiary mt-2">
              不再自动从 YouTube 抓取封面，上传后的图片将用于 DJ Set 外层卡片展示。
            </p>
          </div>

          <div>
            <label className="block text-text-secondary mb-2">Set 标题</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
              placeholder="例如: Boiler Room Berlin 2024"
              required
            />
          </div>

          <div>
            <label className="block text-text-secondary mb-2">介绍</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
              rows={3}
            />
          </div>

          <div className="mt-2 rounded-lg border border-bg-primary bg-bg-tertiary p-4">
            <div className="flex items-center justify-between mb-3">
              <h3 className="font-medium text-text-primary">2. 视频预览</h3>
              {parsedVideo && (
                <span className="text-xs text-text-secondary uppercase">{parsedVideo.platform}</span>
              )}
            </div>
            {thumbnailUrl && (
              <div className="mb-3">
                <p className="text-xs text-text-secondary mb-2">封面预览（将用于外层卡片）</p>
                <div className="relative w-full md:w-80 aspect-video rounded-lg border border-bg-primary overflow-hidden">
                  <Image src={thumbnailUrl} alt="视频封面" fill className="object-cover" sizes="320px" />
                </div>
              </div>
            )}
            {parsedVideo ? (
              <iframe
                src={parsedVideo.embedUrl}
                className="w-full aspect-video rounded-lg border border-bg-primary"
                allowFullScreen
              />
            ) : (
              <p className="text-sm text-text-tertiary">请输入有效的 YouTube 或 Bilibili 链接以预览</p>
            )}
          </div>
        </div>

        <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
          <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
            <h2 className="text-xl font-semibold text-text-primary">3. 手动添加歌曲标记</h2>
            <button
              type="button"
              onClick={addTrack}
              className="bg-primary-purple hover:bg-primary-blue text-white px-4 py-2 rounded-lg transition-colors"
            >
              + 添加歌曲
            </button>
          </div>

          <div className="mb-5 rounded-lg border border-primary-blue/30 bg-primary-blue/10 p-4">
            <p className="text-sm font-medium text-text-primary mb-2">批量粘贴歌单（推荐）</p>
            <p className="text-xs text-text-secondary mb-2">
              固定格式：每行 <code>开始时间 - 歌手 - 歌曲名</code>。只要求开始时间，结束时间会自动按下一首推导。
            </p>
            <textarea
              value={bulkTrackText}
              onChange={(e) => setBulkTrackText(e.target.value)}
              className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none font-mono text-xs"
              rows={8}
              placeholder={`0:00 - DAB THE SKY INTRO (In the End x Hero)\n1:40 - Said the Sky - Stay (Afinity Remix)\n2:32 - Said the Sky - Spider x Dabin - Holding On`}
            />
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => parseBulkTracklist('replace')}
                className="px-3 py-2 bg-primary-blue hover:bg-primary-purple text-white rounded-lg text-xs"
              >
                解析并替换当前歌单
              </button>
              <button
                type="button"
                onClick={() => parseBulkTracklist('append')}
                className="px-3 py-2 bg-bg-tertiary border border-bg-primary text-text-primary rounded-lg text-xs"
              >
                解析并追加到当前歌单
              </button>
            </div>
            {bulkParseMessage && (
              <p className="mt-2 text-xs text-text-secondary">{bulkParseMessage}</p>
            )}
          </div>

          <div className="mb-4 rounded-lg border border-bg-primary bg-bg-tertiary p-3">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="text-sm font-medium text-text-primary">Spotify 鉴权状态</p>
                <p className={`text-xs ${spotifyAuth.authenticated ? 'text-accent-green' : 'text-accent-red'}`}>
                  {spotifyAuth.loading ? '检查中...' : spotifyAuth.message}
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={checkSpotifyAuth}
                  className="px-3 py-2 text-xs rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary"
                >
                  刷新状态
                </button>
                {!spotifyAuth.authenticated && (
                  <a
                    href={spotifyAuth.authUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="px-3 py-2 text-xs rounded-lg bg-[#1DB954] text-white hover:bg-[#1ed760]"
                  >
                    去鉴权
                  </a>
                )}
              </div>
            </div>
          </div>

          <div className="space-y-4">
            {tracks.map((track, index) => {
              const searchState = trackSearch[index] || emptySearchState;
              const hasSpotifyResults = searchState.spotifyResults.length > 0;

              return (
                <div key={index} className="bg-bg-tertiary rounded-lg p-4 border border-bg-primary">
                  <div className="flex justify-between items-start mb-3">
                    <span className="text-text-secondary">歌曲 {index + 1}</span>
                    <button
                      type="button"
                      onClick={() => removeTrack(index)}
                      className="text-accent-red hover:text-accent-red/80"
                    >
                      删除
                    </button>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <label className="block text-text-secondary text-sm mb-1">开始时间 (mm:ss)</label>
                      <input
                        type="text"
                        value={track.startTime}
                        onChange={(e) => updateTrack(index, 'startTime', e.target.value)}
                        className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                        placeholder="0:00"
                        required
                      />
                    </div>

                    <div>
                      <label className="block text-text-secondary text-sm mb-1">结束时间 (mm:ss)</label>
                      <input
                        type="text"
                        value={track.endTime || ''}
                        onChange={(e) => updateTrack(index, 'endTime', e.target.value)}
                        className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                        placeholder="5:30"
                      />
                    </div>

                    <div>
                      <label className="block text-text-secondary text-sm mb-1">歌曲名</label>
                      <input
                        type="text"
                        value={track.title}
                        onChange={(e) => updateTrack(index, 'title', e.target.value)}
                        className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                        required
                      />
                    </div>

                    <div>
                      <label className="block text-text-secondary text-sm mb-1">歌手名</label>
                      <input
                        type="text"
                        value={track.artist}
                        onChange={(e) => updateTrack(index, 'artist', e.target.value)}
                        className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                        required
                      />
                    </div>

                    <div className="md:col-span-2">
                      <label className="block text-text-secondary text-sm mb-1">状态</label>
                      <select
                        value={track.status}
                        onChange={(e) => updateTrack(index, 'status', e.target.value)}
                        className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                      >
                        <option value="released">已发行</option>
                        <option value="id">ID / 未发行</option>
                        <option value="remix">Remix</option>
                        <option value="edit">Edit</option>
                      </select>
                    </div>
                  </div>

                  <div className="mt-4 border-t border-bg-primary pt-4">
                    <div className="flex flex-wrap items-center justify-between gap-3 mb-3">
                      <p className="text-sm text-text-primary font-medium">Spotify 搜索并绑定</p>
                      <button
                        type="button"
                        onClick={() => searchSpotifyTrack(index)}
                        disabled={searchState.loading || !spotifyAuth.authenticated}
                        className="bg-[#1DB954] hover:bg-[#1ed760] disabled:bg-bg-secondary text-white text-sm px-3 py-2 rounded-lg transition-colors"
                      >
                        {searchState.loading ? '搜索中...' : '搜索 Spotify'}
                      </button>
                    </div>

                    {track.spotifyUrl && (
                      <div className="flex items-center gap-2 bg-[#1DB954]/20 text-[#1DB954] px-2 py-1 rounded-md text-xs mb-3 w-fit">
                        <span>已绑定 Spotify: {track.spotifyId}</span>
                        <button
                          type="button"
                          className="hover:text-white"
                          onClick={() => clearSpotifyBinding(index)}
                        >
                          移除
                        </button>
                      </div>
                    )}

                    {searchState.error && (
                      <p className="text-xs text-accent-red mb-2">{searchState.error}</p>
                    )}

                    {hasSpotifyResults && (
                      <div className="bg-bg-primary rounded-lg p-3 border border-bg-secondary">
                        <h4 className="text-sm text-[#1DB954] font-semibold mb-2">
                          Spotify 结果 ({searchState.spotifyResults.length})
                        </h4>
                        <div className="space-y-2 max-h-52 overflow-y-auto">
                          {searchState.spotifyResults.map((result) => (
                            <button
                              key={`spotify-${result.id}`}
                              type="button"
                              onClick={() => selectSpotifyResult(index, result)}
                              className="w-full text-left p-2 rounded-md hover:bg-bg-secondary border border-transparent hover:border-[#1DB954]/40 transition-colors"
                            >
                              <p className="text-sm text-text-primary truncate">{result.name}</p>
                              <p className="text-xs text-text-secondary truncate">{result.artist}</p>
                              {result.album && (
                                <p className="text-xs text-text-tertiary truncate">{result.album}</p>
                              )}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>

                  <div className="mt-4 border-t border-bg-primary pt-4">
                    <p className="text-sm text-text-primary font-medium mb-2">网易云链接（手动粘贴）</p>
                    <input
                      type="url"
                      value={track.neteaseUrl || ''}
                      onChange={(e) => updateTrack(index, 'neteaseUrl', e.target.value)}
                      className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                      placeholder="https://music.163.com/#/song?id=..."
                    />
                    <p className="text-xs text-text-tertiary mt-1">
                      已解析网易云歌曲ID: {track.neteaseId || '未解析到'}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-primary-purple hover:bg-primary-blue disabled:bg-bg-tertiary text-white font-semibold py-3 rounded-lg transition-colors"
        >
          {loading ? '创建中...' : '创建 DJ Set'}
        </button>
      </form>
    </div>
  );
}
