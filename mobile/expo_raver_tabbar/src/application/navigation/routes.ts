export type MainTabKey = 'discover' | 'circle' | 'inbox' | 'profile';

export type DiscoverRoute =
  | { type: 'eventDetail'; eventID: string }
  | { type: 'djDetail'; djID: string }
  | { type: 'organizerDetail'; organizerID: string }
  | { type: 'globalSearch' };

export type AppRoute =
  | { type: 'discover'; route?: DiscoverRoute }
  | { type: 'circle' }
  | { type: 'inbox' }
  | { type: 'profile' };
