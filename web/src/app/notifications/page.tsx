'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { notificationApi } from '@/lib/api/notification';
import { squadApi } from '@/lib/api/squad';

export default function NotificationsPage() {
  const router = useRouter();
  const { user } = useAuth();
  const [notifications, setNotifications] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      loadNotifications();
    }
  }, [user]);

  const loadNotifications = async () => {
    try {
      setLoading(true);
      const data = await notificationApi.getNotifications();
      setNotifications(data);
    } catch (error: any) {
      console.error('加载通知失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleInvite = async (inviteId: string, accept: boolean) => {
    try {
      setProcessing(inviteId);
      await squadApi.handleInvite(inviteId, accept);
      // 重新加载通知
      await loadNotifications();
      if (accept) {
        alert('已加入小队');
      }
    } catch (error: any) {
      alert(error.message || '处理邀请失败');
    } finally {
      setProcessing(null);
    }
  };

  if (!user) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px]">
          <div className="max-w-4xl mx-auto px-6 py-8">
            <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
              <div className="text-6xl mb-4">🔒</div>
              <h2 className="text-2xl font-bold text-text-primary mb-2">
                请先登录
              </h2>
              <button
                onClick={() => router.push('/login')}
                className="mt-6 px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
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
        <div className="max-w-4xl mx-auto px-6 py-8">
          <div className="mb-8">
            <h1 className="text-4xl font-bold bg-gradient-to-r from-primary-purple to-primary-blue bg-clip-text text-transparent mb-4">
              我的消息
            </h1>
            <p className="text-text-secondary">
              查看你的所有通知和消息
            </p>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="text-text-secondary">加载中...</div>
            </div>
          ) : (
            <div className="space-y-6">
              {/* 小队邀请 */}
              {notifications?.squadInvites && notifications.squadInvites.length > 0 && (
                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
                  <h2 className="text-xl font-bold text-text-primary mb-4 flex items-center gap-2">
                    <span>🎪</span>
                    <span>小队邀请</span>
                    <span className="h-6 min-w-[24px] px-2 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center">
                      {notifications.squadInvites.length}
                    </span>
                  </h2>
                  <div className="space-y-3">
                    {notifications.squadInvites.map((invite: any) => (
                      <div key={invite.id} className="bg-bg-primary rounded-lg p-4 flex items-center gap-4">
                        <div className="w-12 h-12 rounded-lg bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-2xl flex-shrink-0">
                          {invite.squad.avatarUrl ? (
                            <img src={invite.squad.avatarUrl} alt={invite.squad.name} className="w-full h-full object-cover rounded-lg" />
                          ) : (
                            '🎪'
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm text-text-primary">
                            <span className="font-semibold">{invite.inviter.displayName || invite.inviter.username}</span>
                            {' '}邀请你加入小队{' '}
                            <span className="font-semibold">{invite.squad.name}</span>
                          </p>
                          <p className="text-xs text-text-secondary mt-1">
                            {new Date(invite.createdAt).toLocaleString('zh-CN')}
                          </p>
                        </div>
                        <div className="flex gap-2 flex-shrink-0">
                          <button
                            onClick={() => handleInvite(invite.id, true)}
                            disabled={processing === invite.id}
                            className="px-4 py-2 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors text-sm disabled:opacity-50"
                          >
                            {processing === invite.id ? '处理中...' : '接受'}
                          </button>
                          <button
                            onClick={() => handleInvite(invite.id, false)}
                            disabled={processing === invite.id}
                            className="px-4 py-2 bg-bg-tertiary hover:bg-bg-primary border border-bg-primary text-text-secondary rounded-lg transition-colors text-sm disabled:opacity-50"
                          >
                            拒绝
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* 暂无通知 */}
              {(!notifications?.squadInvites || notifications.squadInvites.length === 0) && (
                <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
                  <div className="text-6xl mb-4">📭</div>
                  <h2 className="text-2xl font-bold text-text-primary mb-2">
                    暂无新消息
                  </h2>
                  <p className="text-text-secondary">
                    当有新的通知时，会在这里显示
                  </p>
                </div>
              )}

              {/* 未来功能提示 */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary opacity-50">
                  <div className="text-3xl mb-3">💬</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">私信消息</h3>
                  <p className="text-sm text-text-secondary">
                    即将上线
                  </p>
                </div>
                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary opacity-50">
                  <div className="text-3xl mb-3">👥</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">好友申请</h3>
                  <p className="text-sm text-text-secondary">
                    即将上线
                  </p>
                </div>
                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary opacity-50">
                  <div className="text-3xl mb-3">❤️</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">点赞收藏</h3>
                  <p className="text-sm text-text-secondary">
                    即将上线
                  </p>
                </div>
                <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary opacity-50">
                  <div className="text-3xl mb-3">💭</div>
                  <h3 className="text-lg font-bold text-text-primary mb-2">评论回复</h3>
                  <p className="text-sm text-text-secondary">
                    即将上线
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
