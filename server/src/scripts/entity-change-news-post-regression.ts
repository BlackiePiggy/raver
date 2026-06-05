import 'dotenv/config';
import {
  getEntityChangeDefinition,
  type EntitySnapshot,
} from '../modules/entity-change';
import { diffEntitySnapshots } from '../modules/entity-change/entity-change-diff-engine';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const snapshot = (
  entityType: 'news' | 'post',
  entityId: string,
  displayName: string,
  data: Record<string, unknown>
): EntitySnapshot => ({
  entityType,
  entityId,
  displayName,
  revision: null,
  schemaVersion: 1,
  capturedAt: new Date('2026-06-05T00:00:00.000Z').toISOString(),
  data,
});

const run = (): void => {
  const newsDefinition = getEntityChangeDefinition('news');
  const newsAfter = snapshot('news', 'news-regression', 'Regression News', {
    profile: {
      title: 'Regression News',
      summary: 'News summary',
      bodyPreview: 'Body preview for public detail',
      bodyHash: 'news-body-hash',
      category: 'community',
      source: 'Raver',
      visibility: 'public',
    },
    media: {
      coverImageUrl: 'https://cdn.example.com/news.jpg',
      link: 'https://example.com/news',
    },
    publish: {
      authorId: 'user-private',
      publishedAt: '2026-06-05T00:00:00.000Z',
    },
    bindings: {
      djIds: ['dj-1', 'dj-2'],
      brandIds: ['brand-1'],
      eventIds: ['event-1'],
    },
  });
  const newsCreate = diffEntitySnapshots({
    definition: newsDefinition,
    before: null,
    after: newsAfter,
  });
  assert(newsCreate.changes.length > 0, 'news create should be changed');
  assert(newsCreate.publicChanges.some((change) => change.path === 'profile.title'), 'news title should be public');
  assert(newsCreate.publicChanges.some((change) => change.path === 'profile.bodyPreview'), 'news body preview should be public');
  assert(newsCreate.publicChanges.some((change) => change.path === 'bindings.eventIds'), 'news event bindings should be public');
  assert(!newsCreate.publicChanges.some((change) => change.path === 'profile.bodyHash'), 'news body hash must stay private');
  assert(!newsCreate.publicChanges.some((change) => change.path === 'publish.authorId'), 'news author id must stay private');

  const newsBindingOrder = diffEntitySnapshots({
    definition: newsDefinition,
    before: snapshot('news', 'news-regression', 'Regression News', {
      ...newsAfter.data,
      bindings: { djIds: ['dj-1', 'dj-2'], brandIds: ['brand-1'], eventIds: ['event-1'] },
    }),
    after: snapshot('news', 'news-regression', 'Regression News', {
      ...newsAfter.data,
      bindings: { djIds: ['dj-2', 'dj-1'], brandIds: ['brand-1'], eventIds: ['event-1'] },
    }),
  });
  assert(newsBindingOrder.changes.length === 0, 'news binding order should not create diff');

  const postDefinition = getEntityChangeDefinition('post');
  const postAfter = snapshot('post', 'post-regression', 'Regression Post', {
    content: {
      preview: 'ID post content preview',
      hash: 'post-content-hash',
      titleI18n: null,
      summaryI18n: null,
      bodyI18n: null,
    },
    media: {
      images: ['https://cdn.example.com/a.jpg', 'https://cdn.example.com/b.jpg'],
    },
    context: {
      location: null,
      type: 'general',
      visibility: 'public',
      squadId: null,
      eventId: null,
      setId: null,
      displayPublishedAt: '2026-06-05T00:00:00.000Z',
    },
    stats: {
      likeCount: 0,
      repostCount: 0,
      saveCount: 0,
      shareCount: 0,
      hideCount: 0,
      commentCount: 0,
    },
    bindings: {
      djIds: ['dj-1'],
      brandIds: [],
      eventIds: ['event-1'],
    },
  });
  const postCreate = diffEntitySnapshots({
    definition: postDefinition,
    before: null,
    after: postAfter,
  });
  assert(postCreate.changes.length > 0, 'post create should be changed');
  assert(postCreate.publicChanges.some((change) => change.path === 'content.preview'), 'post content preview should be public');
  assert(postCreate.publicChanges.some((change) => change.path === 'media.images'), 'post images should be public');
  assert(postCreate.publicChanges.some((change) => change.path === 'bindings.djIds'), 'post DJ bindings should be public');
  assert(!postCreate.publicChanges.some((change) => change.path === 'content.hash'), 'post content hash must stay private');
  assert(!postCreate.publicChanges.some((change) => change.path.startsWith('stats.')), 'post stats must stay private');

  const postImageOrder = diffEntitySnapshots({
    definition: postDefinition,
    before: snapshot('post', 'post-regression', 'Regression Post', {
      ...postAfter.data,
      media: { images: ['https://cdn.example.com/a.jpg', 'https://cdn.example.com/b.jpg'] },
    }),
    after: snapshot('post', 'post-regression', 'Regression Post', {
      ...postAfter.data,
      media: { images: ['https://cdn.example.com/b.jpg', 'https://cdn.example.com/a.jpg'] },
    }),
  });
  assert(postImageOrder.changes.length === 0, 'post image order should not create diff');

  console.log('[entity-change-news-post-regression] ok');
};

try {
  run();
} catch (error) {
  console.error('[entity-change-news-post-regression] failed:', error);
  process.exit(1);
}
