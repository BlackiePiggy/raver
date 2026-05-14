import { createMMKV } from 'react-native-mmkv';

export type PreferenceKey =
  | 'runtimeMode'
  | 'bffBaseURL'
  | 'language'
  | 'theme'
  | 'virtualAssetsEnabled';

const preferences = createMMKV({
  id: 'raver.preferences',
});

export function getStringPreference(key: PreferenceKey): string | undefined {
  return preferences.getString(key);
}

export function setStringPreference(key: PreferenceKey, value: string): void {
  preferences.set(key, value);
}

export function getBooleanPreference(key: PreferenceKey): boolean | undefined {
  return preferences.getBoolean(key);
}

export function setBooleanPreference(key: PreferenceKey, value: boolean): void {
  preferences.set(key, value);
}

export function deletePreference(key: PreferenceKey): void {
  preferences.remove(key);
}
