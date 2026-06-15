# Genre Sound Cue Track Remaining Issues - 2026-06-14

## Current Status

- Total genres: 323
- Total sound cue tracks: 1938
- Tracks per genre: 6/6 for every genre
- Tracks missing NetEase URL: 0
- Latest quality audit: `/Users/blackie/Projects/raver/server/prisma/.cache/genre-sound-cue-quality-audit-2026-06-14T03-47-32-258Z.md`
- Genres needing replacement: 0
- High-risk issues: 0
- Medium-risk review notes: 80
- Latest curated apply report: `/Users/blackie/Projects/raver/server/prisma/.cache/curated-remaining-genre-sound-cue-tracks-2026-06-14T03-47-10-619Z.md`

## What Was Applied

- Applied 81 strict fallback replacements from `/Users/blackie/Projects/raver/server/prisma/.cache/genre-track-replacement-proposals-fallback-2026-06-14T03-32-07-608Z.json`.
- Applied 17 additional strict fallback replacements from `/Users/blackie/Projects/raver/server/prisma/.cache/genre-track-replacement-proposals-fallback-2026-06-14T03-37-14-100Z.json`.
- Applied curated replacements for the last high-risk groups: Celtic Ambient, Funk Proibidão, Latin Bass, Latincore, Singeli, Industrial and Post-Industrial, Hard Uplifting Trance, and Orchestral Trance.
- All applied replacements preserve tracks #1-#3 from the JSON-standard representative set and only replace modern tracks #4-#6.
- NetEase links were accepted only when both title and artist matched the MusicBrainz candidate.

## Previously Remaining Genres

| Genre | Current Issue | Recommendation |
|---|---|---|
| Celtic Ambient | Previously duplicated parent New Age Ambient modern tracks. | Resolved with Celtic-leaning ambient/new-age tracks from distinct artists. |
| Ragga Jungle | `μ‐Ziq` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Funk and Soul Fusion | A legitimate remix title was flagged because it contained a year. | Resolved by narrowing the suspicious title rule. |
| Acid Jazz | `Lyn` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Funk Proibidão | One modern track duplicated parent Funk Carioca. | Resolved with more specific Funk Proibidão tracks. |
| Latin Club | `2AT` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Latin Bass | One modern track duplicated parent Latin Club. | Resolved with Latin bass / folktronica tracks from different artists. |
| Latincore | Two modern tracks duplicated parent Latin Club. | Resolved with harder Latin club / deconstructed club tracks. |
| Singeli | Modern tracks were unrelated Global Club songs. | Resolved with Tanzanian Singeli-related artists available on NetEase. |
| Industrial and Post-Industrial | One modern track was stylistically unrelated. | Resolved with modern industrial/post-industrial tracks. |
| Forest Psytrance | `Vyd` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Suomisaundi | `Vyd` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Twilight Psytrance | `Vyd` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Hard Progressive Trance | `BK` was flagged because the artist name is short. | Resolved as audit false positive via short-artist allowlist. |
| Hard Uplifting Trance | Modern tracks duplicated parent Hard Trance. | Resolved with harder/uplifting trance tracks from distinct artists. |
| Orchestral Trance | One modern artist repeated and `RAM` was flagged as short. | Resolved with `Kelly Andrew - Xanadu (Orchestral Trance Mix)` and short-artist allowlist. |

## Suggested Next Step

No genre currently requires replacement. The remaining medium-risk notes are overlap reminders between parent, child, or sibling genres and can be reviewed later for even finer differentiation, but they do not indicate missing links or broken result-page data.
