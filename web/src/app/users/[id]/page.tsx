'use client';

import { useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Image from 'next/image';
import Navigation from '@/components/Navigation';
import { getApiUrl } from '@/lib/config';
import { djAPI, DJ } from '@/lib/api/dj';
import { GENRE_TREE, flattenGenres } from '@/lib/genres';

interface PublicUserProfile {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  location: string | null;
  favoriteDjIds: string[];
  favoriteGenres: string[];
  createdAt: string;
}

export default function PublicUserPage() {
  const params = useParams();
  const router = useRouter();
  const [profile, setProfile] = useState<PublicUserProfile | null>(null);
  const [djs, setDjs] = useState<DJ[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const allGenres = useMemo(() => flattenGenres(GENRE_TREE), []);

  useEffect(() => {
    const load = async () => {
      if (!params.id) return;
      setLoading(true);
      setError('');
      try {
        const [profileRes, djsRes] = await Promise.all([
          fetch(getApiUrl(`/auth/users/${params.id}`)),
          djAPI.getDJs({ page: 1, limit: 500, sortBy: 'followerCount', live: false }),
        ]);

        const profileData = await profileRes.json().catch(() => ({}));
        if (!profileRes.ok) {
          throw new Error(profileData.error || '加载用户主页失败');
        }

        setProfile(profileData as PublicUserProfile);
        setDjs(djsRes.djs || []);
      } catch (err) {
        setError(err instanceof Error ? err.message : '加载失败');
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [params.id]);

  const favoriteDjNames = useMemo(() => {
    if (!profile) return [] as string[];
    const map = new Map(djs.map((dj) => [dj.id, dj.name]));
    return profile.favoriteDjIds.map((id) => map.get(id)).filter((name): name is string => Boolean(name));
  }, [profile, djs]);

  const favoriteGenreNames = useMemo(() => {
    if (!profile) return [] as string[];
    return allGenres
      .filter((genre) => profile.favoriteGenres.includes(genre.id))
      .map((genre) => genre.name);
  }, [profile, allGenres]);

  if (loading) {
    return (
      <div className="min-h-screen bg-bg-primary flex items-center justify-center text-text-secondary">加载中...</div>
    );
  }

  if (error || !profile) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] max-w-4xl mx-auto p-6">
          <div className="rounded-lg border border-accent-red/40 bg-accent-red/10 text-accent-red p-3 mb-4">{error || '用户不存在'}</div>
          <button
            type="button"
            onClick={() => router.back()}
            className="px-4 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary"
          >
            返回
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-5xl mx-auto p-6 space-y-6">
        <div className="rounded-2xl border border-bg-tertiary bg-bg-secondary p-5 flex items-center gap-4">
          <div className="h-20 w-20 rounded-full overflow-hidden border border-bg-primary bg-bg-tertiary flex items-center justify-center">
            {profile.avatarUrl ? (
              <Image src={profile.avatarUrl} alt={profile.displayName || profile.username} width={80} height={80} className="h-full w-full object-cover" />
            ) : (
              <span className="text-2xl text-text-primary font-semibold">{(profile.displayName || profile.username || 'U').slice(0, 1).toUpperCase()}</span>
            )}
          </div>
          <div>
            <h1 className="text-2xl font-bold text-text-primary">{profile.displayName || profile.username}</h1>
            <p className="text-sm text-text-tertiary">@{profile.username}</p>
            {profile.location && <p className="text-sm text-text-secondary mt-1">{profile.location}</p>}
          </div>
        </div>

        {profile.bio && (
          <div className="rounded-2xl border border-bg-tertiary bg-bg-secondary p-5">
            <h2 className="text-lg font-semibold text-text-primary mb-2">个人简介</h2>
            <p className="text-text-secondary whitespace-pre-wrap">{profile.bio}</p>
          </div>
        )}

        <div className="rounded-2xl border border-bg-tertiary bg-bg-secondary p-5">
          <h2 className="text-lg font-semibold text-text-primary mb-3">喜欢的 DJ</h2>
          <div className="flex flex-wrap gap-2">
            {favoriteDjNames.length > 0 ? (
              favoriteDjNames.map((name) => (
                <span key={name} className="px-3 py-1 rounded-full text-sm bg-primary-blue/20 text-primary-blue border border-primary-blue/40">
                  {name}
                </span>
              ))
            ) : (
              <span className="text-sm text-text-tertiary">未填写</span>
            )}
          </div>
        </div>

        <div className="rounded-2xl border border-bg-tertiary bg-bg-secondary p-5">
          <h2 className="text-lg font-semibold text-text-primary mb-3">喜欢的风格流派</h2>
          <div className="flex flex-wrap gap-2">
            {favoriteGenreNames.length > 0 ? (
              favoriteGenreNames.map((name) => (
                <span key={name} className="px-3 py-1 rounded-full text-sm bg-primary-purple/20 text-primary-purple border border-primary-purple/40">
                  {name}
                </span>
              ))
            ) : (
              <span className="text-sm text-text-tertiary">未填写</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
