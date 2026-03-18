'use client';

import { useEffect, useState, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Navigation from '@/components/Navigation';
import InviteUserModal from '@/components/InviteUserModal';
import { useAuth } from '@/contexts/AuthContext';
import { squadApi, Squad, SquadMessage } from '@/lib/api/squad';

export default function SquadDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { user } = useAuth();
  const [squad, setSquad] = useState<Squad | null>(null);
  const [messages, setMessages] = useState<SquadMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [showInviteModal, setShowInviteModal] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const squadId = params.id as string;

  useEffect(() => {
    loadSquad();
  }, [squadId, user]);

  useEffect(() => {
    if (squad?.isMember) {
      loadMessages();
      // 每5秒刷新一次消息
      const interval = setInterval(loadMessages, 5000);
      return () => clearInterval(interval);
    }
  }, [squad?.isMember]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const loadSquad = async () => {
    try {
      setLoading(true);
      const data = await squadApi.getSquadById(squadId);
      setSquad(data);
    } catch (err: any) {
      setError(err.message || '加载小队失败');
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async () => {
    if (!user) return;
    try {
      const data = await squadApi.getMessages(squadId);
      setMessages(data);
    } catch (err: any) {
      console.error('加载消息失败:', err);
    }
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || sending) return;

    try {
      setSending(true);
      const message = await squadApi.sendMessage(squadId, newMessage.trim());
      setMessages([...messages, message]);
      setNewMessage('');
    } catch (err: any) {
      alert(err.message || '发送消息失败');
    } finally {
      setSending(false);
    }
  };

  const handleLeave = async () => {
    if (!confirm('确定要离开这个小队吗？')) return;

    try {
      await squadApi.leaveSquad(squadId);
      router.push('/community/squads');
    } catch (err: any) {
      alert(err.message || '离开小队失败');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px]">
          <div className="max-w-7xl mx-auto px-6 py-8">
            <div className="text-center py-12">
              <div className="text-text-secondary">加载中...</div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (error || !squad) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px]">
          <div className="max-w-7xl mx-auto px-6 py-8">
            <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
              <div className="text-6xl mb-4">😕</div>
              <h2 className="text-2xl font-bold text-text-primary mb-2">
                {error || '小队不存在'}
              </h2>
              <button
                onClick={() => router.back()}
                className="mt-6 px-6 py-3 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors"
              >
                返回
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
        <div className="max-w-7xl mx-auto px-6 py-8">
          {/* Squad Header */}
          <div className="bg-bg-secondary rounded-xl p-8 border border-bg-tertiary mb-6">
            <div className="flex items-start gap-6">
              <div className="w-24 h-24 rounded-xl bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-4xl flex-shrink-0">
                {squad.avatarUrl ? (
                  <img src={squad.avatarUrl} alt={squad.name} className="w-full h-full object-cover rounded-xl" />
                ) : (
                  '🎪'
                )}
              </div>
              <div className="flex-1">
                <h1 className="text-3xl font-bold text-text-primary mb-2">
                  {squad.name}
                </h1>
                <p className="text-text-secondary mb-4">
                  队长: {squad.leader.displayName || squad.leader.username}
                </p>
                {squad.description && (
                  <p className="text-text-secondary mb-4">
                    {squad.description}
                  </p>
                )}
                <div className="flex items-center gap-6 text-sm text-text-secondary">
                  <span>👥 {squad.members.length}/{squad.maxMembers} 成员</span>
                  <span>💬 {squad._count?.messages || 0} 消息</span>
                  <span>{squad.isPublic ? '🌐 公开' : '🔒 私密'}</span>
                </div>
              </div>
              {user && squad.isMember && squad.leaderId !== user.id && (
                <button
                  onClick={handleLeave}
                  className="px-4 py-2 bg-bg-tertiary hover:bg-bg-primary border border-bg-primary text-text-secondary rounded-lg transition-colors text-sm"
                >
                  离开小队
                </button>
              )}
              {user && squad.isMember && (
                <button
                  onClick={() => setShowInviteModal(true)}
                  className="px-4 py-2 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors text-sm"
                >
                  邀请用户
                </button>
              )}
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Members List */}
            <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
              <h2 className="text-lg font-bold text-text-primary mb-4">
                成员列表
              </h2>
              <div className="space-y-3">
                {squad.members.map((member) => (
                  <div key={member.id} className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-sm flex-shrink-0">
                      {member.user.avatarUrl ? (
                        <img src={member.user.avatarUrl} alt={member.user.username} className="w-full h-full object-cover rounded-full" />
                      ) : (
                        member.user.username[0].toUpperCase()
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium text-text-primary truncate">
                        {member.user.displayName || member.user.username}
                      </div>
                      <div className="text-xs text-text-secondary">
                        {member.role === 'leader' ? '队长' : member.role === 'admin' ? '管理员' : '成员'}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Chat */}
            <div className="lg:col-span-2">
              {squad.isMember ? (
                <div className="bg-bg-secondary rounded-xl border border-bg-tertiary flex flex-col h-[600px]">
                  <div className="p-4 border-b border-bg-tertiary">
                    <h2 className="text-lg font-bold text-text-primary">
                      小队聊天
                    </h2>
                  </div>

                  {/* Messages */}
                  <div className="flex-1 overflow-y-auto p-4 space-y-4">
                    {messages.length === 0 ? (
                      <div className="text-center py-12 text-text-secondary">
                        还没有消息，开始聊天吧！
                      </div>
                    ) : (
                      messages.map((message) => (
                        <div key={message.id} className={message.type === 'system' ? 'text-center' : ''}>
                          {message.type === 'system' ? (
                            <div className="text-xs text-text-secondary">
                              {message.user.displayName || message.user.username} {message.content}
                            </div>
                          ) : (
                            <div className={`flex gap-3 ${message.userId === user?.id ? 'flex-row-reverse' : ''}`}>
                              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center text-xs flex-shrink-0">
                                {message.user.avatarUrl ? (
                                  <img src={message.user.avatarUrl} alt={message.user.username} className="w-full h-full object-cover rounded-full" />
                                ) : (
                                  message.user.username[0].toUpperCase()
                                )}
                              </div>
                              <div className={`flex-1 ${message.userId === user?.id ? 'text-right' : ''}`}>
                                <div className="text-xs text-text-secondary mb-1">
                                  {message.user.displayName || message.user.username}
                                </div>
                                <div className={`inline-block px-4 py-2 rounded-lg ${
                                  message.userId === user?.id
                                    ? 'bg-primary-purple text-white'
                                    : 'bg-bg-tertiary text-text-primary'
                                }`}>
                                  {message.content}
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      ))
                    )}
                    <div ref={messagesEndRef} />
                  </div>

                  {/* Input */}
                  <form onSubmit={handleSendMessage} className="p-4 border-t border-bg-tertiary">
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={newMessage}
                        onChange={(e) => setNewMessage(e.target.value)}
                        placeholder="输入消息..."
                        className="flex-1 px-4 py-2 bg-bg-primary border border-bg-tertiary rounded-lg text-text-primary placeholder-text-secondary focus:outline-none focus:border-primary-purple"
                        disabled={sending}
                      />
                      <button
                        type="submit"
                        className="px-6 py-2 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        disabled={sending || !newMessage.trim()}
                      >
                        发送
                      </button>
                    </div>
                  </form>
                </div>
              ) : (
                <div className="bg-bg-secondary rounded-xl p-12 border border-bg-tertiary text-center">
                  <div className="text-6xl mb-4">🔒</div>
                  <h2 className="text-2xl font-bold text-text-primary mb-2">
                    加入小队后可查看聊天
                  </h2>
                  <p className="text-text-secondary">
                    请联系队长邀请你加入
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {showInviteModal && (
        <InviteUserModal
          squadId={squadId}
          onClose={() => setShowInviteModal(false)}
          onSuccess={() => {
            loadSquad();
          }}
        />
      )}
    </div>
  );
}
