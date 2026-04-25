const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';

export interface NotificationCount {
  total: number;
  squadInvites: number;
  friendRequests: number;
  messages: number;
  likes: number;
  comments: number;
}

export const notificationApi = {
  // 获取未读通知数量
  async getUnreadCount(): Promise<NotificationCount> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/notifications/unread-count`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '获取未读通知数量失败');
    }

    return response.json();
  },

  // 获取所有通知
  async getNotifications(limit = 20): Promise<any> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/notifications?limit=${limit}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '获取通知失败');
    }

    return response.json();
  },
};
