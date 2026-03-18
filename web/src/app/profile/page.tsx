'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';
import Navigation from '@/components/Navigation';
import { useAuth } from '@/contexts/AuthContext';
import { authAPI } from '@/lib/api/auth';
import { djAPI, DJ } from '@/lib/api/dj';
import { GENRE_TREE, flattenGenres } from '@/lib/genres';

export default function ProfilePage() {
  const router = useRouter();
  const { user, token, isLoading, setAuthUser } = useAuth();
  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [location, setLocation] = useState('');
  const [favoriteDjIds, setFavoriteDjIds] = useState<string[]>([]);
  const [favoriteGenres, setFavoriteGenres] = useState<string[]>([]);
  const [djs, setDjs] = useState<DJ[]>([]);
  const [saving, setSaving] = useState(false);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [message, setMessage] = useState('');

  const allGenres = useMemo(() => flattenGenres(GENRE_TREE), []);

  useEffect(() => {
    if (!isLoading && !user) {
      router.push('/login');
      return;
    }
  }, [isLoading, user, router]);

  useEffect(() => {
    const loadProfile = async () => {
      if (!token) {
        return;
      }
      try {
        const profile = await authAPI.getProfile(token);
        setDisplayName(profile.displayName || '');
        setBio(profile.bio || '');
        setLocation(profile.location || '');
        setFavoriteDjIds(profile.favoriteDjIds || []);
        setFavoriteGenres(profile.favoriteGenres || []);
      } catch (error) {
        console.error('Load profile failed:', error);
      }
    };

    if (user && token) {
      loadProfile();
    }
  }, [user, token]);

  useEffect(() => {
    const loadDjs = async () => {
      try {
        const response = await djAPI.getDJs({ page: 1, limit: 100, sortBy: 'followerCount' });
        setDjs(response.djs || []);
      } catch (error) {
        console.error('Load DJs failed:', error);
      }
    };

    if (user) {
      loadDjs();
    }
  }, [user]);

  const toggleArrayValue = (
    value: string,
    values: string[],
    setter: (next: string[]) => void
  ) => {
    if (values.includes(value)) {
      setter(values.filter((item) => item !== value));
      return;
    }
    setter([...values, value]);
  };

  const handleSave = async () => {
    if (!token) {
      router.push('/login');
      return;
    }

    setSaving(true);
    setMessage('');
    try {
      const updated = await authAPI.updateProfile(token, {
        displayName,
        bio,
        location,
        favoriteDjIds,
        favoriteGenres,
      });
      setAuthUser(updated);
      setMessage('个人信息已保存');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '保存失败');
    } finally {
      setSaving(false);
    }
  };

  const handleAvatarUpload = async (file: File) => {
    if (!token) {
      router.push('/login');
      return;
    }
    setAvatarUploading(true);
    setMessage('');
    try {
      const updated = await authAPI.uploadAvatar(token, file);
      setAuthUser(updated);
      setMessage('头像上传成功');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '头像上传失败');
    } finally {
      setAvatarUploading(false);
    }
  };

  if (!user) {
    return null;
  }

  const favoriteDjNames = djs.filter((dj) => favoriteDjIds.includes(dj.id)).map((dj) => dj.name);
  const favoriteGenreNames = allGenres
    .filter((genre) => favoriteGenres.includes(genre.id))
    .map((genre) => genre.name);

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px] max-w-6xl mx-auto p-6 space-y-6">
        <div>
          <h1 className="text-4xl font-bold text-text-primary mb-2">我的音乐身份</h1>
          <p className="text-text-secondary">设置你是哪些 DJ 和流派的粉丝，生成你的身份标识牌。</p>
        </div>

        <div className="bg-bg-secondary rounded-xl border border-bg-tertiary p-5 space-y-4">
          <h2 className="text-xl font-semibold text-text-primary">基础信息</h2>
          <div>
            <label className="block text-text-secondary text-sm mb-2">头像</label>
            <div className="flex items-center gap-4">
              <div className="h-16 w-16 rounded-full overflow-hidden border border-bg-primary bg-bg-tertiary flex items-center justify-center">
                {user.avatarUrl ? (
                  <Image src={user.avatarUrl} alt={displayName || user.username} width={64} height={64} className="h-full w-full object-cover" />
                ) : (
                  <span className="text-lg text-text-primary font-semibold">{(displayName || user.username || 'U').slice(0, 1).toUpperCase()}</span>
                )}
              </div>
              <label className="inline-flex px-3 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary cursor-pointer text-sm">
                {avatarUploading ? '上传中...' : '上传头像'}
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      handleAvatarUpload(file);
                    }
                  }}
                />
              </label>
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-text-secondary text-sm mb-1">昵称</label>
              <input
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none"
              />
            </div>
            <div>
              <label className="block text-text-secondary text-sm mb-1">城市</label>
              <input
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none"
              />
            </div>
          </div>
          <div>
            <label className="block text-text-secondary text-sm mb-1">个人简介</label>
            <textarea
              rows={3}
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              className="w-full bg-bg-tertiary text-text-primary rounded-lg px-3 py-2 border border-bg-primary focus:border-primary-blue focus:outline-none"
            />
          </div>
        </div>

        <div className="bg-bg-secondary rounded-xl border border-bg-tertiary p-5 space-y-4">
          <h2 className="text-xl font-semibold text-text-primary">DJ 粉丝标识</h2>
          <div className="flex flex-wrap gap-2">
            {djs.map((dj) => {
              const active = favoriteDjIds.includes(dj.id);
              return (
                <button
                  key={dj.id}
                  type="button"
                  onClick={() => toggleArrayValue(dj.id, favoriteDjIds, setFavoriteDjIds)}
                  className={`px-3 py-1 rounded-full text-sm border transition-colors ${
                    active
                      ? 'bg-primary-blue/20 border-primary-blue text-primary-blue'
                      : 'bg-bg-tertiary border-bg-primary text-text-secondary hover:text-text-primary'
                  }`}
                >
                  {dj.name} 粉
                </button>
              );
            })}
          </div>
        </div>

        <div className="bg-bg-secondary rounded-xl border border-bg-tertiary p-5 space-y-4">
          <h2 className="text-xl font-semibold text-text-primary">流派粉丝标识</h2>
          <div className="flex flex-wrap gap-2">
            {allGenres.map((genre) => {
              const active = favoriteGenres.includes(genre.id);
              return (
                <button
                  key={genre.id}
                  type="button"
                  onClick={() => toggleArrayValue(genre.id, favoriteGenres, setFavoriteGenres)}
                  className={`px-3 py-1 rounded-full text-sm border transition-colors ${
                    active
                      ? 'bg-primary-purple/20 border-primary-purple text-primary-purple'
                      : 'bg-bg-tertiary border-bg-primary text-text-secondary hover:text-text-primary'
                  }`}
                >
                  {genre.name} 派
                </button>
              );
            })}
          </div>
        </div>

        <div className="bg-bg-secondary rounded-xl border border-bg-tertiary p-5">
          <h2 className="text-xl font-semibold text-text-primary mb-3">我的身份标识牌</h2>
          <div className="flex flex-wrap gap-2 mb-4">
            {favoriteDjNames.map((name) => (
              <span key={name} className="px-3 py-1 rounded-full text-sm bg-primary-blue/20 text-primary-blue border border-primary-blue/40">
                {name} Fan
              </span>
            ))}
            {favoriteGenreNames.map((name) => (
              <span key={name} className="px-3 py-1 rounded-full text-sm bg-primary-purple/20 text-primary-purple border border-primary-purple/40">
                {name} Lover
              </span>
            ))}
            {favoriteDjNames.length === 0 && favoriteGenreNames.length === 0 && (
              <span className="text-text-tertiary text-sm">还没有选择标识，去上面选一些吧。</span>
            )}
          </div>

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleSave}
              disabled={saving}
              className="px-4 py-2 rounded-lg bg-primary-blue hover:bg-primary-purple text-white disabled:opacity-60"
            >
              {saving ? '保存中...' : '保存资料'}
            </button>
            <Link href="/my-publishes" className="px-4 py-2 rounded-lg border border-bg-primary text-text-secondary hover:text-text-primary text-sm">
              管理我的发布
            </Link>
            {message && <span className="text-sm text-text-secondary">{message}</span>}
          </div>
        </div>
      </div>
    </div>
  );
}
