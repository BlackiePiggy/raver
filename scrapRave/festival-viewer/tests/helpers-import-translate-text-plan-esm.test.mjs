import test from 'node:test';
import assert from 'node:assert/strict';

import {
  hasCjkChar,
  hasLatinChar,
  isEnglishFieldReady,
  isChineseFieldReady,
  toPlainBiText,
  parsePartialBiText,
  mergeTranslatedBiText,
  getFestivalTranslateKey,
  buildFestivalTranslatePlan,
} from '../js/esm/features/import/translate/text-plan-utils.mjs';

test('ESM import translate text-plan detects cjk/latin and field readiness', () => {
  assert.equal(hasCjkChar('明日世界'), true);
  assert.equal(hasCjkChar('Tomorrowland'), false);
  assert.equal(hasLatinChar('Tomorrowland'), true);
  assert.equal(hasLatinChar('明日世界'), false);

  assert.equal(isEnglishFieldReady('Tomorrowland'), true);
  assert.equal(isEnglishFieldReady('CN'), true);
  assert.equal(isEnglishFieldReady('明日世界'), false);

  assert.equal(isChineseFieldReady('明日世界'), true);
  assert.equal(isChineseFieldReady('Tomorrowland'), false);
});

test('ESM import translate text-plan normalizes and merges bi-text', () => {
  assert.deepEqual(
    toPlainBiText({ en: ' Tomorrowland ', zh: '' }, 'fallback'),
    { en: 'Tomorrowland', zh: 'Tomorrowland' }
  );
  assert.deepEqual(
    parsePartialBiText({ EN: 'Ultra', cn: '超世代' }),
    { en: 'Ultra', zh: '超世代' }
  );

  assert.deepEqual(
    mergeTranslatedBiText(
      { en: 'Tomorrowland', zh: '明日世界' },
      { en: 'Tomorrowland Belgium', zh: '' },
      { en: true, zh: false }
    ),
    { en: 'Tomorrowland Belgium', zh: '明日世界' }
  );
});

test('ESM import translate text-plan builds key and translation plan', () => {
  const festWithId = { info: { festivalId: '20260705-Tomorrowland-BEL' } };
  assert.equal(getFestivalTranslateKey(festWithId), '20260705-Tomorrowland-BEL');

  const festFallback = { year: 2026, folder: '7-Tomorrowland-Belgium', info: {} };
  assert.equal(getFestivalTranslateKey(festFallback), '2026/7-Tomorrowland-Belgium');

  const plan = buildFestivalTranslatePlan({
    year: 2026,
    folder: '7-Tomorrowland-Belgium',
    info: {
      nameI18n: { en: 'Tomorrowland', zh: '' },
      city: 'Boom',
      manualLocation: {
        detailAddressI18n: { en: 'De Schorre', zh: '' },
      },
      country: 'Belgium',
    },
  });

  assert.deepEqual(plan.nameBi, { en: 'Tomorrowland', zh: 'Tomorrowland' });
  assert.deepEqual(plan.cityBi, { en: 'Boom', zh: 'Boom' });
  assert.deepEqual(plan.detailAddressBi, { en: 'De Schorre', zh: 'De Schorre' });
  assert.deepEqual(plan.countryBi, { en: 'Belgium', zh: 'Belgium' });
  assert.deepEqual(plan.requestFestival, {
    name_i18n: { en: 'Tomorrowland', zh: 'Tomorrowland' },
    city_i18n: { en: 'Boom', zh: 'Boom' },
    detail_address_i18n: { en: 'De Schorre', zh: 'De Schorre' },
    formatted_address_i18n: { en: 'Belgium · Boom · De Schorre', zh: 'Belgium · Boom · De Schorre' },
    manual_location: {
      detail_address_i18n: { en: 'De Schorre', zh: 'De Schorre' },
      formatted_address_i18n: { en: 'Belgium · Boom · De Schorre', zh: 'Belgium · Boom · De Schorre' },
    },
    country_i18n: { en: 'Belgium', zh: 'Belgium' },
  });
});
