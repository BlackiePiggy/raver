'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { getApiUrl } from '@/lib/config';

interface Tracklist {
  id: string;
  setId: string;
  title: string | null;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
  trackCount: number;
  contributor: {
    id: string;
    username: string;
    displayName: string | null;
    avatarUrl: string | null;
  } | null;
}

interface TracklistSelectorModalProps {
  setId: string;
  setTitle: string;
  defaultContributor: {
    id: string;
    username: string;
    displayName?: string | null;
    avatarUrl?: string | null;
    bio?: string | null;
    location?: string | null;
    favoriteGenres?: string[];
    favoriteDJs?: string[];
  } | null;
  currentTracklistId: string | null;
  onSelect: (tracklistId: string | null) => void;
  onClose: () => void;
}

export default function TracklistSelectorModal({
  setId,
  setTitle,
  defaultContributor,
  currentTracklistId,
  onSelect,
  onClose,
}: TracklistSelectorModalProps) {
  const [tracklists, setTracklists] = useState<Tracklist[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [copiedShare, setCopiedShare] = useState<string | null>(null);

  useEffect(() => {
    const loadTracklists = async () => {
      try {
        const response = await fetch(getApiUrl(`/dj-sets/${setId}/tracklists`));
        const data = await response.json();
        if (Array.isArray(data)) {
          setTracklists(data);
        }
      } catch (error) {
        console.error('Failed to load tracklists:', error);
      } finally {
        setLoading(false);
      }
    };
    loadTracklists();
  }, [setId]);

  const filteredTracklists = tracklists.filter((tl) => {
    if (!searchQuery.trim()) return true;
    const query = searchQuery.toLowerCase();
    const title = tl.title?.toLowerCase() || '';
    const username = tl.contributor?.username?.toLowerCase() || '';
    const displayName = tl.contributor?.displayName?.toLowerCase() || '';
    const id = tl.id.toLowerCase();
    return (
      title.includes(query) ||
      username.includes(query) ||
      displayName.includes(query) ||
      id.includes(query)
    );
  });

  const handleSelect = (tracklistId: string | null) => {
    onSelect(tracklistId);
    onClose();
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const copyToClipboard = async (text: string, type: 'id' | 'share', id: string) => {
    try {
      await navigator.clipboard.writeText(text);
      if (type === 'id') {
        setCopiedId(id);
        setTimeout(() => setCopiedId(null), 2000);
      } else {
        setCopiedShare(id);
        setTimeout(() => setCopiedShare(null), 2000);
      }
    } catch (error) {
      console.error('Failed to copy:', error);
    }
  };

  const generateShareText = (tracklist: Tracklist | null, isDefault: boolean) => {
    const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';
    const displayName = isDefault
      ? defaultContributor?.displayName || defaultContributor?.username || '官方'
      : tracklist?.contributor?.displayName || tracklist?.contributor?.username || '匿名';
    const tracklistTitle = isDefault
      ? '默认 Tracklist'
      : tracklist?.title || `${displayName} 的版本`;
    const tracklistId = isDefault ? 'default' : tracklist?.id || '';
    const trackCount = isDefault ? '原始' : `${tracklist?.trackCount || 0} 首`;

    return `🎵 ${setTitle}

📝 Tracklist: ${tracklistTitle}
👤 贡献者: ${displayName}
🎼 歌曲数: ${trackCount}
🆔 ID: ${tracklistId}

🔍 如何使用：
1. 访问 ${baseUrl}
2. 打开这个 DJ Set
3. 点击歌单区域的 Tracklist 选择按钮
4. 在搜索框输入 ID: ${tracklistId}
5. 选择对应的 Tracklist 即可

✨ 快来体验不同版本的 Tracklist 吧！`;
  };

  const handleShare = (tracklist: Tracklist | null, isDefault: boolean) => {
    const shareText = generateShareText(tracklist, isDefault);
    copyToClipboard(shareText, 'share', isDefault ? 'default' : tracklist?.id || '');
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-bg-secondary rounded-2xl max-w-4xl w-full max-h-[85vh] overflow-hidden border border-bg-tertiary shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="bg-gradient-to-r from-primary-purple/20 to-primary-blue/20 border-b border-bg-tertiary px-6 py-4">
          <div className="flex justify-between items-center mb-3">
            <h2 className="text-2xl font-bold text-text-primary">选择 Tracklist</h2>
            <button
              onClick={onClose}
              className="text-text-secondary hover:text-text-primary text-3xl leading-none transition-colors"
            >
              ×
            </button>
          </div>

          {/* Search Bar */}
          <div className="relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="搜索 ID、用户名或 Tracklist 名称..."
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-2.5 pl-10 border border-bg-primary focus:border-primary-purple focus:outline-none"
            />
            <svg
              className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-tertiary"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
          </div>
        </div>

        {/* Content */}
        <div className="overflow-y-auto max-h-[calc(85vh-140px)] p-6">
          {loading ? (
            <div className="flex items-center justify-center py-20">
              <div className="text-text-secondary">加载中...</div>
            </div>
          ) : (
            <div className="space-y-2">
              {/* Default Tracklist */}
              <div
                onClick={() => handleSelect(null)}
                className={`group relative bg-bg-tertiary rounded-lg p-3 border-2 transition-all cursor-pointer hover:border-primary-purple ${
                  currentTracklistId === null
                    ? 'border-primary-purple shadow-glow'
                    : 'border-transparent'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className="flex-shrink-0">
                    {defaultContributor?.avatarUrl ? (
                      <div className="relative w-10 h-10 rounded-full overflow-hidden border-2 border-primary-purple/60">
                        <Image
                          src={defaultContributor.avatarUrl}
                          alt={defaultContributor.displayName || defaultContributor.username}
                          fill
                          className="object-cover"
                          sizes="40px"
                        />
                      </div>
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-lg">
                        🎵
                      </div>
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <h3 className="text-base font-bold text-text-primary">默认 Tracklist</h3>
                      <span className="px-1.5 py-0.5 bg-accent-green/20 text-accent-green text-xs rounded-full">
                        官方
                      </span>
                      {currentTracklistId === null && (
                        <span className="px-1.5 py-0.5 bg-primary-purple/20 text-primary-purple text-xs rounded-full">
                          当前
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-text-secondary">
                      贡献者：{defaultContributor?.displayName || defaultContributor?.username || '官方'}
                    </p>
                  </div>

                  <div className="flex items-center gap-2 flex-shrink-0">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        copyToClipboard('default', 'id', 'default');
                      }}
                      className="px-2 py-1 bg-bg-primary hover:bg-bg-secondary rounded text-xs text-text-secondary hover:text-text-primary transition-colors"
                      title="复制 ID"
                    >
                      {copiedId === 'default' ? '✓ 已复制' : 'default'}
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleShare(null, true);
                      }}
                      className="p-1.5 bg-bg-primary hover:bg-primary-blue/20 rounded transition-colors"
                      title="分享"
                    >
                      {copiedShare === 'default' ? (
                        <span className="text-xs text-accent-green">✓</span>
                      ) : (
                        <svg className="w-4 h-4 text-text-tertiary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                        </svg>
                      )}
                    </button>
                  </div>
                </div>
              </div>

              {/* User Tracklists */}
              {filteredTracklists.length === 0 ? (
                <div className="text-center py-12">
                  <div className="text-6xl mb-4">🎧</div>
                  <p className="text-text-secondary">
                    {searchQuery ? '没有找到匹配的 Tracklist' : '暂无用户上传的 Tracklist'}
                  </p>
                </div>
              ) : (
                filteredTracklists.map((tracklist) => {
                  const displayName =
                    tracklist.contributor?.displayName ||
                    tracklist.contributor?.username ||
                    '匿名用户';
                  const tracklistTitle =
                    tracklist.title || `${displayName} 的版本`;
                  const shortId = tracklist.id.slice(0, 8);

                  return (
                    <div
                      key={tracklist.id}
                      onClick={() => handleSelect(tracklist.id)}
                      className={`group relative bg-bg-tertiary rounded-lg p-3 border-2 transition-all cursor-pointer hover:border-primary-blue ${
                        currentTracklistId === tracklist.id
                          ? 'border-primary-blue shadow-glow'
                          : 'border-transparent'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        {/* Avatar */}
                        <div className="flex-shrink-0">
                          {tracklist.contributor?.avatarUrl ? (
                            <div className="relative w-10 h-10 rounded-full overflow-hidden border-2 border-primary-purple/60">
                              <Image
                                src={tracklist.contributor.avatarUrl}
                                alt={displayName}
                                fill
                                className="object-cover"
                                sizes="40px"
                              />
                            </div>
                          ) : (
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-sm font-bold text-white">
                              {displayName.charAt(0).toUpperCase()}
                            </div>
                          )}
                        </div>

                        {/* Info */}
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-0.5">
                            <h3 className="text-base font-bold text-text-primary truncate">
                              {tracklistTitle}
                            </h3>
                            {currentTracklistId === tracklist.id && (
                              <span className="px-1.5 py-0.5 bg-primary-blue/20 text-primary-blue text-xs rounded-full flex-shrink-0">
                                当前
                              </span>
                            )}
                          </div>

                          <div className="flex items-center gap-2 text-xs text-text-secondary">
                            <span>{displayName}</span>
                            <span>•</span>
                            <span>{tracklist.trackCount} 首</span>
                            <span>•</span>
                            <span>{formatDate(tracklist.createdAt)}</span>
                          </div>
                        </div>

                        {/* Actions */}
                        <div className="flex items-center gap-2 flex-shrink-0">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              copyToClipboard(tracklist.id, 'id', tracklist.id);
                            }}
                            className="px-2 py-1 bg-bg-primary hover:bg-bg-secondary rounded text-xs text-text-secondary hover:text-text-primary font-mono transition-colors"
                            title="复制完整 ID"
                          >
                            {copiedId === tracklist.id ? '✓ 已复制' : `${shortId}...`}
                          </button>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleShare(tracklist, false);
                            }}
                            className="p-1.5 bg-bg-primary hover:bg-primary-blue/20 rounded transition-colors"
                            title="分享"
                          >
                            {copiedShare === tracklist.id ? (
                              <span className="text-xs text-accent-green">✓</span>
                            ) : (
                              <svg className="w-4 h-4 text-text-tertiary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                              </svg>
                            )}
                          </button>
                        </div>
                      </div>

                      {/* Hover Effect */}
                      <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-primary-purple/0 to-primary-blue/0 group-hover:from-primary-purple/5 group-hover:to-primary-blue/5 transition-all pointer-events-none" />
                    </div>
                  );
                })
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="border-t border-bg-tertiary px-6 py-3 bg-bg-primary/50">
          <div className="flex items-center justify-between text-sm text-text-tertiary">
            <span>共 {tracklists.length + 1} 个 Tracklist</span>
            <button
              onClick={onClose}
              className="px-4 py-2 bg-bg-tertiary border border-bg-primary text-text-primary rounded-lg hover:border-primary-purple transition-colors"
            >
              关闭
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
