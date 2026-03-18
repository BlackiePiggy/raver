'use client';

import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Navigation from '@/components/Navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { squadApi, Squad } from '@/lib/api/squad';

export default function SquadsListPage() {
  const { user } = useAuth();
  const searchParams = useSearchParams();
  const [squads, setSquads] = useState<Squad[]>([]);
  const [mySquads, setMySquads] = useState<Squad[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'all' | 'my'>('all');

  // 检查 URL 参数
  useEffect(() => {
    const myParam = searchParams.get('my');
    if (myParam === 'true' && user) {
      setActiveTab('my');
    }
  }, [searchParams, user]);

  useEffect(() => {
    loadSquads();
  }, [user]);

  const loadSquads = async () => {
    try {
      setLoading(true);
      const [allSquads, userSquads] = await Promise.all([
        squadApi.getSquads({ isPublic: true }),
        user ? squadApi.getSquads({ my: true }) : Promise.resolve([]),
      ]);
      setSquads(allSquads);
      setMySquads(userSquads);
    } catch (error: any) {
      console.error('加载小队失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const displaySquads = activeTab === 'all' ? squads : mySquads;

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="mb-8 flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
                小队
              </h1>
              <p className="text-text-secondary">
                创建或加入小队，与朋友一起参加电音节
              </p>
            </div>
            {user && (
              <Link
                href="/community/squads/new"
                className="px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
              >
                创建小队
              </Link>
            )}
          </div>

          {/* Tab Navigation */}
          <div className="flex gap-2 mb-6 border-b border-bg-tertiary">
            <button
              onClick={() => setActiveTab('all')}
              className={`px-6 py-3 text-sm font-medium transition-colors relative ${
                activeTab === 'all'
                  ? 'text-primary-purple'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              所有小队
              {activeTab === 'all' && (
                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-purple" />
              )}
            </button>
            {user && (
              <button
                onClick={() => setActiveTab('my')}
                className={`px-6 py-3 text-sm font-medium transition-colors relative ${
                  activeTab === 'my'
                    ? 'text-primary-purple'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                我的小队
                {activeTab === 'my' && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-purple" />
                )}
              </button>
            )}
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="text-text-secondary">加载中...</div>
            </div>
          ) : displaySquads.length === 0 ? (
            <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
              <div className="text-6xl mb-4">🎪</div>
              <h2 className="text-2xl font-bold text-text-primary mb-2">
                {activeTab === 'my' ? '还没有加入任何小队' : '暂无小队'}
              </h2>
              <p className="text-text-secondary mb-6">
                {activeTab === 'my' ? '创建一个小队，邀请朋友一起参加电音节吧！' : '成为第一个创建小队的人！'}
              </p>
              {user && (
                <Link
                  href="/community/squads/new"
                  className="inline-block px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
                >
                  创建小队
                </Link>
              )}
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {displaySquads.map((squad) => (
                <Link key={squad.id} href={`/community/squads/${squad.id}`}>
                  <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary hover:border-primary-purple transition-colors cursor-pointer h-full">
                    <div className="flex items-start gap-4 mb-4">
                      <div className="w-16 h-16 rounded-lg bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-2xl flex-shrink-0">
                        {squad.avatarUrl ? (
                          <img src={squad.avatarUrl} alt={squad.name} className="w-full h-full object-cover rounded-lg" />
                        ) : (
                          '🎪'
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <h3 className="text-lg font-bold text-text-primary mb-1 truncate">
                          {squad.name}
                        </h3>
                        <p className="text-sm text-text-secondary">
                          {squad.leader.displayName || squad.leader.username} 创建
                        </p>
                      </div>
                    </div>
                    {squad.description && (
                      <p className="text-sm text-text-secondary mb-4 line-clamp-2">
                        {squad.description}
                      </p>
                    )}
                    <div className="flex items-center gap-4 text-sm text-text-secondary">
                      <span>👥 {squad._count?.members || 0} 成员</span>
                      <span>💬 {squad._count?.messages || 0} 消息</span>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
