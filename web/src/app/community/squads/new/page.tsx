'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { squadApi } from '@/lib/api/squad';

export default function NewSquadPage() {
  const router = useRouter();
  const { user } = useAuth();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isPublic, setIsPublic] = useState(false);
  const [maxMembers, setMaxMembers] = useState(50);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!user) {
      setError('请先登录');
      return;
    }

    if (!name.trim()) {
      setError('请输入小队名称');
      return;
    }

    try {
      setLoading(true);
      setError('');
      const squad = await squadApi.createSquad({
        name: name.trim(),
        description: description.trim() || undefined,
        isPublic,
        maxMembers,
      });
      router.push(`/community/squads/${squad.id}`);
    } catch (err: any) {
      setError(err.message || '创建小队失败');
    } finally {
      setLoading(false);
    }
  };

  if (!user) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px]">
          <div className="max-w-2xl mx-auto px-6 py-8">
            <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
              <div className="text-6xl mb-4">🔒</div>
              <h2 className="text-2xl font-bold text-text-primary mb-2">
                请先登录
              </h2>
              <p className="text-text-secondary mb-6">
                登录后即可创建小队
              </p>
              <button
                onClick={() => router.push('/login')}
                className="px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
              >
                去登录
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <div className="max-w-2xl mx-auto px-6 py-8">
          <div className="mb-8">
            <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
              创建小队
            </h1>
            <p className="text-text-secondary">
              创建一个小队，邀请朋友一起参加电音节
            </p>
          </div>

          <form onSubmit={handleSubmit} className="bg-bg-secondary rounded-xl p-8 border border-bg-tertiary">
            {error && (
              <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 rounded-lg text-red-500 text-sm">
                {error}
              </div>
            )}

            <div className="mb-6">
              <label className="block text-sm font-medium text-text-primary mb-2">
                小队名称 *
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="给你的小队起个名字"
                className="w-full px-4 py-3 bg-bg-primary border border-bg-tertiary rounded-lg text-text-primary placeholder-text-secondary focus:outline-none focus:border-primary-purple"
                maxLength={50}
                required
              />
              <p className="mt-1 text-xs text-text-secondary">
                {name.length}/50
              </p>
            </div>

            <div className="mb-6">
              <label className="block text-sm font-medium text-text-primary mb-2">
                小队简介
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="介绍一下你的小队..."
                className="w-full px-4 py-3 bg-bg-primary border border-bg-tertiary rounded-lg text-text-primary placeholder-text-secondary focus:outline-none focus:border-primary-purple resize-none"
                rows={4}
                maxLength={500}
              />
              <p className="mt-1 text-xs text-text-secondary">
                {description.length}/500
              </p>
            </div>

            <div className="mb-6">
              <label className="block text-sm font-medium text-text-primary mb-2">
                最大成员数
              </label>
              <input
                type="number"
                value={maxMembers}
                onChange={(e) => setMaxMembers(parseInt(e.target.value) || 50)}
                min={2}
                max={200}
                className="w-full px-4 py-3 bg-bg-primary border border-bg-tertiary rounded-lg text-text-primary focus:outline-none focus:border-primary-purple"
              />
              <p className="mt-1 text-xs text-text-secondary">
                设置小队可容纳的最大成员数（2-200人）
              </p>
            </div>

            <div className="mb-8">
              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={isPublic}
                  onChange={(e) => setIsPublic(e.target.checked)}
                  className="w-5 h-5 rounded border-bg-tertiary bg-bg-primary text-primary-purple focus:ring-primary-purple focus:ring-offset-0"
                />
                <div>
                  <div className="text-sm font-medium text-text-primary">
                    公开小队
                  </div>
                  <div className="text-xs text-text-secondary">
                    公开后，其他用户可以在小队列表中看到并申请加入
                  </div>
                </div>
              </label>
            </div>

            <div className="flex gap-4">
              <button
                type="button"
                onClick={() => router.back()}
                className="flex-1 px-6 py-3 bg-bg-tertiary hover:bg-bg-primary border border-bg-primary text-text-primary rounded-lg transition-colors"
                disabled={loading}
              >
                取消
              </button>
              <button
                type="submit"
                className="flex-1 px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                disabled={loading || !name.trim()}
              >
                {loading ? '创建中...' : '创建小队'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
