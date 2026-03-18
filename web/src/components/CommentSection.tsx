'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useAuth } from '@/contexts/AuthContext';
import { getApiUrl } from '@/lib/config';

interface Comment {
  id: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  user: {
    id: string;
    username: string;
    displayName: string | null;
    avatarUrl: string | null;
  };
  replies?: Comment[];
}

interface CommentSectionProps {
  setId: string;
  setTitle: string;
}

export default function CommentSection({ setId, setTitle }: CommentSectionProps) {
  const { user, token } = useAuth();
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(true);
  const [newComment, setNewComment] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [replyContent, setReplyContent] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');

  useEffect(() => {
    loadComments();
  }, [setId]);

  const loadComments = async () => {
    try {
      const response = await fetch(getApiUrl(`/dj-sets/${setId}/comments`));
      const data = await response.json();
      // 确保 data 是数组
      if (Array.isArray(data)) {
        setComments(data);
      } else {
        console.error('Comments data is not an array:', data);
        setComments([]);
      }
    } catch (error) {
      console.error('Failed to load comments:', error);
      setComments([]);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmitComment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !newComment.trim()) return;

    setSubmitting(true);
    try {
      const response = await fetch(getApiUrl(`/dj-sets/${setId}/comments`), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ content: newComment.trim() }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || '发表评论失败');
      }

      setNewComment('');
      await loadComments();
    } catch (error) {
      alert(error instanceof Error ? error.message : '发表评论失败');
    } finally {
      setSubmitting(false);
    }
  };

  const handleSubmitReply = async (parentId: string) => {
    if (!token || !replyContent.trim()) return;

    setSubmitting(true);
    try {
      const response = await fetch(getApiUrl(`/dj-sets/${setId}/comments`), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          content: replyContent.trim(),
          parentId,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || '回复失败');
      }

      setReplyContent('');
      setReplyingTo(null);
      await loadComments();
    } catch (error) {
      alert(error instanceof Error ? error.message : '回复失败');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEditComment = async (commentId: string) => {
    if (!token || !editContent.trim()) return;

    setSubmitting(true);
    try {
      const response = await fetch(getApiUrl(`/comments/${commentId}`), {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ content: editContent.trim() }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || '编辑失败');
      }

      setEditingId(null);
      setEditContent('');
      await loadComments();
    } catch (error) {
      alert(error instanceof Error ? error.message : '编辑失败');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteComment = async (commentId: string) => {
    if (!token) return;
    if (!confirm('确定要删除这条评论吗？')) return;

    try {
      const response = await fetch(getApiUrl(`/comments/${commentId}`), {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || '删除失败');
      }

      await loadComments();
    } catch (error) {
      alert(error instanceof Error ? error.message : '删除失败');
    }
  };

  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return '刚刚';
    if (diffMins < 60) return `${diffMins}分钟前`;
    if (diffHours < 24) return `${diffHours}小时前`;
    if (diffDays < 7) return `${diffDays}天前`;
    return date.toLocaleDateString('zh-CN');
  };

  const renderComment = (comment: Comment, isReply = false) => {
    const displayName = comment.user.displayName || comment.user.username;
    const isOwner = user?.id === comment.user.id;
    const isEditing = editingId === comment.id;

    return (
      <div key={comment.id} className={`${isReply ? 'ml-12' : ''}`}>
        <div className="flex gap-3 p-3 rounded-lg hover:bg-bg-tertiary/30 transition-colors">
          <div className="flex-shrink-0">
            {comment.user.avatarUrl ? (
              <div className="relative w-10 h-10 rounded-full overflow-hidden">
                <Image
                  src={comment.user.avatarUrl}
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

          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-sm font-medium text-text-primary">{displayName}</span>
              <span className="text-xs text-text-tertiary">•</span>
              <span className="text-xs text-text-tertiary">{formatTime(comment.createdAt)}</span>
              {comment.createdAt !== comment.updatedAt && (
                <span className="text-xs text-text-tertiary">(已编辑)</span>
              )}
            </div>

            {isEditing ? (
              <div className="space-y-2">
                <textarea
                  value={editContent}
                  onChange={(e) => setEditContent(e.target.value)}
                  className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none text-sm"
                  rows={3}
                  maxLength={1000}
                />
                <div className="flex gap-2">
                  <button
                    onClick={() => handleEditComment(comment.id)}
                    disabled={submitting || !editContent.trim()}
                    className="px-3 py-1 bg-primary-purple hover:bg-primary-blue text-white rounded text-xs disabled:opacity-50"
                  >
                    保存
                  </button>
                  <button
                    onClick={() => {
                      setEditingId(null);
                      setEditContent('');
                    }}
                    className="px-3 py-1 bg-bg-tertiary hover:bg-bg-primary text-text-primary rounded text-xs"
                  >
                    取消
                  </button>
                </div>
              </div>
            ) : (
              <>
                <p className="text-sm text-text-secondary whitespace-pre-wrap break-words">
                  {comment.content}
                </p>

                <div className="flex items-center gap-3 mt-2">
                  {user && (
                    <button
                      onClick={() => setReplyingTo(comment.id)}
                      className="text-xs text-text-tertiary hover:text-primary-blue transition-colors"
                    >
                      回复
                    </button>
                  )}
                  {isOwner && (
                    <>
                      <button
                        onClick={() => {
                          setEditingId(comment.id);
                          setEditContent(comment.content);
                        }}
                        className="text-xs text-text-tertiary hover:text-primary-purple transition-colors"
                      >
                        编辑
                      </button>
                      <button
                        onClick={() => handleDeleteComment(comment.id)}
                        className="text-xs text-text-tertiary hover:text-accent-red transition-colors"
                      >
                        删除
                      </button>
                    </>
                  )}
                </div>
              </>
            )}

            {replyingTo === comment.id && (
              <div className="mt-3 space-y-2">
                <textarea
                  value={replyContent}
                  onChange={(e) => setReplyContent(e.target.value)}
                  placeholder={`回复 ${displayName}...`}
                  className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-purple focus:outline-none text-sm"
                  rows={3}
                  maxLength={1000}
                />
                <div className="flex gap-2">
                  <button
                    onClick={() => handleSubmitReply(comment.id)}
                    disabled={submitting || !replyContent.trim()}
                    className="px-3 py-1 bg-primary-purple hover:bg-primary-blue text-white rounded text-xs disabled:opacity-50"
                  >
                    发表回复
                  </button>
                  <button
                    onClick={() => {
                      setReplyingTo(null);
                      setReplyContent('');
                    }}
                    className="px-3 py-1 bg-bg-tertiary hover:bg-bg-primary text-text-primary rounded text-xs"
                  >
                    取消
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>

        {comment.replies && comment.replies.length > 0 && (
          <div className="mt-2 space-y-2">
            {comment.replies.map((reply) => renderComment(reply, true))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="bg-bg-secondary rounded-xl p-6 border border-bg-tertiary">
      <h2 className="text-2xl font-bold text-text-primary mb-4">
        💬 评论 ({comments.length})
      </h2>

      {user ? (
        <form onSubmit={handleSubmitComment} className="mb-6">
          <textarea
            value={newComment}
            onChange={(e) => setNewComment(e.target.value)}
            placeholder="发表你的评论..."
            className="w-full bg-bg-tertiary text-text-primary rounded-lg px-4 py-3 border border-bg-primary focus:border-primary-purple focus:outline-none resize-none"
            rows={4}
            maxLength={1000}
          />
          <div className="flex justify-between items-center mt-2">
            <span className="text-xs text-text-tertiary">
              {newComment.length}/1000
            </span>
            <button
              type="submit"
              disabled={submitting || !newComment.trim()}
              className="px-4 py-2 bg-primary-purple hover:bg-primary-blue text-white rounded-lg transition-colors disabled:opacity-50"
            >
              {submitting ? '发表中...' : '发表评论'}
            </button>
          </div>
        </form>
      ) : (
        <div className="mb-6 p-4 bg-bg-tertiary rounded-lg border border-bg-primary text-center">
          <p className="text-text-secondary">
            <a href="/login" className="text-primary-blue hover:underline">
              登录
            </a>
            后可以发表评论
          </p>
        </div>
      )}

      {loading ? (
        <div className="text-center py-8 text-text-secondary">加载中...</div>
      ) : comments.length === 0 ? (
        <div className="text-center py-8">
          <div className="text-4xl mb-2">💭</div>
          <p className="text-text-secondary">还没有评论，来发表第一条吧！</p>
        </div>
      ) : (
        <div className="space-y-2">
          {comments.map((comment) => renderComment(comment))}
        </div>
      )}
    </div>
  );
}
