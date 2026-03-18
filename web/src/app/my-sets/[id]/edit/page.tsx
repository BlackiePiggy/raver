'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Image from 'next/image';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { getApiUrl } from '@/lib/config';
import { SpotifyAPI } from '@/lib/music-api';

interface EditTrack {
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

interface EditableSet {
  id: string;
  uploadedById?: string;
  djId: string;
  coDjIds?: string[];
  customDjNames?: string[];
  title: string;
  description?: string;
  videoUrl: string;
  thumbnailUrl?: string;
  venue?: string;
  eventName?: string;
  tracks: Array<{
    position: number;
    startTime: number;
    endTime?: number;
    title: string;
    artist: string;
    status: 'released' | 'id' | 'remix' | 'edit';
    spotifyUrl?: string;
    spotifyId?: string;
    spotifyUri?: string;
    neteaseUrl?: string;
    neteaseId?: string;
  }>;
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
  if (!url) return undefined;
  const hashMatch = url.match(/song\?id=(\d+)/);
  if (hashMatch) return hashMatch[1];
  const plainMatch = url.match(/id=(\d+)/);
  if (plainMatch) return plainMatch[1];
  return undefined;
};

const inferTrackStatus = (text: string): EditTrack['status'] => {
  const normalized = text.toLowerCase();
  if (normalized.includes('unreleased') || /\bid\b/.test(normalized)) return 'id';
  if (normalized.includes('remix') || normalized.includes(' flip') || normalized.includes(' vip')) return 'remix';
  if (normalized.includes(' edit') || normalized.includes('(edit') || normalized.includes(' x ') || normalized.includes(' vs ')) return 'edit';
  return 'released';
};

const parseTrackLine = (
  line: string
): { startSeconds: number; title: string; artist: string; status: EditTrack['status'] } | null => {
  const cleaned = line.trim();
  if (!cleaned) return null;
  const match = cleaned.match(/^(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*(.+)$/);
  if (!match) return null;
  const startSeconds = parseTimeToSeconds(match[1]);
  const details = match[2].trim();
  const splitIndex = details.indexOf(' - ');
  const artist = splitIndex > -1 ? details.slice(0, splitIndex).trim() : 'Unknown';
  const title = splitIndex > -1 ? details.slice(splitIndex + 3).trim() : details;
  return { startSeconds, title, artist, status: inferTrackStatus(details) };
};

const parseTimeToSeconds = (time: string): number => {
  const parts = time.trim().split(':').map((v) => Number(v));
  if (parts.some((v) => Number.isNaN(v))) {
    return 0;
  }
  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }
  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  return 0;
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

export default function EditMySetPage() {
  const params = useParams();
  const router = useRouter();
  const { user, token, isLoading } = useAuth();

  const [setData, setSetData] = useState<EditableSet | null>(null);
  const [djs, setDjs] = useState<Array<{ id: string; name: string }>>([]);
  const [selectedDjIds, setSelectedDjIds] = useState<string[]>([]);
  const [djSearchKeyword, setDjSearchKeyword] = useState('');
  const [customDJName, setCustomDJName] = useState('');
  const [addingCustomDj, setAddingCustomDj] = useState(false);
  const [title, setTitle] = useState('');
  const [videoUrl, setVideoUrl] = useState('');
  const [thumbnailUrl, setThumbnailUrl] = useState('');
  const [description, setDescription] = useState('');
  const [venue, setVenue] = useState('');
  const [eventName, setEventName] = useState('');
  const [bulkTrackText, setBulkTrackText] = useState('');
  const [bulkParseMessage, setBulkParseMessage] = useState('');
  const [tracks, setTracks] = useState<EditTrack[]>([]);
  const [trackSearch, setTrackSearch] = useState<Record<number, TrackSearchState>>({});
  const [spotifyAuth, setSpotifyAuth] = useState<SpotifyAuthState>(emptySpotifyAuth);
  const [thumbnailUploading, setThumbnailUploading] = useState(false);
  const [thumbnailDragging, setThumbnailDragging] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const setId = useMemo(() => String(params.id || ''), [params.id]);
  const filteredDJs = useMemo(() => {
    const keyword = djSearchKeyword.trim().toLowerCase();
    if (!keyword) {
      return [];
    }
    return djs.filter((dj) => dj.name.toLowerCase().includes(keyword)).slice(0, 120);
  }, [djs, djSearchKeyword]);

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
      return;
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    const loadDjs = async () => {
      try {
        const response = await fetch(getApiUrl('/djs?limit=400&sortBy=followerCount&live=false'));
        const data = await response.json().catch(() => ({}));
        const list = Array.isArray(data?.djs)
          ? data.djs.map((item: any) => ({ id: item.id, name: item.name }))
          : [];
        setDjs(list);
      } catch {
        setDjs([]);
      }
    };

    loadDjs();
  }, []);

  useEffect(() => {
    const loadSet = async () => {
      if (!setId) {
        return;
      }
      setLoading(true);
      setError('');
      try {
        const response = await fetch(getApiUrl(`/dj-sets/${setId}`));
        const data = await response.json().catch(() => ({}));
        if (!response.ok) {
          throw new Error(data.error || '加载 DJ Set 失败');
        }

        setSetData(data as EditableSet);
        setTitle(data.title || '');
        setVideoUrl(data.videoUrl || '');
        setThumbnailUrl(data.thumbnailUrl || '');
        setDescription(data.description || '');
        setVenue(data.venue || '');
        setEventName(data.eventName || '');
        setSelectedDjIds(
          [data.djId, ...(Array.isArray(data.coDjIds) ? data.coDjIds : [])].filter((id, idx, arr) => id && arr.indexOf(id) === idx)
        );
        setTracks(
          Array.isArray(data.tracks)
            ? data.tracks.map((track: any, index: number) => ({
                position: index + 1,
                startTime: formatSecondsToTime(track.startTime || 0),
                endTime: track.endTime ? formatSecondsToTime(track.endTime) : '',
                title: track.title || '',
                artist: track.artist || '',
                status: track.status || 'released',
                spotifyUrl: track.spotifyUrl,
                spotifyId: track.spotifyId,
                spotifyUri: track.spotifyUri,
                neteaseUrl: track.neteaseUrl,
                neteaseId: track.neteaseId,
              }))
            : []
        );
      } catch (err) {
        setError(err instanceof Error ? err.message : '加载失败');
      } finally {
        setLoading(false);
      }
    };

    loadSet();
  }, [setId]);

  useEffect(() => {
    if (!setData || !user) {
      return;
    }
    if (setData.uploadedById && setData.uploadedById !== user.id) {
      setError('你只能编辑自己上传的 DJ Set');
    }
  }, [setData, user]);

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
    if (user) {
      checkSpotifyAuth();
    }
  }, [user, checkSpotifyAuth]);

  const addSelectedDj = (id: string) => {
    setSelectedDjIds((prev) => (prev.includes(id) ? prev : [...prev, id]));
  };

  const removeSelectedDj = (id: string) => {
    setSelectedDjIds((prev) => prev.filter((item) => item !== id));
  };

  const addCustomDjToLibrary = async () => {
    const trimmed = customDJName.trim();
    if (!trimmed) {
      setMessage('请输入 DJ 名称');
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
      setMessage(`已添加并选中 DJ：${ensured.name || trimmed}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : '添加自定义 DJ 失败');
    } finally {
      setAddingCustomDj(false);
    }
  };

  const updateTrack = (index: number, field: keyof EditTrack, value: string) => {
    const next = [...tracks];
    const candidate = { ...next[index], [field]: value };
    if (field === 'neteaseUrl') {
      candidate.neteaseId = parseNeteaseIdFromUrl(value);
    }
    next[index] = candidate;
    setTracks(next);

    if (field === 'title' || field === 'artist') {
      const keyword = `${candidate.artist} ${candidate.title}`.trim();
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

  const addTrack = () => {
    setTracks((prev) => [
      ...prev,
      {
        position: prev.length + 1,
        startTime: '',
        endTime: '',
        title: '',
        artist: '',
        status: 'released',
      },
    ]);
  };

  const removeTrack = (index: number) => {
    setTracks((prev) => prev.filter((_, i) => i !== index).map((track, i) => ({ ...track, position: i + 1 })));
    const nextSearch: Record<number, TrackSearchState> = {};
    Object.entries(trackSearch).forEach(([key, value]) => {
      const numericKey = Number(key);
      if (numericKey < index) {
        nextSearch[numericKey] = value;
      } else if (numericKey > index) {
        nextSearch[numericKey - 1] = value;
      }
    });
    setTrackSearch(nextSearch);
  };

  const fetchPreview = async () => {
    if (!videoUrl.trim()) {
      return;
    }
    setMessage('正在解析视频信息...');
    try {
      const response = await fetch(getApiUrl(`/dj-sets/preview?videoUrl=${encodeURIComponent(videoUrl.trim())}`));
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.error || '解析失败');
      }
      if (!title && data.title) {
        setTitle(data.title);
      }
      if (!description && data.description) {
        setDescription(data.description);
      }
      setMessage('解析成功，已更新标题/介绍');
    } catch (err) {
      setMessage(err instanceof Error ? err.message : '解析失败');
    }
  };

  const handlePasteAndExtract = async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (!text) {
        setMessage('剪贴板为空');
        return;
      }
      setVideoUrl(text.trim());
      if (!title || !description) {
        await fetch(getApiUrl(`/dj-sets/preview?videoUrl=${encodeURIComponent(text.trim())}`))
          .then((res) => res.json().then((data) => ({ ok: res.ok, data })))
          .then(({ ok, data }) => {
            if (!ok) {
              throw new Error(data.error || '解析失败');
            }
            if (!title && data.title) {
              setTitle(data.title);
            }
            if (!description && data.description) {
              setDescription(data.description);
            }
            setMessage('已粘贴并解析视频信息');
          });
      } else {
        setMessage('已粘贴视频链接');
      }
    } catch (err) {
      setMessage(err instanceof Error ? `无法读取剪贴板：${err.message}` : '无法读取剪贴板');
    }
  };

  const uploadThumbnail = async (file: File) => {
    if (!token) {
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
      setMessage('封面上传成功');
    } catch (err) {
      setError(err instanceof Error ? err.message : '封面上传失败');
    } finally {
      setThumbnailUploading(false);
    }
  };

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

    const generatedTracks: EditTrack[] = parsedLines.map((item, index) => ({
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
          error: 'Spotify 未鉴权，请先完成配置',
        },
      }));
      return;
    }

    const track = tracks[index];
    if (!track) return;
    const keyword = `${track.artist} ${track.title}`.trim();
    if (!keyword) {
      setTrackSearch((prev) => ({
        ...prev,
        [index]: {
          ...(prev[index] || emptySearchState),
          error: '请先填写歌曲名和艺术家',
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
          error: error instanceof Error ? error.message : 'Spotify 搜索失败',
        },
      }));
    }
  };

  const selectSpotifyResult = (index: number, result: SpotifyResultItem) => {
    const next = [...tracks];
    next[index] = {
      ...next[index],
      spotifyId: result.id,
      spotifyUrl: result.url,
      spotifyUri: result.uri,
    };
    setTracks(next);
  };

  const clearSpotifyBinding = (index: number) => {
    const next = [...tracks];
    next[index] = {
      ...next[index],
      spotifyId: undefined,
      spotifyUrl: undefined,
      spotifyUri: undefined,
    };
    setTracks(next);
  };

  const handleSave = async () => {
    if (!token) {
      router.push('/login');
      return;
    }
    if (!setData || (setData.uploadedById && setData.uploadedById !== user?.id)) {
      return;
    }
    if (selectedDjIds.length === 0) {
      setError('请至少从 DJ 库中选择 1 位 DJ');
      return;
    }

    setSaving(true);
    setMessage('');
    setError('');

    try {
      const updateSetRes = await fetch(getApiUrl(`/dj-sets/${setId}`), {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          djId: selectedDjIds[0],
          djIds: selectedDjIds,
          customDjNames: [],
          title,
          videoUrl,
          thumbnailUrl,
          description,
          venue,
          eventName,
        }),
      });
      const setResult = await updateSetRes.json().catch(() => ({}));
      if (!updateSetRes.ok) {
        throw new Error(setResult.error || '更新 DJ Set 基础信息失败');
      }

      const normalizedTracks = tracks
        .filter((track) => track.startTime.trim() && track.title.trim() && track.artist.trim())
        .map((track, index) => ({
          position: index + 1,
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

      const updateTracksRes = await fetch(getApiUrl(`/dj-sets/${setId}/tracks`), {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ tracks: normalizedTracks }),
      });
      const tracksResult = await updateTracksRes.json().catch(() => ({}));
      if (!updateTracksRes.ok) {
        throw new Error(tracksResult.error || '更新 tracklist 失败');
      }

      setMessage('保存成功，视频与 tracklist 已更新');
    } catch (err) {
      setError(err instanceof Error ? err.message : '保存失败');
    } finally {
      setSaving(false);
    }
  };

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-6xl mx-auto p-6 space-y-5">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-text-primary">编辑我的 DJ Set</h1>
            <p className="text-text-secondary mt-1">可修改视频信息与 tracklist。</p>
          </div>
          <button
            type="button"
            onClick={() => router.push('/my-publishes?type=djset')}
            className="px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary"
          >
            返回我的发布
          </button>
        </div>

        {loading ? (
          <div className="text-text-secondary">加载中...</div>
        ) : error ? (
          <div className="rounded-lg border border-accent-red/40 bg-accent-red/10 text-accent-red p-3">{error}</div>
        ) : (
          <>
            <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 space-y-4">
              <h2 className="text-xl font-semibold text-text-primary">视频信息</h2>
              <div>
                <label className="block text-sm text-text-secondary mb-2">DJ（可多选）</label>
                <p className="text-xs text-text-tertiary mb-2">主 DJ 为所选列表中的第 1 位。</p>
                <input
                  type="text"
                  value={djSearchKeyword}
                  onChange={(e) => setDjSearchKeyword(e.target.value)}
                  className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none mb-2"
                  placeholder="搜索 DJ 库..."
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
                  <div className="mt-2 rounded-lg border border-bg-primary bg-bg-tertiary/40 p-2 max-h-56 overflow-y-auto space-y-1">
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
                <div className="mt-2 grid grid-cols-1 md:grid-cols-[1fr_auto] gap-2">
                  <input
                    type="text"
                    value={customDJName}
                    onChange={(e) => setCustomDJName(e.target.value)}
                    className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none"
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
              <div>
                <label className="block text-sm text-text-secondary mb-1">标题</label>
                <input value={title} onChange={(e) => setTitle(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none" />
              </div>
              <div>
                <label className="block text-sm text-text-secondary mb-1">视频 URL</label>
                <div className="flex gap-2">
                  <input value={videoUrl} onChange={(e) => setVideoUrl(e.target.value)} className="flex-1 bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none" />
                  <button type="button" onClick={fetchPreview} className="px-3 py-2 rounded-lg bg-bg-tertiary border border-bg-primary text-text-primary">重新解析</button>
                </div>
              </div>
              <div
                className={`rounded-lg border-2 border-dashed p-3 transition-colors ${
                  thumbnailDragging
                    ? 'border-primary-blue bg-primary-blue/10'
                    : 'border-bg-primary bg-bg-tertiary/40'
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
                <label className="block text-sm text-text-secondary mb-2">封面图片（拖拽或点击上传）</label>
                {thumbnailUrl ? (
                  <div className="relative w-full md:w-80 aspect-video rounded-lg border border-bg-primary overflow-hidden mb-2">
                    <Image src={thumbnailUrl} alt="DJ Set封面" fill className="object-cover" sizes="320px" />
                  </div>
                ) : (
                  <div className="w-full md:w-80 aspect-video rounded-lg bg-bg-primary/40 flex items-center justify-center text-text-tertiary text-sm mb-2">
                    暂无封面
                  </div>
                )}
                <label className="inline-flex px-3 py-2 rounded-lg bg-bg-primary border border-bg-secondary text-text-primary text-sm cursor-pointer">
                  {thumbnailUploading ? '上传中...' : '点击上传图片'}
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
              </div>
              <div>
                <label className="block text-sm text-text-secondary mb-1">介绍</label>
                <textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none" />
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-text-secondary mb-1">Venue</label>
                  <input value={venue} onChange={(e) => setVenue(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none" />
                </div>
                <div>
                  <label className="block text-sm text-text-secondary mb-1">Event Name</label>
                  <input value={eventName} onChange={(e) => setEventName(e.target.value)} className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none" />
                </div>
              </div>
            </div>

            <div className="rounded-xl border border-bg-tertiary bg-bg-secondary p-5 space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-semibold text-text-primary">Tracklist</h2>
                <button onClick={addTrack} type="button" className="px-3 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white text-sm">+ 添加歌曲</button>
              </div>

              <div className="rounded-lg border border-primary-blue/30 bg-primary-blue/10 p-4">
                <p className="text-sm font-medium text-text-primary mb-2">批量粘贴歌单（与上传页一致）</p>
                <p className="text-xs text-text-secondary mb-2">
                  固定格式：每行 <code>开始时间 - 歌手 - 歌曲名</code>。只要求开始时间，结束时间自动推导。
                </p>
                <textarea
                  value={bulkTrackText}
                  onChange={(e) => setBulkTrackText(e.target.value)}
                  className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none font-mono text-xs"
                  rows={6}
                  placeholder={`0:00 - Artist - Track\n1:40 - Artist - Track 2`}
                />
                <div className="mt-3 flex flex-wrap gap-2">
                  <button type="button" onClick={() => parseBulkTracklist('replace')} className="px-3 py-2 bg-primary-blue hover:bg-primary-purple text-white rounded-lg text-xs">
                    解析并替换
                  </button>
                  <button type="button" onClick={() => parseBulkTracklist('append')} className="px-3 py-2 bg-bg-tertiary border border-bg-primary text-text-primary rounded-lg text-xs">
                    解析并追加
                  </button>
                </div>
                {bulkParseMessage && <p className="mt-2 text-xs text-text-secondary">{bulkParseMessage}</p>}
              </div>

              <div className="rounded-lg border border-bg-primary bg-bg-tertiary p-3">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium text-text-primary">Spotify 鉴权状态</p>
                    <p className={`text-xs ${spotifyAuth.authenticated ? 'text-accent-green' : 'text-accent-red'}`}>
                      {spotifyAuth.loading ? '检查中...' : spotifyAuth.message}
                    </p>
                  </div>
                  {!spotifyAuth.authenticated && (
                    <a href={spotifyAuth.authUrl} target="_blank" rel="noopener noreferrer" className="px-3 py-2 text-xs rounded-lg bg-[#1DB954] text-white hover:bg-[#1ed760]">
                      去鉴权
                    </a>
                  )}
                </div>
              </div>

              <div className="space-y-3 max-h-[520px] overflow-y-auto pr-1">
                {tracks.map((track, index) => (
                  <div key={index} className="rounded-lg border border-bg-primary bg-bg-tertiary p-3">
                    <div className="flex items-center justify-between mb-2">
                      <p className="text-sm text-text-secondary">歌曲 {index + 1}</p>
                      <button type="button" onClick={() => removeTrack(index)} className="text-xs text-accent-red">删除</button>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                      <input value={track.startTime} onChange={(e) => updateTrack(index, 'startTime', e.target.value)} placeholder="开始时间 0:00" className="bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary" />
                      <input value={track.endTime || ''} onChange={(e) => updateTrack(index, 'endTime', e.target.value)} placeholder="结束时间 3:30" className="bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary" />
                      <input value={track.title} onChange={(e) => updateTrack(index, 'title', e.target.value)} placeholder="歌曲名" className="bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary" />
                      <input value={track.artist} onChange={(e) => updateTrack(index, 'artist', e.target.value)} placeholder="艺术家" className="bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary" />
                      <select value={track.status} onChange={(e) => updateTrack(index, 'status', e.target.value)} className="bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary md:col-span-2">
                        <option value="released">已发行</option>
                        <option value="id">ID / 未发行</option>
                        <option value="remix">Remix</option>
                        <option value="edit">Edit</option>
                      </select>
                    </div>

                    <div className="mt-3 border-t border-bg-primary pt-3">
                      <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                        <p className="text-sm text-text-primary font-medium">Spotify 搜索并绑定</p>
                        <button
                          type="button"
                          onClick={() => searchSpotifyTrack(index)}
                          disabled={(trackSearch[index] || emptySearchState).loading || !spotifyAuth.authenticated}
                          className="bg-[#1DB954] hover:bg-[#1ed760] disabled:bg-bg-secondary text-white text-xs px-3 py-2 rounded-lg"
                        >
                          {(trackSearch[index] || emptySearchState).loading ? '搜索中...' : '搜索 Spotify'}
                        </button>
                      </div>

                      {track.spotifyUrl && (
                        <div className="flex items-center gap-2 bg-[#1DB954]/20 text-[#1DB954] px-2 py-1 rounded-md text-xs mb-2 w-fit">
                          <span>已绑定: {track.spotifyId}</span>
                          <button type="button" className="hover:text-white" onClick={() => clearSpotifyBinding(index)}>移除</button>
                        </div>
                      )}

                      {(trackSearch[index] || emptySearchState).error && (
                        <p className="text-xs text-accent-red mb-2">{(trackSearch[index] || emptySearchState).error}</p>
                      )}

                      {(trackSearch[index] || emptySearchState).spotifyResults.length > 0 && (
                        <div className="bg-bg-primary rounded-lg p-2 border border-bg-secondary max-h-40 overflow-y-auto space-y-1">
                          {(trackSearch[index] || emptySearchState).spotifyResults.map((result) => (
                            <button
                              key={`sp-${result.id}`}
                              type="button"
                              onClick={() => selectSpotifyResult(index, result)}
                              className="w-full text-left p-2 rounded-md hover:bg-bg-secondary border border-transparent hover:border-[#1DB954]/40"
                            >
                              <p className="text-sm text-text-primary truncate">{result.name}</p>
                              <p className="text-xs text-text-secondary truncate">{result.artist}</p>
                            </button>
                          ))}
                        </div>
                      )}
                    </div>

                    <div className="mt-3 border-t border-bg-primary pt-3">
                      <p className="text-sm text-text-primary font-medium mb-2">网易云链接（手动粘贴）</p>
                      <input
                        type="url"
                        value={track.neteaseUrl || ''}
                        onChange={(e) => updateTrack(index, 'neteaseUrl', e.target.value)}
                        className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary"
                        placeholder="https://music.163.com/#/song?id=xxxx"
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="flex items-center gap-3">
              <button onClick={handleSave} disabled={saving} className="px-4 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white disabled:opacity-60">
                {saving ? '保存中...' : '保存修改'}
              </button>
              {message && <span className="text-sm text-text-secondary">{message}</span>}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
