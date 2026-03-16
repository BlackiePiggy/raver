# DJ Set & Aggregator Configuration

## Required Environment Variables

Add these to your `server/.env` file:

```env
# Spotify API (for DJ data aggregation and track search)
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret

# Discogs API (optional, for additional DJ data)
DISCOGS_TOKEN=your_discogs_token

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/raver_dev
```

## Getting API Keys

### Spotify API
1. Go to https://developer.spotify.com/dashboard
2. Create a new app
3. Copy Client ID and Client Secret

### Discogs API (Optional)
1. Go to https://www.discogs.com/settings/developers
2. Generate a personal access token

## Frontend Configuration

Add to `web/.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:3001/api
```

## Features Implemented

### 1. DJ Data Aggregation
- Automatically fetch DJ information from Spotify and Discogs
- Sync DJ profiles with external data sources
- Batch sync multiple DJs

**API Endpoints:**
- `POST /api/dj-aggregator/sync/:djId` - Sync single DJ
- `POST /api/dj-aggregator/batch-sync` - Batch sync DJs
- `GET /api/dj-aggregator/search/:name` - Search DJ data

### 2. DJ Set Video Module
- Embed YouTube and Bilibili videos
- Interactive tracklist with timestamp navigation
- Click track to jump to specific time in video
- Track status indicators (Released, ID, Remix, Edit)
- Auto-link tracks to streaming platforms

**API Endpoints:**
- `POST /api/dj-sets` - Create DJ set
- `GET /api/dj-sets/:id` - Get DJ set with tracks
- `GET /api/dj-sets/dj/:djId` - Get all sets by DJ
- `POST /api/dj-sets/:id/tracks` - Add single track
- `POST /api/dj-sets/:id/tracks/batch` - Batch add tracks
- `POST /api/dj-sets/:id/auto-link` - Auto-link tracks to streaming

### 3. Database Schema

**DJSet Table:**
- Video URL and platform (YouTube/Bilibili)
- DJ reference
- Metadata (title, description, venue, event)
- View and like counts

**Track Table:**
- Position in set
- Start/end timestamps
- Track info (title, artist, status)
- Streaming platform links (Spotify, Apple Music, YouTube Music, etc.)

## Usage Examples

### Create a DJ Set

```typescript
const djSet = await DJSetAPI.createDJSet({
  djId: 'dj-uuid',
  title: 'Boiler Room Berlin 2024',
  videoUrl: 'https://www.youtube.com/watch?v=xxxxx',
  description: 'Amazing techno set',
  venue: 'Berghain',
  eventName: 'Boiler Room',
});
```

### Add Tracks

```typescript
await DJSetAPI.batchAddTracks(djSet.id, [
  {
    position: 1,
    startTime: 0,
    endTime: 300,
    title: 'Track Name',
    artist: 'Artist Name',
    status: 'released',
  },
  {
    position: 2,
    startTime: 300,
    title: 'Unreleased ID',
    artist: 'Unknown',
    status: 'id',
  },
]);
```

### Auto-Link Tracks

```typescript
// Automatically search and link tracks to streaming platforms
await DJSetAPI.autoLinkTracks(djSet.id);
```

### Sync DJ Data

```typescript
// Sync single DJ
await DJAggregatorAPI.syncDJ(djId);

// Batch sync
await DJAggregatorAPI.batchSyncDJs([djId1, djId2, djId3]);
```

## Pages Created

- `/dj-sets/[id]` - DJ Set player with interactive tracklist
- `/djs/[djId]/sets` - List all sets by a DJ
- `/upload` - Upload new DJ set with tracklist

## Next Steps

1. Set up API keys in `.env`
2. Run database migration: `pnpm prisma migrate dev`
3. Start the server: `cd server && pnpm dev`
4. Start the web app: `cd web && pnpm dev`
5. Visit `/upload` to create your first DJ set