# Media OSS replacement guide

All page media is now centralized in `src/app/data/media.ts`.

After uploading files to Alibaba Cloud OSS, replace the corresponding value in
`media.ts` with the public HTTPS URL. Components should not need to change.

## Recommended OSS object names

| `media.ts` key | Current source | Suggested OSS object key |
| --- | --- | --- |
| `media.frames.iphone16ProPortrait` | Existing OSS URL | `ravehub/frames/iphone-16-pro-portrait.webp` |
| `media.videos.hero` | Existing OSS URL | `ravehub/videos/hero.mp4` |
| `media.videos.scrollShowcase` | Existing OSS URL, currently reserved | `ravehub/videos/scroll-showcase.mp4` |
| `media.videos.downloadBackground` | `thirdparty/background/背景烟花地图.mp4` | `ravehub/videos/download-background.mp4` |
| `media.images.aboutWorkspace` | Unsplash URL | `ravehub/images/about-workspace.jpg` |
| `media.projectImages.aesopEthereal` | Unsplash URL | `ravehub/projects/aesop-ethereal.jpg` |
| `media.projectImages.monoChair` | Unsplash URL | `ravehub/projects/mono-chair.jpg` |
| `media.projectImages.leicaPure` | Unsplash URL | `ravehub/projects/leica-pure.jpg` |
| `media.projectImages.bangOlufsen` | Unsplash URL | `ravehub/projects/bang-olufsen.jpg` |
| `media.projectImages.architecturalForm` | Unsplash URL | `ravehub/projects/architectural-form.jpg` |
| `media.projectImages.ceramicVoid` | Unsplash URL | `ravehub/projects/ceramic-void.jpg` |
| `media.capabilityScreens.events` | `src/assets/optimized/capabilities/capability-01-events.avif` | `ravehub/capabilities/01-events.avif` |
| `media.capabilityScreens.archive` | `src/assets/optimized/capabilities/capability-02-archive.avif` | `ravehub/capabilities/02-archive.avif` |
| `media.capabilityScreens.team` | `src/assets/optimized/capabilities/capability-03-team.avif` | `ravehub/capabilities/03-team.avif` |
| `media.capabilityScreens.community` | `src/assets/optimized/videos/capability-04-community.mp4` | `ravehub/capabilities/04-community.mp4` |
| `media.capabilityScreens.communitySets` | `src/assets/optimized/videos/capability-05-community-sets.mp4` | `ravehub/capabilities/05-community-sets.mp4` |
| `media.capabilityScreens.official` | `src/assets/optimized/capabilities/capability-06-official.avif` | `ravehub/capabilities/06-official.avif` |
| `media.communityShowcase.edmPersonality` | `src/assets/optimized/community/edm-personality.avif` | `ravehub/community/edm-personality.avif` |
| `media.communityShowcase.diyTimetable` | `src/assets/optimized/community/diy-timetable.avif` | `ravehub/community/diy-timetable.avif` |
| `media.communityShowcase.rollingBanner` | `src/assets/optimized/community/rolling-banner.avif` | `ravehub/community/rolling-banner.avif` |
| `media.communityShowcase.keepInTouch` | `src/assets/optimized/community/keep-in-touch.avif` | `ravehub/community/keep-in-touch.avif` |
| `media.communityShowcase.communityVideo01` | `src/assets/community/community-video-01.mp4` | `ravehub/community/community-video-01.mp4` |
| `media.communityShowcase.communityVideo02` | `src/assets/community/community-video-02.mp4` | `ravehub/community/community-video-02.mp4` |

## Replacement example

Before:

```ts
downloadBackground: downloadBackgroundVideo,
```

After:

```ts
downloadBackground: 'https://your-bucket.oss-cn-shanghai.aliyuncs.com/ravehub/videos/download-background.mp4',
```

After replacing a local import with an OSS URL, remove the unused import at the
top of `media.ts`.

## OSS settings checklist

- Use public read access for teaching/demo URLs, or bind CDN with public access.
- Set the correct `Content-Type`: `.mp4` as `video/mp4`, `.avif` as `image/avif`, `.jpg` as `image/jpeg`, `.png` as `image/png`.
- Enable CDN/cache headers for stable assets, for example `Cache-Control: public, max-age=31536000, immutable`.
- Keep filenames lowercase and URL-safe. Avoid spaces and Chinese characters in new OSS object keys.
- Compress videos before upload. For web background video, 720p or 1080p H.264 MP4 is usually enough.
- After replacement, run `npm run build` and preview the site to confirm media loads.
