import test from 'node:test';
import assert from 'node:assert/strict';

import {
  scrapeDateFromDatetime,
  dedupeStrings,
  extractCountryFromScraped,
  sanitizeFolderToken,
  sanitizePhotoLabel,
  guessPhotoExt,
  mapScrapedEventToInfo,
} from '../js/esm/features/import/runtime/transform-mapper-utils.mjs';

test('ESM import runtime utils parse/sanitize helpers', () => {
  assert.equal(scrapeDateFromDatetime('2026-07-05T16:20:00Z'), '2026-07-05');
  assert.equal(scrapeDateFromDatetime('bad'), '');

  assert.deepEqual(dedupeStrings([' a ', 'a', '', 'b']), ['a', 'b']);
  assert.equal(sanitizeFolderToken('A/B:C*D?', 'x'), 'A B C D');
  assert.equal(sanitizePhotoLabel(' Main Stage #1 '), 'main_stage_1');
  assert.equal(guessPhotoExt('https://x.com/a.jpeg?x=1'), 'jpg');
  assert.equal(guessPhotoExt('bad-url'), 'jpg');
});

test('ESM import runtime utils extract country from scraped payload', () => {
  const event = {
    jsonld: [
      { '@type': 'Organization' },
      { '@type': 'Event', location: { address: { addressCountry: 'Belgium' } } },
    ],
  };
  assert.equal(extractCountryFromScraped(event), 'Belgium');
});

test('ESM import runtime mapper builds normalized import info', () => {
  const event = {
    start_datetime: '2026-07-05T16:20:00Z',
    end_datetime: '2026-07-07T22:00:00Z',
    title: 'Tomorrowland',
    venue: 'Boom',
    slug: 'tomorrowland-2026',
    event_url: 'https://fest.example/event',
    social_links: [{ type: 'instagram', url: 'https://ig.example/tml' }],
    quick_links: [{ url: 'https://fest.example/tickets' }],
    stream_platforms: [{ url: 'https://yt.example/live' }],
    photos: [{ label: 'cover', image_url: 'https://img.example/cover.jpg' }],
    jsonld: [{ '@type': 'Event', location: { address: { addressCountry: 'Belgium' } } }],
    timetable_details: [
      {
        date_text: '2026-07-05',
        stages: [
          {
            stage_name: 'Mainstage',
            sets: [
              {
                artist: 'Armin van Buuren',
                start_datetime: '2026-07-05T20:00:00Z',
                start_time: '20:00',
                end_time: '21:00',
                artist_image_url: 'https://img.example/armin.jpg',
              },
            ],
          },
        ],
      },
    ],
  };

  const info = mapScrapedEventToInfo(event, {
    buildFestivalId: () => '20260705-Tomorrowland-BEL',
  });

  assert.equal(info.name, 'Tomorrowland');
  assert.equal(info.startDate, '2026-07-05');
  assert.equal(info.endDate, '2026-07-07');
  assert.equal(info.country, 'Belgium');
  assert.equal(info.festivalId, '20260705-Tomorrowland-BEL');
  assert.equal(Array.isArray(info.socialLinks), true);
  assert.equal(info.relatedLinks.includes('https://fest.example/event'), true);
  assert.equal(info.lineup.length, 1);
  assert.equal(info.lineup[0].time, '20:00—21:00');
});
