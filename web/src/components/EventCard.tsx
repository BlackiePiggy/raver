import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { Event } from '@/lib/api/event';

interface EventCardProps {
  event: Event;
}

export const EventCard: React.FC<EventCardProps> = ({ event }) => {
  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  return (
    <Link href={`/events/${event.id}`}>
      <div className="bg-bg-secondary rounded-xl overflow-hidden border border-border-secondary hover:border-primary-purple transition-all duration-300 hover:shadow-glow cursor-pointer">
        {event.coverImageUrl ? (
          <div className="h-48 bg-bg-tertiary relative">
            <Image
              src={event.coverImageUrl}
              alt={event.name}
              fill
              className="object-cover"
              sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
            />
          </div>
        ) : (
          <div className="h-48 bg-gradient-to-br from-primary-purple to-primary-blue flex items-center justify-center">
            <span className="text-6xl">🎪</span>
          </div>
        )}

        <div className="p-6">
          <div className="flex items-start justify-between mb-2">
            <h3 className="text-xl font-bold text-text-primary line-clamp-2">
              {event.name}
            </h3>
            {event.isVerified && (
              <span className="ml-2 text-accent-green">✓</span>
            )}
          </div>

          {event.description && (
            <p className="text-text-tertiary text-sm mb-4 line-clamp-2">
              {event.description}
            </p>
          )}

          <div className="space-y-2 text-sm">
            <div className="flex items-center text-text-secondary">
              <span className="mr-2">📅</span>
              <span>{formatDate(event.startDate)}</span>
            </div>

            {event.city && (
              <div className="flex items-center text-text-secondary">
                <span className="mr-2">📍</span>
                <span>{event.city}{event.country && `, ${event.country}`}</span>
              </div>
            )}

            {event.venueName && (
              <div className="flex items-center text-text-secondary">
                <span className="mr-2">🏛️</span>
                <span className="line-clamp-1">{event.venueName}</span>
              </div>
            )}
          </div>

          <div className="mt-4 flex gap-2">
            <span className={`px-3 py-1 rounded-full text-xs ${
              event.status === 'upcoming'
                ? 'bg-accent-green/20 text-accent-green'
                : event.status === 'ongoing'
                ? 'bg-primary-blue/20 text-primary-blue'
                : 'bg-text-tertiary/20 text-text-tertiary'
            }`}>
              {event.status === 'upcoming' ? '即将开始' : event.status === 'ongoing' ? '进行中' : '已结束'}
            </span>
          </div>
        </div>
      </div>
    </Link>
  );
};
