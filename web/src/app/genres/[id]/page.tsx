'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Image from 'next/image';
import Link from 'next/link';
import { genreAPI, GenreDetail } from '@/lib/api/genre';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

export default function GenreDetailPage() {
  const params = useParams();
  const router = useRouter();
  const [genre, setGenre] = useState<GenreDetail | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const load = async () => {
      try {
        setIsLoading(true);
        const data = await genreAPI.getGenre(params.id as string);
        setGenre(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load genre');
      } finally {
        setIsLoading(false);
      }
    };

    if (params.id) {
      load();
    }
  }, [params.id]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] min-h-[80vh] flex items-center justify-center">
          <div className="text-text-secondary">加载中...</div>
        </div>
      </div>
    );
  }

  if (error || !genre) {
    return (
      <div className="min-h-screen bg-bg-primary">
        <Navigation />
        <div className="pt-[44px] min-h-[80vh] flex items-center justify-center">
          <Card className="max-w-md">
            <div className="text-center">
              <div className="text-6xl mb-4">🎵</div>
              <p className="text-text-secondary mb-4">{error || '流派不存在'}</p>
              <Button onClick={() => router.push('/genres')}>返回流派列表</Button>
            </div>
          </Card>
        </div>
      </div>
    );
  }

  const pathParts = genre.path.split(' > ');
  const themeColor = genre.themeColor || '#6366f1';

  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="max-w-6xl mx-auto px-4 py-8 pt-[60px]">
        <Button
          variant="secondary"
          size="sm"
          onClick={() => router.push('/genres')}
          className="mb-6"
        >
          ← 返回
        </Button>

        <section className="relative rounded-2xl overflow-hidden border border-bg-tertiary mb-10">
          <div className="relative w-full aspect-[3/1] min-h-[200px]">
            {genre.backgroundImageURL ? (
              <Image
                src={genre.backgroundImageURL}
                alt={genre.name}
                fill
                className="object-cover"
                sizes="(max-width: 1200px) 100vw, 1200px"
                priority
              />
            ) : (
              <div
                className="w-full h-full"
                style={{
                  background: `linear-gradient(135deg, ${themeColor}40 0%, ${themeColor}10 50%, ${themeColor}30 100%)`,
                }}
              />
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-bg-primary via-bg-primary/60 to-transparent" />
          </div>

          <div className="absolute left-6 bottom-6 md:left-10 md:bottom-8">
            {pathParts.length > 1 && (
              <p className="text-xs text-text-tertiary mb-2">
                {pathParts.slice(0, -1).join(' › ')}
              </p>
            )}
            <h1
              className="text-4xl md:text-6xl leading-[0.95] text-text-primary font-black tracking-tight"
              style={{ fontFamily: "'Circular Std','SpotifyMixUI','Helvetica Neue',Arial,sans-serif" }}
            >
              {genre.name}
            </h1>
          </div>
        </section>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2 space-y-8">
            {genre.description && (
              <Card>
                <h2 className="text-2xl font-bold text-text-primary mb-4">简介</h2>
                <p className="text-text-secondary whitespace-pre-wrap leading-relaxed">
                  {genre.description}
                </p>
              </Card>
            )}

            {genre.example && (
              <Card>
                <h2 className="text-2xl font-bold text-text-primary mb-4">代表曲目</h2>
                <p className="text-text-primary text-lg mb-3">{genre.example}</p>
                {genre.spotifyTrackURL && (
                  <a
                    href={genre.spotifyTrackURL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-4 py-2 bg-accent-green/10 hover:bg-accent-green/20 rounded-lg transition-colors"
                  >
                    <span className="text-lg">🎵</span>
                    <span className="text-accent-green font-medium text-sm">在 Spotify 上收听</span>
                  </a>
                )}
              </Card>
            )}

            {genre.keyArtistBindings.length > 0 && (
              <Card>
                <h2 className="text-2xl font-bold text-text-primary mb-4">代表艺人</h2>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {genre.keyArtistBindings.map((artist) => {
                    const inner = (
                      <div className="flex items-center gap-3 p-3 rounded-lg bg-bg-tertiary hover:bg-bg-tertiary/80 transition-colors">
                        {artist.dj?.avatarMediumUrl || artist.dj?.avatarUrl ? (
                          <Image
                            src={artist.dj.avatarMediumUrl || artist.dj.avatarUrl!}
                            alt={artist.name}
                            width={40}
                            height={40}
                            className="rounded-full object-cover"
                          />
                        ) : (
                          <div
                            className="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-bold"
                            style={{ background: `linear-gradient(135deg, ${themeColor}, ${themeColor}80)` }}
                          >
                            {artist.name.charAt(0).toUpperCase()}
                          </div>
                        )}
                        <span className="text-text-primary font-medium text-sm">{artist.name}</span>
                      </div>
                    );

                    return artist.dj?.id ? (
                      <Link key={artist.name} href={`/djs/${artist.dj.id}`}>
                        {inner}
                      </Link>
                    ) : (
                      <div key={artist.name}>{inner}</div>
                    );
                  })}
                </div>
              </Card>
            )}

            {genre.soundCueTracks.length > 0 && (
              <Card>
                <h2 className="text-2xl font-bold text-text-primary mb-4">推荐曲目</h2>
                <div className="space-y-3">
                  {genre.soundCueTracks.map((track, i) => (
                    <div key={i} className="flex items-center justify-between p-3 rounded-lg bg-bg-tertiary">
                      <div>
                        <p className="text-text-primary font-medium text-sm">{track.title}</p>
                        <p className="text-text-tertiary text-xs">{track.artist}</p>
                      </div>
                      <div className="flex gap-2">
                        {track.spotifyUrl && (
                          <a href={track.spotifyUrl} target="_blank" rel="noopener noreferrer" className="text-accent-green hover:opacity-80 text-xs">Spotify</a>
                        )}
                        {track.appleMusicUrl && (
                          <a href={track.appleMusicUrl} target="_blank" rel="noopener noreferrer" className="text-primary-blue hover:opacity-80 text-xs">Apple</a>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </Card>
            )}
          </div>

          <div className="space-y-4">
            {(genre.origin || genre.era || genre.bpm) && (
              <Card>
                <h3 className="text-xl font-bold text-text-primary mb-4">流派信息</h3>
                <div className="space-y-3">
                  {genre.origin && (
                    <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                      <p className="text-text-tertiary text-xs mb-1">起源</p>
                      <p className="text-text-primary text-sm font-medium">{genre.origin}</p>
                    </div>
                  )}
                  {genre.era && (
                    <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                      <p className="text-text-tertiary text-xs mb-1">年代</p>
                      <p className="text-text-primary text-sm font-medium">{genre.era}</p>
                    </div>
                  )}
                  {genre.bpm && (
                    <div className="rounded-xl border border-bg-primary bg-bg-secondary/70 p-3">
                      <p className="text-text-tertiary text-xs mb-1">BPM</p>
                      <p className="text-text-primary text-sm font-medium">{genre.bpm}</p>
                    </div>
                  )}
                </div>
              </Card>
            )}

            {genre.wikipediaURL && (
              <Card>
                <h3 className="text-xl font-bold text-text-primary mb-4">外部链接</h3>
                <a
                  href={genre.wikipediaURL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-3 p-3 bg-bg-tertiary hover:bg-bg-tertiary/80 rounded-lg transition-colors"
                >
                  <span className="text-xl">📖</span>
                  <span className="text-text-secondary text-sm font-medium">Wikipedia</span>
                </a>
              </Card>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
