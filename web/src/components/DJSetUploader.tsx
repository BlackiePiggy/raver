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
}

export default function DJSetUploader() {
  const [djId, setDjId] = useState('');
  const [title, setTitle] = useState('');
  const [videoUrl, setVideoUrl] = useState('');
  const [description, setDescription] = useState('');
  const [tracks, setTracks] = useState<TrackInput[]>([]);
  const [loading, setLoading] = useState(false);

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

  const updateTrack = (index: number, field: keyof TrackInput, value: any) => {
    const newTracks = [...tracks];
    newTracks[index] = { ...newTracks[index], [field]: value };
    setTracks(newTracks);
  };

  const removeTrack = (index: number) => {
    setTracks(tracks.filter((_, i) => i !== index));
  };

  const parseTimeToSeconds = (time: string): number => {
    const parts = time.split(':').map(Number);
    if (parts.length === 2) {
      return parts[0] * 60 + parts[1];
    } else if (parts.length === 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    return 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Create DJ Set
      const setResponse = await fetch(getApiUrl('/dj-sets'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          djId,
          title,
          videoUrl,
          description,
        }),
      });

      if (!setResponse.ok) throw new Error('Failed to create DJ set');

      const djSet = await setResponse.json();

      // Add tracks
      const tracksData = tracks.map((track) => ({
        ...track,
        startTime: parseTimeToSeconds(track.startTime),
        endTime: track.endTime ? parseTimeToSeconds(track.endTime) : undefined,
      }));

      await fetch(getApiUrl(`/dj-sets/${djSet.id}/tracks/batch`), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tracks: tracksData }),
      });

      // Auto-link tracks
      await fetch(getApiUrl(`/dj-sets/${djSet.id}/auto-link`), {
        method: 'POST',
      });

      alert('DJ Set created successfully!');
      // Reset form
      setTitle('');
      setVideoUrl('');
      setDescription('');
      setTracks([]);
    } catch (error) {
      console.error('Error:', error);
      alert('Failed to create DJ set');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-3xl font-bold text-text-primary mb-6">上传 DJ Set</h1>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Basic Info */}
        <div className="bg-bg-secondary rounded-xl p-6 space-y-4 border border-bg-tertiary">
          <h2 className="text-xl font-semibold text-text-primary">基本信息</h2>

          <div>
            <label className="block text-text-secondary mb-2">DJ ID</label>
            <input
              type="text"
              value={djId}
              onChange={(e) => setDjId(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
              required
            />
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
            <label className="block text-text-secondary mb-2">视频 URL</label>
            <input
              type="url"
              value={videoUrl}
              onChange={(e) => setVideoUrl(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
              placeholder="YouTube 或 Bilibili URL"
              required
            />
          </div>

          <div>
            <label className="block text-text-secondary mb-2">描述</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none"
              rows={3}
            />
          </div>
        </div>

        {/* Tracklist */}
        <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold text-text-primary">歌单</h2>
            <button
              type="button"
              onClick={addTrack}
              className="bg-primary-purple hover:bg-primary-blue text-white px-4 py-2 rounded-lg transition-colors"
            >
              + 添加歌曲
            </button>
          </div>

          <div className="space-y-4">
            {tracks.map((track, index) => (
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

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-text-secondary text-sm mb-1">
                      开始时间 (mm:ss)
                    </label>
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
                    <label className="block text-text-secondary text-sm mb-1">
                      结束时间 (可选)
                    </label>
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
                    <label className="block text-text-secondary text-sm mb-1">艺术家</label>
                    <input
                      type="text"
                      value={track.artist}
                      onChange={(e) => updateTrack(index, 'artist', e.target.value)}
                      className="w-full bg-bg-primary text-text-primary rounded-lg px-3 py-2 border border-bg-secondary focus:border-primary-purple focus:outline-none"
                      required
                    />
                  </div>

                  <div className="col-span-2">
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
              </div>
            ))}
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