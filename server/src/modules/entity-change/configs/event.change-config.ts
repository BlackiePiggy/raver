import { registerEntityChangeDefinition } from '../entity-change.registry';
import type { ChangePathConfig } from '../entity-change.types';
import { buildEventChangeSnapshot } from '../snapshots/event.snapshot';

const publicScalar = (labelZh: string, labelEn: string, category: string, priority = 50): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'public',
  publicSafe: true,
  priority,
});

const privateScalar = (labelZh: string, labelEn: string, category: string): ChangePathConfig => ({
  labelZh,
  labelEn,
  category,
  audience: 'private',
  publicSafe: false,
  sensitive: true,
});

export const eventChangePaths: Record<string, ChangePathConfig> = {
  'profile.name': publicScalar('活动名称', 'Event name', 'profile', 100),
  'profile.description': publicScalar('活动介绍', 'Event description', 'profile'),
  'profile.eventType': publicScalar('活动类型', 'Event type', 'profile'),
  'profile.status': publicScalar('活动状态', 'Event status', 'profile'),
  'profile.officialWebsite': publicScalar('活动官网', 'Official website', 'links'),
  'media.coverImageUrl': publicScalar('活动封面', 'Cover image', 'media'),
  'media.lineupImageUrl': publicScalar('阵容图', 'Lineup image', 'media'),
  'organizer.organizerName': publicScalar('主办方名称', 'Organizer name', 'organizer'),
  'organizer.wikiFestivalId': publicScalar('关联主办方', 'Related brand', 'organizer'),
  'location.venueName': publicScalar('场地名称', 'Venue name', 'location', 95),
  'location.venueAddress': publicScalar('场地地址', 'Venue address', 'location', 90),
  'location.city': publicScalar('城市', 'City', 'location'),
  'location.country': publicScalar('国家/地区', 'Country or region', 'location'),
  'location.manualLocation': publicScalar('地点详情', 'Location details', 'location'),
  'location.locationPoint': publicScalar('地图坐标', 'Map coordinate', 'location'),
  'location.latitude': publicScalar('纬度', 'Latitude', 'location'),
  'location.longitude': publicScalar('经度', 'Longitude', 'location'),
  'schedule.startDate': publicScalar('开始日期', 'Start date', 'schedule', 98),
  'schedule.endDate': publicScalar('结束日期', 'End date', 'schedule', 98),
  'schedule.scheduleMode': publicScalar('日程模式', 'Schedule mode', 'schedule'),
  'schedule.timeZone': publicScalar('时区', 'Time zone', 'schedule'),
  'schedule.startTime': publicScalar('开始时间', 'Start time', 'schedule'),
  'schedule.endTime': publicScalar('结束时间', 'End time', 'schedule'),
  'schedule.dayRolloverHour': publicScalar('跨日切分时间', 'Day rollover hour', 'schedule'),
  'schedule.weeks': {
    ...publicScalar('周期结构', 'Week structure', 'schedule'),
    arrayStrategy: { type: 'keyed-list', keyPath: 'weekIndex', orderMatters: true },
  },
  'schedule.eventDays': {
    ...publicScalar('活动日期', 'Event days', 'schedule'),
    arrayStrategy: { type: 'keyed-list', keyPath: 'eventDayId', orderMatters: true },
  },
  'tickets.ticketUrl': publicScalar('购票链接', 'Ticket URL', 'tickets'),
  'tickets.ticketPriceMin': publicScalar('最低票价', 'Minimum ticket price', 'tickets'),
  'tickets.ticketPriceMax': publicScalar('最高票价', 'Maximum ticket price', 'tickets'),
  'tickets.ticketCurrency': publicScalar('票价币种', 'Ticket currency', 'tickets'),
  'tickets.ticketNotes': publicScalar('票务说明', 'Ticket notes', 'tickets'),
  'tickets.tiers': {
    ...publicScalar('票档', 'Ticket tier', 'tickets'),
    arrayStrategy: { type: 'keyed-list', keyPath: 'identityKey', orderMatters: true },
  },
  'lineup.stages': {
    ...publicScalar('舞台', 'Stage', 'lineup'),
    arrayStrategy: { type: 'keyed-list', keyPath: 'normalizedName', orderMatters: true },
  },
  'lineup.artists': {
    ...publicScalar('阵容艺人', 'Lineup artist', 'lineup', 88),
    arrayStrategy: { type: 'keyed-list', keyPath: 'artistIdentity', orderMatters: true },
  },
  'lineup.performances': {
    ...publicScalar('演出时间表', 'Timetable performance', 'lineup', 92),
    arrayStrategy: { type: 'keyed-list', keyPath: 'identityKey', orderMatters: true },
  },
  'links.referenceLinks': {
    labelZh: '参考链接',
    labelEn: 'Reference links',
    category: 'links',
    audience: 'operator',
    publicSafe: false,
    arrayStrategy: { type: 'set' },
  },
  'links.socialLinks': publicScalar('社交链接', 'Social links', 'links'),
  'links.sourceProvider': privateScalar('来源平台', 'Source provider', 'source'),
  'links.sourceEventUrl': privateScalar('来源链接', 'Source event URL', 'source'),
};

registerEntityChangeDefinition({
  entityType: 'event',
  snapshotSchemaVersion: 1,
  buildSnapshot: buildEventChangeSnapshot,
  paths: eventChangePaths,
});
