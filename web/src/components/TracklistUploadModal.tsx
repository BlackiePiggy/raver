'use client';

import { useState } from 'react';
import { getApiUrl } from '@/lib/config';

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

interface TracklistUploadModalProps {
  setId: string;
  token: string;
  onClose: () => void;
  onSuccess: () => void;
}

const parseTimeParts = (time: string): number | null => {
  const trimmed = time.trim();
  if (!trimmed) return null;
  const parts = trimmed.split(':').map((item) => Number(item.trim()));
  if (parts.some((value) => Number.isNaN(value))) return null;
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  return null;
};

const formatSecondsToTime = (seconds: number): string => {
  const safe = Math.max(0, Math.floor(seconds));
  const h = Math.floor(safe / 3600);
  const m = Math.floor((safe % 3600) / 60);
  const s = safe % 60;
  if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  return `${m}:${s.toString().padStart(2, '0')}`;
};

const inferTrackStatus = (text: string): TrackInput['status'] => {
  const normalized = text.toLowerCase();
  if (normalized.includes('unreleased') || /\bid\b/.test(normalized)) return 'id';
  if (normalized.includes(' edit') || normalized.includes('(edit')) return 'edit';
  if (normalized.includes('remix') || normalized.includes(' flip')) return 'remix';
  return 'released';
};

const parseTrackLine = (line: string) => {
  const cleaned = line.trim();
  if (!cleaned) return null;
  const match = cleaned.match(/^(\d{1,2}:\d{2}(?::\d{2})?)\s*[-–]\s*(.+)$/);
  if (!match) return null;
  const startSeconds = parseTimeParts(match[1]);
  if (startSeconds === null) return null;
  const details = match[2].trim();
  const splitIndex = details.indexOf(' - ');
  const artist = splitIndex > -1 ? details.slice(0, splitIndex).trim() : 'Unknown';
  const title = splitIndex > -1 ? details.slice(splitIndex + 3).trim() : details;
  return { startSeconds, title, artist, status: inferTrackStatus(details) };
};

export default function TracklistUploadModal({ setId, token, onClose, onSuccess }: TracklistUploadModalProps) {
  const [title, setTitle] = useState('');
  const [bulkTrackText, setBulkTrackText] = useState('');
  const [tracks, setTracks] = useState<TrackInput[]>([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const parseBulkTracklist = () => {
    if (!bulkTrackText.trim()) {
      setMessage('请先粘贴歌单文本');
      return;
    }

    const parsedLines = bulkTrackText
      .split('\n')
      .map((line) => parseTrackLine(line))
      .filter((item): item is NonNullable<ReturnType<typeof parseTrackLine>> => item !== null)
      .sort((a, b) => a.startSeconds - b.startSeconds);

    if (parsedLines.length === 0) {
      setMessage('未识别到可解析行，请使用"时间戳 - 歌手 - 歌名"格式');
      return;
    }

    const generatedTracks: TrackInput[] = parsedLines.map((item, index) => ({
      position: index + 1,
      startTime: formatSecondsToTime(item.startSeconds),
      endTime: index < parsedLines.length - 1 ? formatSecondsToTime(parsedLines[index + 1].startSeconds) : undefined,
      title: item.title,
      artist: item.artist,
      status: item.status,
    }));

    setTracks(generatedTracks);
    setMessage(`解析成功：${generatedTracks.length} 首歌曲`);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (tracks.length === 0) {
      setMessage('请先解析歌单');
      return;
    }

    setLoading(true);
    try {
      const tracksData = tracks.map((track) => ({
        position: track.position,
        startTime: parseTimeParts(track.startTime) || 0,
        endTime: track.endTime ? parseTimeParts(track.endTime) : undefined,
        title: track.title,
        artist: track.artist,
        status: track.status,
        spotifyUrl: track.spotifyUrl,
        spotifyId: track.spotifyId,
        spotifyUri: track.spotifyUri,
        neteaseUrl: track.neteaseUrl,
        neteaseId: track.neteaseId,
      }));

      const response = await fetch(getApiUrl(`/dj-sets/${setId}/tracklists`), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ title: title.trim() || undefined, tracks: tracksData }),
      });

      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.error || '上传失败');
      }

      setMessage('Tracklist 上传成功！');
      setTimeout(() => {
        onSuccess();
        onClose();
      }, 1000);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '上传失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" onClick={onClose}>
      <div className="bg-bg-secondary rounded-xl max-w-3xl w-full max-h-[90vh] overflow-y-auto p-6 border border-bg-tertiary" onClick={(e) => e.stopPropagation()}>
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-2xl font-bold text-text-primary">上传我的 Tracklist</h2>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary text-2xl">&times;</button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-text-secondary mb-2 text-sm">Tracklist 标题（可选）</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
              placeholder="例如：我的版本"
            />
          </div>

          <div>
            <label className="block text-text-secondary mb-2 text-sm">批量粘贴歌单</label>
            <p className="text-xs text-text-tertiary mb-2">
              格式：每行 <code>开始时间 - 歌手 - 歌曲名</code>
            </p>
            <textarea
              value={bulkTrackText}
              onChange={(e) => setBulkTrackText(e.target.value)}
              className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none font-mono text-xs"
              rows={12}
              placeholder="0:00 - Artist - Song Title&#10;1:40 - Another Artist - Another Song"
            />
            <button
              type="button"
              onClick={parseBulkTracklist}
              className="mt-2 px-4 py-2 bg-primary-blue hover:bg-primary-purple text-white rounded-lg text-sm"
            >
              解析歌单
            </button>
          </div>

          {tracks.length > 0 && (
            <div className="bg-bg-tertiary rounded-lg p-4 border border-bg-primary">
              <p className="text-sm text-text-primary mb-2">已解析 {tracks.length} 首歌曲</p>
              <div className="max-h-40 overflow-y-auto space-y-1">
                {tracks.slice(0, 5).map((track, index) => (
                  <div key={index} className="text-xs text-text-secondary">
                    {track.position}. {track.artist} - {track.title} ({track.startTime})
                  </div>
                ))}
                {tracks.length > 5 && <p className="text-xs text-text-tertiary">...还有 {tracks.length - 5} 首</p>}
              </div>
            </div>
          )}

          {message && (
            <p className={`text-sm ${message.includes('成功') ? 'text-accent-green' : 'text-text-tertiary'}`}>
              {message}
            </p>
          )}

          <div className="flex gap-3">
            <button
              type="submit"
              disabled={loading || tracks.length === 0}
              className="flex-1 bg-primary-purple hover:bg-primary-blue disabled:bg-bg-tertiary text-white font-semibold py-3 rounded-lg transition-colors"
            >
              {loading ? '上传中...' : '上传 Tracklist'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="px-6 py-3 bg-bg-tertiary border border-bg-primary text-text-primary rounded-lg hover:border-primary-purple"
            >
              取消
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
