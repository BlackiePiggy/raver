# iOS Privacy Data Map

> Version: 2026-05-15  
> Scope: Raver iOS main app, Countdown Widget, Notification Service, server-side services used by the iOS app.  
> Tracking: Raver does not use collected data to track users across apps or websites owned by other companies.

## App Privacy Matrix

| Data set / fields | Apple data type | Source | Purpose | Linked | Tracking | Shared third party | Retention / deletion |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account ID, username, display name, avatar URL, profile bio | User ID, Name, Photos or Videos, Other User Content | Registration, profile edit, social login sync | App functionality, account management, social profile | Yes | No | Tencent IM/OpenIM identity sync, Ali OSS for media storage | Until account deletion; public identity is anonymized by account deletion worker |
| Email address, phone number, verification state | Email Address, Phone Number | Login, registration, account recovery, support and appeal forms | Account management, security, support | Yes | No | SMS/email provider when enabled; support workflow | Until account deletion or legal retention expiry; anonymized on deletion |
| Posts, comments, ratings, reports, appeals, moderation evidence | Other User Content, Photos or Videos | Feed, Discover, reports, moderation and appeal flows | App functionality, safety, moderation | Yes | No | Ali OSS for attachments; moderation/admin services | UGC follows content policy; removed or anonymized on account/content deletion |
| Private and group messages, media attachments, voice/audio messages | Emails or Text Messages, Photos or Videos, Audio Data | Tencent IM chat UI and message APIs | App functionality, user communication, safety reports | Yes | No | Tencent IM/OpenIM; Ali OSS for media objects | Retained for active conversations and safety obligations; account deletion queues IM deletion/anonymization |
| Precise coordinates, coarse location labels, venue/address text | Precise Location, Coarse Location | Compose post location picker, event editor, Squad live location uploader | App functionality, venue discovery, live squad map | Yes | No | Backend APIs; map/geocoding providers where configured | Squad live location ends with activity; deletion requests can remove location history |
| APNs token, device ID / identifierForVendor, locale, notification preferences | Device ID, User ID, Product Interaction | App registration, settings, push registration | App functionality, notification delivery, account security | Yes | No | APNs; Tencent IM push bridge where configured | APNs token revoked on logout/deletion; preferences remain until reset/deletion |
| Search history, hidden posts, feature flags, language, cached route/widget snapshots | Product Interaction, Other User Content | On-device UserDefaults/app group storage | App functionality, personalization, offline cache | Yes when synced, otherwise local only | No | Not shared except app group between app/extensions | Local cache can be cleared by logout/account deletion or app removal |
| Crash logs, probe logs, upload/download errors, performance diagnostics | Crash Data, Performance Data | iOS diagnostics, app logs, server/API logs | App functionality, reliability, fraud/safety debugging | Usually No; server logs may contain account IDs | No | Hosting/logging providers under service contracts | Rotated by operational retention; deletion requests remove direct account references where feasible |
| Purchases, tickets, virtual assets, balances, transaction IDs | Purchase History, User ID, Product Interaction | Virtual asset and event/ticket features | App functionality, account management, fraud prevention | Yes | No | Payment/ticketing providers when enabled | Retained as required by accounting, refund, and legal obligations |

## Required Reason API Evidence

| Target | API category | Evidence | Declared reason |
| --- | --- | --- | --- |
| RaverMVP | UserDefaults | `Core/AppConfig.swift`, `Core/AppState.swift`, `FeedViewModel.swift`, `RecentSearchStore.swift`, `VirtualAssetCacheStore.swift`, push app-group context | `CA92.1` for app/user settings, preferences, feature flags, notification context |
| RaverMVP | File Timestamp | `ChatMediaTempFileStore.swift`, `IMProbeLogger.swift`, `AppState.swift`, `IMStorageGovernance.swift` read or set file metadata for app-owned logs/media/cache | `C617.1` for app-container file/cache maintenance |
| RaverCountdownWidgets | File Timestamp | Widget snapshot/image store uses `FileManager.fileExists`, app-group files, and file reads/writes for widget content | `C617.1` for app-group widget file maintenance |
| RaverNotificationService | UserDefaults | `NotificationService.swift` reads app-group `push.currentUserID` to format mention notifications | `CA92.1` for app-group notification preference/context |

## Third-Party Data Flow

| Provider / SDK | Data involved | Purpose | Manifest / privacy notes |
| --- | --- | --- | --- |
| Tencent IM / OpenIM | User ID, display name, avatar, messages, attachments metadata, push bridge identifiers | Real-time private/group messaging and moderation evidence | SDK ships its own privacy manifest for accessed APIs; app manifest covers Raver-collected user/message data |
| SDWebImage / SDWebImageSwiftUI | Remote image URLs, cached image files | Image loading and cache management | Pods include privacy manifests; SDWebImage declares file timestamp access |
| Ali OSS | Avatar, post/event/chat/report media object keys and files | Media upload, storage, deletion/anonymization | App data map marks photos/videos/audio as linked, not tracking |
| APNs | Device token, notification payload metadata | Push delivery | Token is registered only after permission and removed on logout/deletion |
| Map/geocoding/location services | User-selected venue, coordinates, address text | Location picker, venue discovery, Squad live map | Permission soft prompt and manual address fallback are implemented |
| Music/event content services | Public artist/event/set identifiers and metadata | Discover and recommendation features | Public/content metadata, not cross-app tracking |

## App Store Connect Privacy Labels

Use the main app matrix above to configure App Store Connect:

- Tracking: No.
- Contact Info: Email Address, Phone Number, Name. Linked to user, not used for tracking.
- Location: Precise Location and Coarse Location. Linked to user, not used for tracking, app functionality.
- User Content: Photos or Videos, Audio Data, Emails or Text Messages, Other User Content. Linked to user, not used for tracking, app functionality and safety.
- Identifiers: User ID and Device ID. Linked to user, not used for tracking, app functionality/account management.
- Diagnostics: Crash Data and Performance Data. Not used for tracking; generally not linked in client diagnostics, server logs may include account IDs for operational support.
- Usage Data: Product Interaction. Linked to user when synced to backend, not used for tracking, app functionality and analytics.
- Purchases: Purchase History should be enabled before paid tickets, IAP, or virtual-asset purchases are launched in production.

## Review Checklist

- Privacy manifests are present in the main app, widget extension, and notification service extension.
- Required Reason APIs found in app-owned code are declared for each target that uses them.
- Third-party SDK manifests remain bundled through Pods/XCFramework integration.
- Re-run Xcode archive privacy report before App Store submission and update this map when paid commerce, analytics SDKs, or new third-party SDKs are enabled.
