import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { DJ } from '@/lib/api/dj';

interface DJCardProps {
  dj: DJ;
}

const getHighResAvatar = (url: string) =>
  url
    .replace('ab6761610000f178', 'ab6761610000e5eb')
    .replace('ab67616100005174', 'ab6761610000e5eb')
    .replace('ab67616d00004851', 'ab67616d0000b273')
    .replace('ab67616d00001e02', 'ab67616d0000b273');

export const DJCard: React.FC<DJCardProps> = ({ dj }) => {
  return (
    <Link href={`/djs/${dj.id}`}>
      <div className="bg-bg-secondary rounded-xl overflow-hidden border border-border-secondary hover:border-primary-purple transition-all duration-300 hover:shadow-glow cursor-pointer">
        {dj.avatarUrl ? (
          <div className="aspect-square bg-bg-tertiary relative">
            <Image
              src={getHighResAvatar(dj.avatarUrl)}
              alt={dj.name}
              fill
              className="object-cover"
              sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
            />
          </div>
        ) : (
          <div className="aspect-square bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">
            <span className="text-6xl">🎧</span>
          </div>
        )}

        <div className="p-6">
          <div className="flex items-start justify-between mb-2">
            <h3 className="text-xl font-bold text-text-primary line-clamp-1">
              {dj.name}
            </h3>
            {dj.isVerified && (
              <span className="ml-2 text-accent-green">✓</span>
            )}
          </div>

          {dj.bio && (
            <p className="text-text-tertiary text-sm mb-4 line-clamp-2">
              {dj.bio}
            </p>
          )}

          <div className="space-y-2 text-sm">
            {dj.country && (
              <div className="flex items-center text-text-secondary">
                <span className="mr-2">🌍</span>
                <span>{dj.country}</span>
              </div>
            )}

            <div className="flex items-center text-text-secondary">
              <span className="mr-2">👥</span>
              <span>{dj.followerCount.toLocaleString()} 粉丝</span>
            </div>
          </div>

          <div className="mt-4 flex gap-2 flex-wrap">
            {dj.spotifyId && (
              <span className="px-2 py-1 bg-accent-green/20 text-accent-green rounded text-xs">
                Spotify
              </span>
            )}
            {dj.soundcloudUrl && (
              <span className="px-2 py-1 bg-primary-blue/20 text-primary-blue rounded text-xs">
                SoundCloud
              </span>
            )}
            {dj.instagramUrl && (
              <span className="px-2 py-1 bg-accent-pink/20 text-accent-pink rounded text-xs">
                Instagram
              </span>
            )}
          </div>
        </div>
      </div>
    </Link>
  );
};
