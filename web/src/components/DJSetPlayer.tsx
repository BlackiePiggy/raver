'use client';

import { useState, useRef, useEffect, useMemo, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import MusicPlayingIcon from './MusicPlayingIcon';
import TracklistUploadModal from './TracklistUploadModal';
import TracklistSelectorModal from './TracklistSelectorModal';
import { useAuth } from '@/contexts/AuthContext';
import { getApiUrl } from '@/lib/config';

interface Track {
  id: string;
  position: number;
  startTime: number;
  endTime?: number;
  title: string;
  artist: string;
  status: 'released' | 'id' | 'remix' | 'edit';
  spotifyUrl?: string;
  spotifyId?: string;
  spotifyUri?: string;
  appleMusicUrl?: string;
  youtubeMusicUrl?: string;
  soundcloudUrl?: string;
  neteaseUrl?: string;
  neteaseId?: string;
  createdAt?: string;
}

interface DJSet {
  id: string;
  title: string;
  videoUrl: string;
  platform: 'youtube' | 'bilibili';
  videoId: string;
  description?: string;
  venue?: string;
  eventName?: string;
  createdAt?: string;
  dj: {
    name: string;
    avatarUrl?: string;
  };
  videoContributor?: ContributorProfile | null;
  tracklistContributor?: ContributorProfile | null;
  tracks: Track[];
}

interface DJSetPlayerProps {
  djSet: DJSet;
}

interface ContributorProfile {
  id: string;
  username: string;
  displayName?: string | null;
  avatarUrl?: string | null;
  bio?: string | null;
  location?: string | null;
  favoriteDJs?: string[];
  favoriteGenres?: string[];
}

const extractYouTubeVideoId = (videoUrl: string): string | null => {
  const patterns = [
    /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
  ];

  for (const pattern of patterns) {
    const match = videoUrl.match(pattern);
    if (match?.[1]) {
      return match[1];
    }
  }

  return null;
};

const isValidYouTubeVideoId = (id: string | undefined): id is string =>
  Boolean(id && /^[a-zA-Z0-9_-]{11}$/.test(id));

const buildBilibiliEmbedUrl = (videoId: string, startAt?: number) => {
  const base = `https://player.bilibili.com/player.html?bvid=${videoId}`;
  if (!startAt || startAt <= 0) {
    return base;
  }
  return `${base}&t=${Math.floor(startAt)}`;
};

function ContributorChip({ label, contributor }: { label: string; contributor?: ContributorProfile | null }) {
  const resolvedName = contributor?.displayName || contributor?.username || 'Unknown';
  const content = (
    <div className="flex items-center gap-2 rounded-xl border border-bg-primary bg-bg-tertiary/60 px-3 py-2 hover:border-primary-blue/40 transition-colors">
      {contributor?.avatarUrl ? (
        <div className="relative h-9 w-9 overflow-hidden rounded-full border border-primary-purple/60">
          <Image src={contributor.avatarUrl} alt={resolvedName} fill className="object-cover" sizes="36px" />
        </div>
      ) : (
        <div className="h-9 w-9 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-sm">
          👤
        </div>
      )}
      <div className="min-w-0">
        <p className="text-[11px] text-text-tertiary">{label}</p>
        <p className="text-sm text-text-primary font-medium truncate">{resolvedName}</p>
        {contributor?.id && (
          <p className="text-[10px] text-text-tertiary truncate">ID: {contributor.id}</p>
        )}
      </div>
    </div>
  );

  if (contributor?.id) {
    return <Link href={`/users/${contributor.id}`}>{content}</Link>;
  }
  return content;
}

export default function DJSetPlayer({ djSet }: DJSetPlayerProps) {
  const router = useRouter();
  const { user, token } = useAuth();
  const [currentTime, setCurrentTime] = useState(0);
  const [activeSongId, setActiveSongId] = useState<string | null>(null);
  const [playerError, setPlayerError] = useState<string | null>(null);
  const [bilibiliStartAt, setBilibiliStartAt] = useState(0);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [showSelectorModal, setShowSelectorModal] = useState(false);
  const [tracklists, setTracklists] = useState<any[]>([]);
  const [selectedTracklistId, setSelectedTracklistId] = useState<string | null>(null);
  const [currentTracks, setCurrentTracks] = useState(djSet.tracks);
  const [currentTracklistInfo, setCurrentTracklistInfo] = useState<any>(null);
  const playerRef = useRef<any>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastPolledRef = useRef<number>(0);
  const songRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const tracklistContainerRef = useRef<HTMLDivElement | null>(null);
  const tracklistHeaderRef = useRef<HTMLDivElement | null>(null);
  const resolvedVideoId = useMemo(() => {
    if (djSet.platform !== 'youtube') {
      return null;
    }
    if (isValidYouTubeVideoId(djSet.videoId)) {
      return djSet.videoId;
    }
    return extractYouTubeVideoId(djSet.videoUrl);
  }, [djSet.platform, djSet.videoId, djSet.videoUrl]);

  const orderedTracks = useMemo(
    () => [...currentTracks].sort((a, b) => a.startTime - b.startTime),
    [currentTracks]
  );
  const tracklistUploadedAt = useMemo(() => {
    const withCreatedAt = currentTracks
      .map((track) => (track.createdAt ? new Date(track.createdAt).getTime() : NaN))
      .filter((value) => !Number.isNaN(value));
    if (withCreatedAt.length === 0) {
      return null;
    }
    return new Date(Math.min(...withCreatedAt));
  }, [currentTracks]);

  useEffect(() => {
    const loadTracklists = async () => {
      try {
        const response = await fetch(getApiUrl(`/dj-sets/${djSet.id}/tracklists`));
        const data = await response.json();
        if (Array.isArray(data)) {
          setTracklists(data);
        }
      } catch (error) {
        console.error('Failed to load tracklists:', error);
      }
    };
    loadTracklists();
  }, [djSet.id]);

  const loadTracklistTracks = async (tracklistId: string | null) => {
    if (tracklistId === null) {
      // Load default tracklist
      setCurrentTracks(djSet.tracks);
      setSelectedTracklistId(null);
      setCurrentTracklistInfo(null);
      return;
    }

    try {
      const response = await fetch(getApiUrl(`/dj-sets/${djSet.id}/tracklists/${tracklistId}`));
      const data = await response.json();
      if (data?.tracks) {
        setCurrentTracks(data.tracks);
        setSelectedTracklistId(tracklistId);
        setCurrentTracklistInfo(data);
      }
    } catch (error) {
      console.error('Failed to load tracklist tracks:', error);
    }
  };

  const handleTracklistUploadSuccess = () => {
    // Reload tracklists
    fetch(getApiUrl(`/dj-sets/${djSet.id}/tracklists`))
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data)) {
          setTracklists(data);
        }
      })
      .catch(console.error);
  };

  const computeActiveSongId = useCallback(
    (time: number): string | null => {
      for (let i = 0; i < orderedTracks.length; i += 1) {
        const track = orderedTracks[i];
        const nextTrack = orderedTracks[i + 1];
        const fallbackEnd = nextTrack?.startTime ?? Number.POSITIVE_INFINITY;
        const endTime =
          track.endTime && track.endTime > track.startTime ? track.endTime : fallbackEnd;

        if (time >= track.startTime && time < endTime) {
          return track.id;
        }
      }
      return null;
    },
    [orderedTracks]
  );

  const updateActiveSong = useCallback(
    (time: number) => {
      const nextActiveId = computeActiveSongId(time);
      setActiveSongId((prev) => (prev === nextActiveId ? prev : nextActiveId));
    },
    [computeActiveSongId]
  );

  const clearTimer = () => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  };

  const startProgressPolling = useCallback(() => {
    clearTimer();
    intervalRef.current = setInterval(() => {
      if (playerRef.current?.getCurrentTime) {
        const now = Date.now();
        if (now - lastPolledRef.current < 220) {
          return;
        }
        lastPolledRef.current = now;
        const time = playerRef.current.getCurrentTime();
        setCurrentTime(time);
        updateActiveSong(time);
      }
    }, 250);
  }, [updateActiveSong]);

  const onPlayerStateChange = useCallback(
    (event: any) => {
      const yt = window.YT;
      if (!yt?.PlayerState) {
        return;
      }

      if (event.data === yt.PlayerState.PLAYING) {
        startProgressPolling();
      }

      if (
        event.data === yt.PlayerState.PAUSED ||
        event.data === yt.PlayerState.ENDED ||
        event.data === yt.PlayerState.CUED
      ) {
        clearTimer();
      }
    },
    [startProgressPolling]
  );

  const initYouTubePlayer = useCallback(() => {
    if (djSet.platform !== 'youtube') {
      return;
    }
    if (!window.YT?.Player) {
      return;
    }
    if (!resolvedVideoId) {
      setPlayerError('该视频不是有效的 YouTube 链接，无法在站内播放器中加载。');
      return;
    }

    if (playerRef.current?.destroy) {
      playerRef.current.destroy();
      playerRef.current = null;
    }

    setPlayerError(null);
    playerRef.current = new window.YT.Player('youtube-player', {
      videoId: resolvedVideoId,
      events: {
        onStateChange: onPlayerStateChange,
        onError: () => {
          setPlayerError('YouTube 播放器加载失败，请打开原始链接播放。');
        },
      },
    });
  }, [djSet.platform, resolvedVideoId, onPlayerStateChange]);

  useEffect(() => {
    updateActiveSong(0);
    if (djSet.platform !== 'youtube') {
      return () => {
        clearTimer();
      };
    }

    if (!window.YT) {
      const tag = document.createElement('script');
      tag.src = 'https://www.youtube.com/iframe_api';
      const firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode?.insertBefore(tag, firstScriptTag);
      window.onYouTubeIframeAPIReady = initYouTubePlayer;
    } else {
      initYouTubePlayer();
    }

    return () => {
      clearTimer();
      if (playerRef.current?.destroy) {
        playerRef.current.destroy();
        playerRef.current = null;
      }
    };
  }, [djSet.platform, initYouTubePlayer, updateActiveSong]);

  const scrollActiveTrackToCenter = useCallback((trackId: string) => {
    const container = tracklistContainerRef.current;
    const activeElement = songRefs.current[trackId];
    if (!container || !activeElement) {
      return;
    }

    const headerHeight = tracklistHeaderRef.current?.offsetHeight ?? 0;
    const containerRect = container.getBoundingClientRect();
    const itemRect = activeElement.getBoundingClientRect();
    const itemTopInScroll = itemRect.top - containerRect.top + container.scrollTop;
    const visibleListHeight = Math.max(container.clientHeight - headerHeight, 1);

    const targetScrollTop =
      itemTopInScroll - headerHeight - (visibleListHeight - itemRect.height) / 2;
    const maxScrollTop = Math.max(container.scrollHeight - container.clientHeight, 0);
    const clampedScrollTop = Math.min(Math.max(targetScrollTop, 0), maxScrollTop);

    container.scrollTo({
      top: clampedScrollTop,
      behavior: 'smooth',
    });
  }, []);

  useEffect(() => {
    if (!activeSongId) {
      return;
    }
    scrollActiveTrackToCenter(activeSongId);
  }, [activeSongId, scrollActiveTrackToCenter]);

  const seekToTrack = (track: Track) => {
    if (djSet.platform === 'youtube' && playerRef.current?.seekTo) {
      playerRef.current.seekTo(track.startTime, true);
      playerRef.current.playVideo();
    }
    if (djSet.platform === 'bilibili') {
      setBilibiliStartAt(track.startTime);
    }

    setCurrentTime(track.startTime);
    updateActiveSong(track.startTime);
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'released':
        return 'Released';
      case 'id':
        return 'ID';
      case 'remix':
        return 'Remix';
      case 'edit':
        return 'Edit';
      default:
        return 'Released';
    }
  };

  const getStatusLabelClass = (status: string) => {
    switch (status) {
      case 'id':
        return 'border-amber-400/50 bg-amber-400/10 text-amber-200';
      case 'remix':
        return 'border-cyan-400/50 bg-cyan-400/10 text-cyan-200';
      case 'edit':
        return 'border-fuchsia-400/50 bg-fuchsia-400/10 text-fuchsia-200';
      default:
        return 'border-emerald-400/50 bg-emerald-400/10 text-emerald-200';
    }
  };

  const formatDateTime = (value?: string | Date | null) => {
    if (!value) {
      return '未知';
    }
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      return '未知';
    }
    return date.toLocaleString('zh-CN');
  };

  return (
    <div className="flex flex-col lg:flex-row gap-6 max-w-7xl mx-auto p-6">
      <div className="lg:w-2/3">
        <button
          onClick={() => router.back()}
          className="mb-4 text-text-secondary hover:text-text-primary transition-colors flex items-center gap-2"
        >
          <span>←</span>
          <span>返回</span>
        </button>

        <div className="bg-black rounded-xl overflow-hidden shadow-2xl border border-bg-tertiary">
          {djSet.platform === 'youtube' ? (
            resolvedVideoId ? (
              <div id="youtube-player" className="aspect-video w-full"></div>
            ) : (
              <div className="aspect-video w-full flex items-center justify-center bg-bg-tertiary text-text-secondary text-sm">
                无法解析 YouTube 视频 ID，请使用下方原始链接打开
              </div>
            )
          ) : (
            <iframe
              key={`bili-${bilibiliStartAt}`}
              src={buildBilibiliEmbedUrl(djSet.videoId, bilibiliStartAt)}
              className="aspect-video w-full"
              allowFullScreen
              title={djSet.title}
            />
          )}
        </div>
        {playerError && (
          <div className="mt-3 p-3 rounded-lg border border-accent-red/40 bg-accent-red/10 text-sm text-accent-red">
            {playerError}
          </div>
        )}

        <div className="mt-3 p-3 bg-bg-tertiary rounded-lg border border-bg-primary">
          <div className="flex items-start gap-2 text-xs text-text-tertiary">
            <span>ℹ️</span>
            <div>
              <p className="mb-1">
                <strong>视频来源:</strong> {djSet.platform === 'youtube' ? 'YouTube' : 'Bilibili'}
              </p>
              <p className="mb-1">
                <strong>原始链接:</strong>{' '}
                <a
                  href={djSet.videoUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary-blue hover:underline"
                >
                  {djSet.videoUrl}
                </a>
              </p>
              <p className="text-text-tertiary/80">
                本站仅提供视频嵌入展示，所有视频内容版权归原作者所有。
                如有侵权，请联系我们删除。
              </p>
            </div>
          </div>
        </div>

        <div className="mt-4 bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
          <h1 className="text-3xl font-bold text-text-primary mb-3">{djSet.title}</h1>
          <div className="flex items-center gap-3 mb-4">
            {djSet.dj.avatarUrl ? (
              <div className="relative w-12 h-12">
                <Image
                  src={djSet.dj.avatarUrl}
                  alt={djSet.dj.name}
                  fill
                  className="rounded-full border-2 border-primary-purple object-cover"
                  sizes="48px"
                />
              </div>
            ) : (
              <div className="w-12 h-12 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-xl">
                🎧
              </div>
            )}
            <div>
              <span className="text-text-secondary text-lg block">{djSet.dj.name}</span>
              {(djSet.venue || djSet.eventName) && (
                <div className="flex items-center gap-2 text-sm text-text-tertiary">
                  {djSet.venue && <span>📍 {djSet.venue}</span>}
                  {djSet.eventName && <span>🎪 {djSet.eventName}</span>}
                </div>
              )}
            </div>
          </div>
          {djSet.description && (
            <p className="text-text-secondary">{djSet.description}</p>
          )}

          <div className="mt-4 rounded-lg border border-bg-primary bg-bg-tertiary/50 px-3 py-2 text-xs text-text-secondary space-y-1">
            <p>视频上传时间：{formatDateTime(djSet.createdAt)}</p>
            <p>Tracklist 上传时间：{tracklistUploadedAt ? formatDateTime(tracklistUploadedAt) : '暂无 Tracklist'}</p>
          </div>

          <div className="mt-5 grid grid-cols-1 md:grid-cols-2 gap-3">
            <ContributorChip label="视频贡献者" contributor={djSet.videoContributor} />
            <ContributorChip label="Tracklist 贡献者" contributor={djSet.tracklistContributor} />
          </div>
        </div>
      </div>

      <div className="lg:w-1/3">
        <div
          ref={tracklistContainerRef}
          className="bg-bg-secondary rounded-xl px-0 pb-0 pt-0 shadow-xl max-h-[700px] overflow-y-auto border border-bg-tertiary"
        >
          <div
            ref={tracklistHeaderRef}
            className="sticky top-0 z-50 -mt-0 px-2 pt-2 pb-3 bg-bg-secondary/100 border-b border-bg-primary/80"
          >
            <div className="flex items-center justify-between mb-2">
              <h2 className="text-xl font-bold text-text-primary leading-none">
                歌单 ({currentTracks.length})
              </h2>
              {user && token && (
                <button
                  onClick={() => setShowUploadModal(true)}
                  className="text-xs px-3 py-1.5 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
                >
                  上传我的 Tracklist
                </button>
              )}
            </div>

            {/* Tracklist Selector Button */}
            <button
              onClick={() => setShowSelectorModal(true)}
              className="w-full mb-2 px-3 py-2 bg-bg-tertiary hover:bg-bg-primary border border-bg-primary hover:border-primary-purple rounded-lg transition-all text-left flex items-center justify-between group"
            >
              <div className="flex items-center gap-2 flex-1 min-w-0">
                {currentTracklistInfo?.contributor?.avatarUrl ? (
                  <div className="relative w-6 h-6 rounded-full overflow-hidden flex-shrink-0">
                    <Image
                      src={currentTracklistInfo.contributor.avatarUrl}
                      alt="上传者"
                      fill
                      className="object-cover"
                      sizes="24px"
                    />
                  </div>
                ) : selectedTracklistId ? (
                  <div className="w-6 h-6 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-xs text-white flex-shrink-0">
                    {currentTracklistInfo?.contributor?.displayName?.charAt(0) ||
                     currentTracklistInfo?.contributor?.username?.charAt(0) || '?'}
                  </div>
                ) : (
                  <div className="w-6 h-6 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-xs flex-shrink-0">
                    🎵
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <div className="text-sm text-text-primary font-medium truncate">
                    {selectedTracklistId
                      ? currentTracklistInfo?.title ||
                        `${currentTracklistInfo?.contributor?.displayName ||
                          currentTracklistInfo?.contributor?.username || '匿名'} 的版本`
                      : '默认 Tracklist'}
                  </div>
                  {tracklists.length > 0 && (
                    <div className="text-xs text-text-tertiary">
                      点击查看全部 {tracklists.length + 1} 个版本
                    </div>
                  )}
                </div>
              </div>
              <svg
                className="w-4 h-4 text-text-tertiary group-hover:text-primary-purple transition-colors flex-shrink-0"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>

            <p className="text-xs text-text-tertiary">
              当前时间：{formatTime(currentTime)} · 点击任意歌曲可跳转
            </p>
          </div>

          <div className="space-y-2 pt-3">
            {orderedTracks.map((track) => {
              const isActive = activeSongId === track.id;

              return (
                <div
                  key={track.id}
                  ref={(el) => {
                    songRefs.current[track.id] = el;
                  }}
                  className={`p-2.5 rounded-xl cursor-pointer transition-all duration-300 hover:-translate-y-[1px] ${
                    isActive
                      ? 'bg-primary-purple/90 shadow-xl scale-[1.02] border border-primary-blue/60 transform'
                      : 'bg-bg-tertiary/70 hover:bg-bg-primary border border-transparent hover:border-primary-purple/30'
                  }`}
                  onClick={() => seekToTrack(track)}
                  title="点击跳转到此歌曲"
                >
                  <div className="flex items-start gap-2.5">
                    <div className="flex-shrink-0 w-5 flex items-center justify-center mt-0.5">
                      {isActive ? (
                        <MusicPlayingIcon />
                      ) : (
                        <span className="text-text-tertiary text-xs">{track.position}</span>
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5 mb-0.5 flex-wrap">
                        <span className="text-[11px] text-text-secondary font-mono">
                          {formatTime(track.startTime)}
                        </span>
                        <span
                          className={`inline-flex items-center rounded-md border px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${getStatusLabelClass(track.status)}`}
                        >
                          {getStatusLabel(track.status)}
                        </span>
                        {isActive && (
                          <span className="text-[10px] px-1.5 py-0.5 rounded-md bg-primary-blue/20 text-primary-blue font-semibold animate-pulse">
                            正在播放
                          </span>
                        )}
                      </div>

                      <div className="flex items-start justify-between gap-2">
                        <div className="flex-1 min-w-0">
                          <h3 className={`font-semibold truncate leading-tight ${isActive ? 'text-white text-base' : 'text-text-primary text-sm'}`}>
                            {track.title}
                          </h3>
                          <p className={`text-xs truncate ${isActive ? 'text-white/80' : 'text-text-secondary'}`}>
                            {track.artist}
                          </p>
                        </div>

                        {(track.spotifyUrl || track.neteaseUrl) && (
                          <div className="flex items-center gap-1.5 flex-shrink-0 mt-0.5">
                            {track.spotifyUrl && (
                              <a
                                href={track.spotifyUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="w-6 h-6 flex items-center justify-center bg-[#1DB954] hover:bg-[#1ed760] rounded-full transition-all hover:scale-110"
                                onClick={(e) => e.stopPropagation()}
                                title="在 Spotify 收听"
                              >
                                <svg className="w-3.5 h-3.5 text-white" fill="currentColor" viewBox="0 0 24 24">
                                  <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z" />
                                </svg>
                              </a>
                            )}
                            {track.neteaseUrl && (
                              <a
                                href={track.neteaseUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="w-7 h-7 flex items-center justify-center rounded-full transition-all hover:scale-110 hover:opacity-85"
                                onClick={(e) => e.stopPropagation()}
                                title="在网易云音乐收听"
                              >
                                <img
                                  src="/icons/netease.svg"
                                  alt="网易云音乐"
                                  className="w-7 h-7"
                                />
                              </a>
                            )}
                          </div>
                        )}
                      </div>

                      {track.status === 'id' && (
                        <span className="text-[10px] text-accent-yellow mt-1 block">
                          未发行 ID
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

        </div>
      </div>

      {showSelectorModal && (
        <TracklistSelectorModal
          setId={djSet.id}
          setTitle={djSet.title}
          defaultContributor={djSet.videoContributor || null}
          currentTracklistId={selectedTracklistId}
          onSelect={loadTracklistTracks}
          onClose={() => setShowSelectorModal(false)}
        />
      )}

      {showUploadModal && token && (
        <TracklistUploadModal
          setId={djSet.id}
          token={token}
          onClose={() => setShowUploadModal(false)}
          onSuccess={handleTracklistUploadSuccess}
        />
      )}
    </div>
  );
}

declare global {
  interface Window {
    YT: any;
    onYouTubeIframeAPIReady: () => void;
  }
}
