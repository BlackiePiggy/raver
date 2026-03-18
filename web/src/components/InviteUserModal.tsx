'use client';

import { useState } from 'react';
import { authAPI } from '@/lib/api/auth';
import { squadApi } from '@/lib/api/squad';

interface InviteUserModalProps {
  squadId: string;
  onClose: () => void;
  onSuccess: () => void;
}

export default function InviteUserModal({ squadId, onClose, onSuccess }: InviteUserModalProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Array<{
    id: string;
    username: string;
    displayName?: string;
    avatarUrl?: string;
  }>>([]);
  const [searching, setSearching] = useState(false);
  const [inviting, setInviting] = useState<string | null>(null);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;

    try {
      setSearching(true);
      const results = await authAPI.searchUsers(searchQuery.trim());
      setSearchResults(results);
    } catch (error: any) {
      alert(error.message || '搜索失败');
    } finally {
      setSearching(false);
    }
  };

  const handleInvite = async (userId: string) => {
    try {
      setInviting(userId);
      await squadApi.inviteUser(squadId, userId);
      alert('邀请已发送');
      onSuccess();
      onClose();
    } catch (error: any) {
      alert(error.message || '邀请失败');
    } finally {
      setInviting(null);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={onClose}>
      <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary max-w-md w-full mx-4" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-2xl font-bold text-text-primary mb-4">
          邀请用户
        </h2>

        <div className="mb-4">
          <div className="flex gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              placeholder="搜索用户名..."
              className="flex-1 px-4 py-2 bg-bg-primary border border-bg-tertiary rounded-lg text-text-primary placeholder-text-secondary focus:outline-none focus:border-primary-purple"
            />
            <button
              onClick={handleSearch}
              disabled={searching || !searchQuery.trim()}
              className="px-6 py-2 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {searching ? '搜索中...' : '搜索'}
            </button>
          </div>
        </div>

        <div className="max-h-96 overflow-y-auto space-y-2">
          {searchResults.length === 0 ? (
            <div className="text-center py-8 text-text-secondary text-sm">
              {searchQuery ? '没有找到用户' : '输入用户名进行搜索'}
            </div>
          ) : (
            searchResults.map((user) => (
              <div key={user.id} className="flex items-center gap-3 p-3 bg-bg-primary rounded-lg">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-sm flex-shrink-0">
                  {user.avatarUrl ? (
                    <img src={user.avatarUrl} alt={user.username} className="w-full h-full object-cover rounded-full" />
                  ) : (
                    user.username[0].toUpperCase()
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium text-text-primary truncate">
                    {user.displayName || user.username}
                  </div>
                  <div className="text-xs text-text-secondary">
                    @{user.username}
                  </div>
                </div>
                <button
                  onClick={() => handleInvite(user.id)}
                  disabled={inviting === user.id}
                  className="px-4 py-2 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {inviting === user.id ? '邀请中...' : '邀请'}
                </button>
              </div>
            ))
          )}
        </div>

        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-6 py-2 bg-bg-tertiary hover:bg-bg-primary border border-bg-primary text-text-primary rounded-lg transition-colors"
          >
            关闭
          </button>
        </div>
      </div>
    </div>
  );
}
