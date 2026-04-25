const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';

export interface Squad {
  id: string;
  name: string;
  description?: string;
  avatarUrl?: string;
  bannerUrl?: string;
  leaderId: string;
  isPublic: boolean;
  maxMembers: number;
  createdAt: string;
  updatedAt: string;
  leader: {
    id: string;
    username: string;
    displayName?: string;
    avatarUrl?: string;
  };
  members: SquadMember[];
  isMember?: boolean;
  _count?: {
    members: number;
    messages: number;
    activities?: number;
    albums?: number;
  };
}

export interface SquadMember {
  id: string;
  squadId: string;
  userId: string;
  role: string;
  joinedAt: string;
  user: {
    id: string;
    username: string;
    displayName?: string;
    avatarUrl?: string;
  };
}

export interface SquadInvite {
  id: string;
  squadId: string;
  inviterId: string;
  inviteeId: string;
  status: string;
  createdAt: string;
  expiresAt: string;
  squad: {
    id: string;
    name: string;
    description?: string;
    avatarUrl?: string;
  };
  inviter: {
    id: string;
    username: string;
    displayName?: string;
    avatarUrl?: string;
  };
}

export interface SquadMessage {
  id: string;
  squadId: string;
  userId: string;
  content: string;
  type: string;
  imageUrl?: string;
  createdAt: string;
  user: {
    id: string;
    username: string;
    displayName?: string;
    avatarUrl?: string;
  };
}

export const squadApi = {
  // 获取小队列表
  async getSquads(params?: {
    my?: boolean;
    search?: string;
    isPublic?: boolean;
  }): Promise<Squad[]> {
    const queryParams = new URLSearchParams();
    if (params?.my) queryParams.append('my', 'true');
    if (params?.search) queryParams.append('search', params.search);
    if (params?.isPublic !== undefined) queryParams.append('isPublic', String(params.isPublic));

    const url = `${API_URL}/squads${queryParams.toString() ? `?${queryParams}` : ''}`;
    const response = await fetch(url);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '获取小队列表失败');
    }

    return response.json();
  },

  // 获取小队详情
  async getSquadById(id: string): Promise<Squad> {
    const token = localStorage.getItem('token');
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${API_URL}/squads/${id}`, { headers });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '获取小队详情失败');
    }

    return response.json();
  },

  // 创建小队
  async createSquad(data: {
    name: string;
    description?: string;
    isPublic?: boolean;
    maxMembers?: number;
    memberIds?: string[];
  }): Promise<Squad> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/squads`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '创建小队失败');
    }

    return response.json();
  },

  // 邀请用户
  async inviteUser(squadId: string, inviteeId: string): Promise<SquadInvite> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/squads/${squadId}/invite`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ inviteeId }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '邀请用户失败');
    }

    return response.json();
  },

  // 获取我的邀请
  async getMyInvites(): Promise<SquadInvite[]> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/squads/invites/me`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '获取邀请列表失败');
    }

    return response.json();
  },

  // 处理邀请
  async handleInvite(inviteId: string, accept: boolean): Promise<{ success: boolean; accepted: boolean }> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/squads/invites/${inviteId}/handle`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ accept }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '处理邀请失败');
    }

    return response.json();
  },

  // 发送消息
  async sendMessage(squadId: string, content: string): Promise<SquadMessage> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/squads/${squadId}/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ content }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '发送消息失败');
    }

    return response.json();
  },

  // 获取消息
  async getMessages(squadId: string, limit = 50, before?: string): Promise<SquadMessage[]> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const queryParams = new URLSearchParams();
    queryParams.append('limit', String(limit));
    if (before) queryParams.append('before', before);

    const response = await fetch(`${API_URL}/squads/${squadId}/messages?${queryParams}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '获取消息失败');
    }

    return response.json();
  },

  // 离开小队
  async leaveSquad(squadId: string): Promise<{ success: boolean }> {
    const token = localStorage.getItem('token');
    if (!token) {
      throw new Error('请先登录');
    }

    const response = await fetch(`${API_URL}/squads/${squadId}/leave`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || '离开小队失败');
    }

    return response.json();
  },
};
