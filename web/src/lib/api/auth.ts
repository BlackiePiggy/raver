import { authSessionToken } from '@/lib/auth/session-token';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';
const V1_API_URL =
  typeof window !== 'undefined'
    ? '/v1'
    : (process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api').replace(/\/api\/?$/, '/v1');

export interface User {
  id: string;
  username: string;
  email?: string;
  displayName: string | null;
  avatarUrl: string | null;
  avatarURL?: string | null;
  bio?: string | null;
  location?: string | null;
  favoriteDjIds?: string[];
  favoriteGenres?: string[];
  role: string;
}

export interface AuthResponse {
  user: User;
  token: string;
  accessToken?: string;
  accessTokenExpiresIn?: number;
  refreshToken?: string;
  refreshTokenId?: string;
}

export interface RegisterData {
  username: string;
  email: string;
  password: string;
  displayName?: string;
  birthYear?: number;
  regionCode?: string;
}

export interface LoginData {
  identifier: string;
  password: string;
}

class AuthAPI {
  private getHeaders(token?: string) {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
    return headers;
  }

  private authMetadataHeaders(): HeadersInit {
    return {
      'x-raver-client-type': 'web_admin',
      'x-raver-platform': 'web',
      'x-raver-device-name': typeof navigator !== 'undefined' ? navigator.userAgent.slice(0, 120) : 'Web Admin',
    };
  }

  private async parseError(response: Response, fallback: string): Promise<Error> {
    const error = await response.json().catch(() => ({}));
    return new Error(error.error || error.message || fallback);
  }

  async register(data: RegisterData): Promise<AuthResponse> {
    const response = await fetch(`${V1_API_URL}/auth/register`, {
      method: 'POST',
      headers: {
        ...this.getHeaders(),
        ...this.authMetadataHeaders(),
      },
      credentials: 'include',
      body: JSON.stringify({
        ...data,
        birthYear: data.birthYear ?? 1998,
        regionCode: data.regionCode ?? 'JP',
        clientType: 'web_admin',
      }),
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Registration failed');
    }

    return response.json();
  }

  async login(data: LoginData): Promise<AuthResponse> {
    const response = await fetch(`${V1_API_URL}/auth/login`, {
      method: 'POST',
      headers: {
        ...this.getHeaders(),
        ...this.authMetadataHeaders(),
      },
      credentials: 'include',
      body: JSON.stringify({
        ...data,
        clientType: 'web_admin',
      }),
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Login failed');
    }

    return response.json();
  }

  async refresh(): Promise<AuthResponse> {
    const response = await fetch(`${V1_API_URL}/auth/refresh`, {
      method: 'POST',
      headers: {
        ...this.getHeaders(),
        ...this.authMetadataHeaders(),
      },
      credentials: 'include',
      body: JSON.stringify({ clientType: 'web_admin' }),
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Session expired');
    }

    return response.json();
  }

  async logout(): Promise<void> {
    await fetch(`${V1_API_URL}/auth/logout`, {
      method: 'POST',
      headers: this.getHeaders(),
      credentials: 'include',
    }).catch(() => undefined);
  }

  async reauth(password: string, scope: string): Promise<{ success: true; reauthProof: string; expiresInSeconds: number; scope: string }> {
    const response = await fetch(`${V1_API_URL}/auth/reauth`, {
      method: 'POST',
      headers: this.getHeaders(authSessionToken.get() || undefined),
      credentials: 'include',
      body: JSON.stringify({ password, scope }),
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Reauthentication failed');
    }

    return response.json();
  }

  async getProfile(token: string): Promise<User> {
    const response = await fetch(`${V1_API_URL}/profile/me`, {
      headers: this.getHeaders(token),
      credentials: 'include',
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Failed to fetch profile');
    }

    const profile = await response.json();
    return {
      id: profile.id,
      username: profile.username,
      email: profile.email,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl ?? profile.avatarURL ?? null,
      avatarURL: profile.avatarURL ?? profile.avatarUrl ?? null,
      bio: profile.bio,
      favoriteGenres: profile.tags ?? profile.favoriteGenres,
      role: profile.role ?? 'user',
    };
  }

  async updateProfile(
    token: string,
    data: {
      displayName?: string;
      bio?: string;
      location?: string;
      favoriteDjIds?: string[];
      favoriteGenres?: string[];
    }
  ): Promise<User> {
    const response = await fetch(`${API_URL}/auth/profile`, {
      method: 'PUT',
      headers: this.getHeaders(token),
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Failed to update profile');
    }

    return response.json();
  }

  async uploadAvatar(token: string, file: File): Promise<User> {
    const formData = new FormData();
    formData.append('avatar', file);

    const response = await fetch(`${API_URL}/auth/avatar`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: formData,
    });

    if (!response.ok) {
      throw await this.parseError(response, 'Failed to upload avatar');
    }

    return response.json();
  }

  async searchUsers(query: string): Promise<Array<{
    id: string;
    username: string;
    displayName?: string;
    avatarUrl?: string;
  }>> {
    const response = await fetch(`${API_URL}/auth/users/search?q=${encodeURIComponent(query)}`);

    if (!response.ok) {
      throw await this.parseError(response, 'Failed to search users');
    }

    return response.json();
  }
}

export const authAPI = new AuthAPI();
