'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import MusicPlayingIcon from './MusicPlayingIcon';

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
  appleMusicUrl?: string;
  youtubeMusicUrl?: string;
  soundcloudUrl?: string;
  neteaseUrl?: string;
  neteaseId?: string;
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
  dj: {
    name: string;
    avatarUrl?: string;
  };
  tracks: Track[];
}

interface DJSetPlayerProps {
  djSet: DJSet;
}

export default function DJSetPlayer({ djSet }: DJSetPlayerProps) {
  const router = useRouter();
  const [currentTime, setCurrentTime] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTrack, setCurrentTrack] = useState<Track | null>(null);
  const playerRef = useRef<any>(null);
  const bilibiliIframeRef = useRef<HTMLIFrameElement>(null);

  useEffect(() => {
    if (djSet.platform === 'youtube') {
      // Load YouTube IFrame API
      if (!window.YT) {
        const tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        const firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode?.insertBefore(tag, firstScriptTag);

        window.onYouTubeIframeAPIReady = () => {
          initYouTubePlayer();
        };
      } else if (window.YT) {
        initYouTubePlayer();
      }
    }
  }, [djSet.videoId]);

  const initYouTubePlayer = () => {
    playerRef.current = new window.YT.Player('youtube-player', {
      videoId: djSet.videoId,
      events: {
        onStateChange: onPlayerStateChange,
      },
    });

    // Update current time
    setInterval(() => {
      if (playerRef.current?.getCurrentTime) {
        const time = playerRef.current.getCurrentTime();
        setCurrentTime(time);
        updateCurrentTrack(time);
      }
    }, 1000);
  };

  const onPlayerStateChange = (event: any) => {
    setIsPlaying(event.data === window.YT.PlayerState.PLAYING);
  };

  const updateCurrentTrack = (time: number) => {
    const track = djSet.tracks.find(
      t => t.startTime <= time && (!t.endTime || t.endTime > time)
    );
    setCurrentTrack(track || null);
  };

  const seekToTrack = (track: Track) => {
    if (djSet.platform === 'youtube' && playerRef.current?.seekTo) {
      playerRef.current.seekTo(track.startTime, true);
      playerRef.current.playVideo();
    } else if (djSet.platform === 'bilibili') {
      // Bilibili: 重新加载iframe with time parameter
      const newUrl = `https://player.bilibili.com/player.html?bvid=${djSet.videoId}&t=${track.startTime}`;
      if (bilibiliIframeRef.current) {
        bilibiliIframeRef.current.src = newUrl;
      }
    }
    setCurrentTime(track.startTime);
    updateCurrentTrack(track.startTime);
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'released':
        return '🎵';
      case 'id':
        return '🆔';
      case 'remix':
        return '🎹';
      case 'edit':
        return '✂️';
      default:
        return '🎵';
    }
  };

  return (
    <div className="flex flex-col lg:flex-row gap-6 max-w-7xl mx-auto p-6">
      {/* Video Player Section */}
      <div className="lg:w-2/3">
        {/* Back Button */}
        <button
          onClick={() => router.back()}
          className="mb-4 text-text-secondary hover:text-text-primary transition-colors flex items-center gap-2"
        >
          <span>←</span>
          <span>返回</span>
        </button>

        <div className="bg-black rounded-xl overflow-hidden shadow-2xl border border-bg-tertiary">
          {djSet.platform === 'youtube' ? (
            <div id="youtube-player" className="aspect-video w-full"></div>
          ) : (
            <iframe
              ref={bilibiliIframeRef}
              src={`https://player.bilibili.com/player.html?bvid=${djSet.videoId}`}
              className="aspect-video w-full"
              allowFullScreen
            />
          )}
        </div>

        {/* Video Source Info */}
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

        {/* Set Info */}
        <div className="mt-4 bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
          <h1 className="text-3xl font-bold text-text-primary mb-3">{djSet.title}</h1>
          <div className="flex items-center gap-3 mb-4">
            {djSet.dj.avatarUrl ? (
              <img
                src={djSet.dj.avatarUrl}
                alt={djSet.dj.name}
                className="w-12 h-12 rounded-full border-2 border-primary-purple"
              />
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
        </div>
      </div>

      {/* Tracklist Section */}
      <div className="lg:w-1/3">
        <div className="bg-bg-secondary rounded-xl p-5 shadow-xl max-h-[700px] overflow-y-auto border border-bg-tertiary">
          <h2 className="text-xl font-bold text-text-primary mb-4 sticky top-0 bg-bg-secondary pb-2 z-10">
            歌单 ({djSet.tracks.length})
          </h2>

          <div className="space-y-2">
            {djSet.tracks.map((track) => (
              <div
                key={track.id}
                className={`p-4 rounded-lg cursor-pointer transition-all duration-300 ${
                  currentTrack?.id === track.id
                    ? 'bg-primary-purple shadow-2xl scale-105 border-2 border-primary-blue transform'
                    : 'bg-bg-tertiary hover:bg-bg-primary border border-transparent hover:border-primary-purple/30 scale-100'
                }`}
                onClick={() => seekToTrack(track)}
                title="点击跳转到此歌曲"
              >
                <div className="flex items-start gap-3">
                  {/* Music Playing Icon */}
                  <div className="flex-shrink-0 w-6 flex items-center justify-center">
                    {currentTrack?.id === track.id ? (
                      <MusicPlayingIcon />
                    ) : (
                      <span className="text-text-tertiary text-sm">{track.position}</span>
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1 flex-wrap">
                      <span className="text-xs text-text-secondary font-mono">
                        {formatTime(track.startTime)}
                      </span>
                      <span className="text-lg">{getStatusIcon(track.status)}</span>
                      {currentTrack?.id === track.id && (
                        <span className="text-xs text-primary-blue font-semibold animate-pulse">
                          正在播放
                        </span>
                      )}
                    </div>

                    <div className="flex items-start justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <h3 className={`font-semibold truncate ${
                          currentTrack?.id === track.id ? 'text-white text-lg' : 'text-text-primary'
                        }`}>
                          {track.title}
                        </h3>
                        <p className={`text-sm truncate ${
                          currentTrack?.id === track.id ? 'text-white/80' : 'text-text-secondary'
                        }`}>
                          {track.artist}
                        </p>
                      </div>

                      {/* Streaming Platform Icons */}
                      {(track.spotifyUrl || track.neteaseUrl) && (
                        <div className="flex items-center gap-2 flex-shrink-0">
                          {track.spotifyUrl && (
                            <a
                              href={track.spotifyUrl}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="w-8 h-8 flex items-center justify-center bg-[#1DB954] hover:bg-[#1ed760] rounded-full transition-colors"
                              onClick={(e) => e.stopPropagation()}
                              title="在 Spotify 收听"
                            >
                              <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
                              </svg>
                            </a>
                          )}
                          {track.neteaseUrl && (
                            <a
                              href={track.neteaseUrl}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="w-8 h-8 flex items-center justify-center bg-[#EC4141] hover:bg-[#ff4d4d] rounded-full transition-colors"
                              onClick={(e) => e.stopPropagation()}
                              title="在网易云音乐收听"
                            >
                              <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.562 17.376c-.175.15-.4.225-.625.225-.25 0-.5-.1-.675-.275l-3.262-3.262-3.262 3.262c-.35.35-.925.35-1.275 0-.35-.35-.35-.925 0-1.275l3.262-3.262-3.262-3.262c-.35-.35-.35-.925 0-1.275.35-.35.925-.35 1.275 0l3.262 3.262 3.262-3.262c.35-.35.925-.35 1.275 0 .35.35.35.925 0 1.275l-3.262 3.262 3.262 3.262c.375.35.4.925.025 1.3z"/>
                              </svg>
                            </a>
                          )}
                        </div>
                      )}
                    </div>

                    {track.status === 'id' && (
                      <span className="text-xs text-accent-yellow mt-2 block">
                        未发行 ID
                      </span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Usage Hint */}
          <div className="mt-4 p-3 bg-bg-tertiary/50 rounded-lg border border-bg-primary">
            <p className="text-xs text-text-tertiary text-center">
              💡 点击任意歌曲可跳转到对应时间
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// TypeScript declarations for YouTube API
declare global {
  interface Window {
    YT: any;
    onYouTubeIframeAPIReady: () => void;
  }
}