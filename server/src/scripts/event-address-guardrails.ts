import { resolveEventActivityAddressText, resolveEventVenueDisplayAddressText } from '../utils/event-address';
import { resolvePosterVenueText } from '../services/share-poster/localization';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const main = (): void => {
  const manualOnlyEvent = {
    manualLocation: {
      detailAddressI18n: {
        zh: '徐汇滨江 88 号',
        en: '88 Xuhui Riverside',
      },
      formattedAddressI18n: {
        zh: '中国 · 上海 · 徐汇滨江 88 号',
        en: 'China · Shanghai · 88 Xuhui Riverside',
      },
    },
    locationPoint: null,
  };

  const poiBackedEvent = {
    manualLocation: {
      detailAddressI18n: {
        zh: '徐汇滨江 88 号',
        en: '88 Xuhui Riverside',
      },
      formattedAddressI18n: {
        zh: '中国 · 上海 · 徐汇滨江 88 号',
        en: 'China · Shanghai · 88 Xuhui Riverside',
      },
    },
    locationPoint: {
      nameI18n: {
        zh: '滨江仓库',
        en: 'Riverside Warehouse',
      },
      formattedAddressI18n: {
        zh: '中国 · 上海 · 滨江仓库',
        en: 'China · Shanghai · Riverside Warehouse',
      },
      manualSetAddressI18n: {
        zh: '中国 · 上海 · 徐汇滨江 88 号',
        en: 'China · Shanghai · 88 Xuhui Riverside',
      },
    },
  };

  const poiWithoutManualSetEvent = {
    manualLocation: {
      detailAddressI18n: {
        zh: '徐汇滨江 88 号',
        en: '88 Xuhui Riverside',
      },
      formattedAddressI18n: {
        zh: '中国 · 上海 · 徐汇滨江 88 号',
        en: 'China · Shanghai · 88 Xuhui Riverside',
      },
    },
    locationPoint: {
      nameI18n: {
        zh: '滨江仓库',
        en: 'Riverside Warehouse',
      },
      formattedAddressI18n: {
        zh: '中国 · 上海 · 滨江仓库',
        en: 'China · Shanghai · Riverside Warehouse',
      },
    },
  };

  const emptyManualAddressEvent = {
    manualLocation: {
      detailAddressI18n: {
        zh: '徐汇滨江 88 号',
        en: '88 Xuhui Riverside',
      },
    },
    locationPoint: null,
  };

  assert(
    resolveEventActivityAddressText(poiBackedEvent) === '中国 · 上海 · 徐汇滨江 88 号',
    'activityAddress should only read manualLocation.formattedAddressI18n'
  );
  assert(
    resolveEventVenueDisplayAddressText(poiBackedEvent) === '中国 · 上海 · 徐汇滨江 88 号',
    'venueDisplayAddress should prefer locationPoint.manualSetAddressI18n'
  );
  assert(
    resolveEventVenueDisplayAddressText(poiWithoutManualSetEvent) === '中国 · 上海 · 滨江仓库',
    'venueDisplayAddress should fall back to locationPoint.formattedAddressI18n when manualSetAddressI18n is absent'
  );
  assert(
    resolveEventVenueDisplayAddressText(manualOnlyEvent) === '中国 · 上海 · 徐汇滨江 88 号',
    'venueDisplayAddress should fall back to manualLocation.formattedAddressI18n when locationPoint is absent'
  );
  assert(
    resolveEventVenueDisplayAddressText(emptyManualAddressEvent) === '徐汇滨江 88 号',
    'venueDisplayAddress should finally fall back to manualLocation.detailAddressI18n when formatted address is absent'
  );
  assert(
    resolvePosterVenueText(poiBackedEvent, 'zh') === '中国 · 上海 · 徐汇滨江 88 号',
    'poster venue text should align with venueDisplayAddress semantics'
  );
  assert(
    resolvePosterVenueText(poiWithoutManualSetEvent, 'zh') === '中国 · 上海 · 滨江仓库',
    'poster venue text should use provider formatted address when manualSetAddressI18n is absent'
  );
  assert(
    resolvePosterVenueText(emptyManualAddressEvent, 'zh') === '徐汇滨江 88 号',
    'poster venue text should only fall back to manual detail address, not city/country'
  );

  console.log('[event-address-guardrails] ok');
};

main();
