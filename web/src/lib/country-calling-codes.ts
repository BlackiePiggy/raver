import { getCountries, getCountryCallingCode } from 'libphonenumber-js';
import { countries } from 'countries-list';

export type CountryCallingOption = {
  iso2: string;
  name: string;
  flagUrl: string;
  callingCode: string;
  value: string;
  label: string;
};

const PRIORITY_ISO2: string[] = [
  'CN', 'HK', 'MO', 'TW', 'SG', 'MY', 'TH', 'JP', 'KR',
  'US', 'CA', 'GB', 'DE', 'FR', 'AU', 'AE', 'IN', 'ID', 'VN',
];

const toName = (iso2: string): string => {
  const key = iso2.toUpperCase() as keyof typeof countries;
  return countries[key]?.name || key;
};

const toFlagUrl = (iso2: string): string =>
  `https://flagcdn.com/24x18/${iso2.toLowerCase()}.png`;

const getPriority = (iso2: string): number => {
  const idx = PRIORITY_ISO2.indexOf(iso2.toUpperCase());
  return idx === -1 ? Number.MAX_SAFE_INTEGER : idx;
};

const getCallingCodeNumber = (callingCode: string): number => Number(callingCode.replace('+', ''));

const countryCallingOptions: CountryCallingOption[] = getCountries()
  .map((iso2) => {
    const callingCode = `+${getCountryCallingCode(iso2)}`;
    const name = toName(iso2);
    return {
      iso2,
      name,
      flagUrl: toFlagUrl(iso2),
      callingCode,
      value: callingCode,
      label: `${name} (${callingCode})`,
    };
  })
  .sort((a, b) => {
    const pa = getPriority(a.iso2);
    const pb = getPriority(b.iso2);
    if (pa !== pb) {
      return pa - pb;
    }
    const codeDiff = getCallingCodeNumber(a.callingCode) - getCallingCodeNumber(b.callingCode);
    if (codeDiff !== 0) {
      return codeDiff;
    }
    return a.name.localeCompare(b.name, 'en');
  });

export const COUNTRY_CALLING_OPTIONS: CountryCallingOption[] = countryCallingOptions;
