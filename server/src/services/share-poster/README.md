# Share Poster System

## Flow

1. Share link resolves to `targetType + targetId + metadata`.
2. Poster route collects `locale` and optional `variant`.
3. `renderSharePoster(...)` builds a `SharePosterRequestContext`.
4. Registry selects one handler by `targetType + variant`.
5. Handler loads a minimal snapshot from Prisma.
6. Handler renders SVG -> PNG with `@resvg/resvg-js`, or falls back to raster PNG when needed.

## Current Handlers

- `event-access`
  - Default event share poster.
  - Route example: `/poster/:code.png`
- `event-timetable`
  - Event timetable poster minimal case.
  - Route example: `/poster/:code.png?variant=timetable`
- `dj-profile`
  - DJ poster minimal case.
  - Works when share link `targetType = dj`
- `user-profile`
  - User profile poster minimal case.
  - Works when share link `targetType = user_card`
- `festival-intro`
  - Organizer / festival intro poster minimal case.
  - Works when share link `targetType = festival`
- `default`
  - Generic fallback card when no specialized handler matches.

## Extension Rules

1. Add a new handler in `handlers/`.
2. Keep it responsible for:
   - `supports(context)`
   - loading its own snapshot
   - rendering its own poster
3. Register it in `registry.ts`.
4. If the target type has no share seed yet, add it in `share-link.service.ts`.
5. Prefer:
   - SVG renderer for real poster styles
   - raster fallback only for degraded compatibility

## Poster Variant Strategy

- Primary routing key: `shareLink.targetType`
- Secondary routing key: `variant`
- Variant can come from:
  - query string `?variant=...`
  - `shareLink.metadata.posterVariant`

## Minimal Examples

### Event Access Poster

```ts
await renderSharePoster({
  prisma,
  shareLink,
  locale: 'zh',
});
```

### Event Timetable Poster

```ts
await renderSharePoster({
  prisma,
  shareLink,
  locale: 'en',
  variant: 'timetable',
});
```

### DJ Poster

```ts
await renderSharePoster({
  prisma,
  shareLink, // targetType = dj
  locale: 'en',
});
```

### User Poster

```ts
await renderSharePoster({
  prisma,
  shareLink, // targetType = user_card
  locale: 'zh',
});
```

### Festival Poster

```ts
await renderSharePoster({
  prisma,
  shareLink, // targetType = festival
  locale: 'zh',
});
```
