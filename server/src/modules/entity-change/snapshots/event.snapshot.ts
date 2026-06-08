import type { EntitySnapshot } from '../entity-change.types';
import type { EntityChangeDb } from '../entity-change.types';
import {
  dateToDateKey,
  dateToIso,
  decimalToString,
  normalizeJson,
  sortedStrings,
} from './snapshot-utils';
import { resolveEventTruth } from '../../../utils/event-status';

export const buildEventChangeSnapshot = async (input: {
  entityId: string;
  db: EntityChangeDb;
}): Promise<EntitySnapshot | null> => {
  const event = await input.db.event.findUnique({
    where: { id: input.entityId },
    include: {
      ticketTiers: { orderBy: { sortOrder: 'asc' } },
      weeks: { orderBy: { sortOrder: 'asc' } },
      eventDays: { orderBy: { sortOrder: 'asc' } },
      stages: { orderBy: { sortOrder: 'asc' } },
      canonicalArtists: {
        orderBy: { billingOrder: 'asc' },
        include: {
          members: { orderBy: { memberOrder: 'asc' } },
        },
      },
      performances: {
        orderBy: [
          { overallDayIndex: 'asc' },
          { startAt: 'asc' },
          { sortOrder: 'asc' },
        ],
        include: {
          stage: true,
          eventArtist: true,
          eventDay: true,
        },
      },
    },
  });

  if (!event) return null;

  const resolvedEventTruth = resolveEventTruth({
    isCancelled: event.isCancelled,
    visibility: event.visibility,
  });

  return {
    entityType: 'event',
    entityId: event.id,
    displayName: event.name,
    revision: event.revision,
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    data: {
      profile: {
        name: event.name,
        nameI18n: normalizeJson(event.nameI18n),
        abbreviation: event.abbreviation,
        description: event.description,
        descriptionI18n: normalizeJson(event.descriptionI18n),
        eventType: event.eventType,
        isCancelled: resolvedEventTruth.isCancelled,
        visibility: resolvedEventTruth.visibility,
        officialWebsite: event.officialWebsite,
        isVerified: event.isVerified,
      },
      media: {
        coverImageUrl: event.coverImageUrl,
        lineupImageUrl: event.lineupImageUrl,
        imageAssets: normalizeJson(event.imageAssets),
      },
      organizer: {
        organizerName: event.organizerName,
        wikiFestivalId: event.wikiFestivalId,
      },
      location: {
        city: event.city,
        cityI18n: normalizeJson(event.cityI18n),
        country: event.country,
        countryI18n: normalizeJson(event.countryI18n),
        manualLocation: normalizeJson(event.manualLocation),
        locationPoint: normalizeJson(event.locationPoint),
        latitude: decimalToString(event.latitude),
        longitude: decimalToString(event.longitude),
      },
      schedule: {
        startDate: dateToIso(event.startDate),
        endDate: dateToIso(event.endDate),
        scheduleMode: event.scheduleMode,
        timeZone: event.timeZone,
        startTime: event.startTime,
        endTime: event.endTime,
        dayRolloverHour: event.dayRolloverHour,
        weeks: event.weeks.map((week) => ({
          weekIndex: week.weekIndex,
          label: week.label,
          startDate: dateToDateKey(week.startDate),
          endDate: dateToDateKey(week.endDate),
          sortOrder: week.sortOrder,
        })),
        eventDays: event.eventDays.map((day) => ({
          eventDayId: day.eventDayId,
          weekIndex: day.weekIndex,
          dayIndexInWeek: day.dayIndexInWeek,
          overallDayIndex: day.overallDayIndex,
          label: day.label,
          weekday: day.weekday,
          date: dateToDateKey(day.date),
          sortOrder: day.sortOrder,
        })),
      },
      tickets: {
        ticketUrl: event.ticketUrl,
        ticketPriceMin: decimalToString(event.ticketPriceMin),
        ticketPriceMax: decimalToString(event.ticketPriceMax),
        ticketCurrency: event.ticketCurrency,
        ticketNotes: event.ticketNotes,
        tiers: event.ticketTiers.map((tier) => ({
          identityKey: `${tier.name.trim().toLowerCase()}|${tier.currency ?? ''}`,
          name: tier.name,
          price: decimalToString(tier.price),
          currency: tier.currency,
          sortOrder: tier.sortOrder,
        })),
      },
      lineup: {
        stages: event.stages.map((stage) => ({
          id: stage.id,
          name: stage.name,
          normalizedName: stage.normalizedName,
          sortOrder: stage.sortOrder,
        })),
        artists: event.canonicalArtists.map((artist) => ({
          artistIdentity: artist.primaryDjId ?? artist.normalizedName ?? artist.displayName,
          displayName: artist.displayName,
          normalizedName: artist.normalizedName,
          actType: artist.actType,
          primaryDjId: artist.primaryDjId,
          billingOrder: artist.billingOrder,
          posterTier: artist.posterTier,
          isTimetableOnly: artist.isTimetableOnly,
          members: artist.members.map((member) => ({
            djId: member.djId,
            memberNameSnapshot: member.memberNameSnapshot,
            memberOrder: member.memberOrder,
            role: member.role,
          })),
        })),
        performances: event.performances.map((performance) => ({
          identityKey: performance.identityKey,
          displayNameSnapshot: performance.displayNameSnapshot,
          artistIdentity: performance.eventArtist.primaryDjId ?? performance.eventArtist.normalizedName ?? performance.eventArtist.displayName,
          stageName: performance.stage?.name ?? null,
          stageNormalizedName: performance.stage?.normalizedName ?? null,
          eventDayId: performance.eventDayId,
          eventDayLabel: performance.eventDay?.label ?? null,
          weekIndex: performance.weekIndex,
          dayIndexInWeek: performance.dayIndexInWeek,
          overallDayIndex: performance.overallDayIndex,
          localDate: dateToDateKey(performance.localDate),
          startAt: dateToIso(performance.startAt),
          endAt: dateToIso(performance.endAt),
          sortOrder: performance.sortOrder,
          status: performance.status,
        })),
      },
      links: {
        referenceLinks: sortedStrings(event.referenceLinks),
        socialLinks: normalizeJson(event.socialLinks),
        sourceProvider: event.sourceProvider,
        sourceEventUrl: event.sourceEventUrl,
      },
    },
  };
};
