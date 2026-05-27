import { defaultPosterHandler } from './handlers/default-poster';
import { djPosterHandler } from './handlers/dj-poster';
import { eventPosterHandler } from './handlers/event-poster';
import { festivalPosterHandler } from './handlers/festival-poster';
import { userProfilePosterHandler } from './handlers/user-profile-poster';
import { SharePosterHandler, SharePosterRequestContext } from './types';

const handlers: SharePosterHandler[] = [
  eventPosterHandler,
  djPosterHandler,
  userProfilePosterHandler,
  festivalPosterHandler,
  defaultPosterHandler,
];

export const resolveSharePosterHandler = (context: SharePosterRequestContext): SharePosterHandler =>
  handlers.find((handler) => handler.supports(context)) || defaultPosterHandler;
