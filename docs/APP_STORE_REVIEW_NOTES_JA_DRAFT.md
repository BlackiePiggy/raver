# App Store Review Notes Draft - Japan

> Draft date: 2026-05-15  
> Scope: iOS Japan compliance review notes for TestFlight/App Review.

## Account Deletion Path

Review test account:

- Regular user account: `[APP_REVIEW_USER_EMAIL_OR_PHONE]`
- Password / one-time code instruction: `[APP_REVIEW_PASSWORD_OR_OTP_INSTRUCTION]`
- Account state: active, not admin, not banned, can create reports and access settings.
- Notes before submission: replace the placeholders above with the real App Review credential, and keep this account seeded with at least one visible post or user profile that can be reported during review.

Japanese review path:

1. Sign in with the review test account.
2. Open `プロフィール` tab.
3. Tap `設定`.
4. Open `アカウント安全`.
5. Tap `アカウントを削除`.
6. Review the deletion scope and confirm in the second confirmation dialog.

Expected behavior:

- The app revokes the local session, clears local tokens/cache/IM state, unregisters the APNs token, and returns to signed-out state.
- The backend revokes refresh tokens, deactivates push tokens, anonymizes email/phone/profile/avatar/location/third-party bindings, and marks the account inactive.
- Public UGC remains available only under the deleted-account display policy, without exposing the original profile identity.
- External Tencent IM account deletion and Ali OSS avatar/media deletion are queued with retry state.
- Admins can inspect the request at `/admin/account-deletions`, see IM/OSS status, last failure reason, retry counters, target OSS keys, and trigger retry.

Support and privacy URLs:

- Privacy Policy: `/legal/privacy`
- Data Requests: `/legal/data-requests`
- Contact: `/legal/contact`
- Terms: `/legal/terms`
- Community Guidelines: `/legal/community-guidelines`
- Tokushoho / Commercial Transaction Notice: `/legal/tokushoho`
- Copyright Complaints: `/legal/copyright`
- Minor Safety: `/legal/minor-safety`

## Japanese Text For Review Notes

アカウント削除はアプリ内で完結できます。ログイン後、プロフィールタブから「設定」→「アカウント安全」→「アカウントを削除」を開き、削除範囲を確認したうえで二段階確認を完了してください。削除後はログアウトされ、ローカルトークン、IM セッション、キャッシュ、APNs トークンが無効化されます。サーバー側ではログイントークンとプッシュトークンを取り消し、メールアドレス、電話番号、プロフィール、アバター、位置情報、外部連携情報を匿名化します。公開投稿など法令・安全・監査上保持が必要なデータは、削除済みアカウントとして表示され、元のプロフィール情報は公開されません。Tencent IM アカウント削除と Ali OSS のアバター/メディア削除は管理画面の再試行キューで追跡されます。

## Safety, Reporting, Blocking, And Account Status

Recommended review scenarios:

- Report path: sign in with the review account, open a visible post/user profile/event/DJ/Set/Learn content item, then use `通報`.
- Block path: open a user profile or chat settings, tap `ブロック`, then confirm the user appears under `プロフィール -> 設定 -> プライバシー設定`.
- Account deletion path: use the same account path described above from `プロフィール -> 設定 -> アカウント安全`.
- Push permission denial path: open `プロフィール -> 設定 -> 通知`, choose the push notification entry point, and deny the iOS system prompt if shown; in-app notifications remain available.
- Location permission denial path: open a location-based posting, event discovery, check-in, or Squad location flow, deny the iOS system prompt if shown, and continue with manual search or manual address input where supported.

Japanese review paths:

- Report content or users: open a post, user profile, chat settings, event detail, DJ detail, Set detail, or Learn content page, then use the `通報` action.
- Block or unblock a user: open the user profile or chat settings, use `ブロック`, or manage blocked users from `プロフィール -> 設定 -> プライバシー設定`.
- Account enforcement and appeals: open `プロフィール -> 設定 -> アカウント安全` to view account status, active restrictions, and appeal history.
- Notifications: open `プロフィール -> 設定 -> 通知` to manage push and in-app notification preferences.

Expected behavior:

- Reporting supports reason, optional detail, attachment links, and optional blocking for user reports.
- Report decisions, content submission review results, and account enforcement notices use configurable notification templates with `ja-JP`, `en`, and `zh-CN` fallback.
- Blocking prevents direct messages and hides or filters blocked-user content from supported feeds, comments, search, recommendations, and invitations.
- Restricted or suspended users can still access settings, appeal, legal pages, data request information, and account deletion.
- In the Japan compliance mode, registration collects birth year to derive an age band. Accounts below the minimum age are rejected, and minor accounts receive additional restrictions for stranger direct messages, squad location sharing, and late-night third-party ticket links.
- RaveHub does not provide adult content. Adult/sexual content is prohibited content and is handled through report, review, removal, and account enforcement rather than age-gated distribution.
- Parents or guardians can contact support through in-app support/report flows or `support@raver.app`; the Minor Safety page documents this path.

## Permission Usage Notes

- Push notifications are used for messages, community interactions, event reminders, followed DJ or Brand updates, moderation results, and account status notices.
- Location is used only for user-initiated event discovery, check-ins, route or venue context, and Squad location sharing flows.
- Photos and media access are used for avatars, posts, event discussions, Squad content, report attachments, and related user-generated content uploads.
- Camera access, if requested by the build, is used for user-generated photos or media upload flows.

## Third-Party Music, Events, And Ticketing

- RaveHub displays music, DJ, festival, venue, and event information for discovery, community discussion, check-ins, ratings, reporting, and user-generated submissions.
- Third-party music or event names, artwork, lineups, venue information, and external links are provided by official public sources, event organizers, partner sources, or user submissions, and can be corrected or removed through the report and copyright complaint flows.
- If an event contains a ticketing link, RaveHub only displays an external link supplied by the event organizer, official source, partner source, or user submission. Ticket browsing, payment, refund, admission, and customer support are handled by the third-party organizer or ticketing provider outside the current iOS app flow.
- RaveHub does not operate ticket sales, process ticket payments, take ticketing commissions, sell memberships, sell digital content, or sell virtual assets through the current iOS App Store review build. No in-app purchase is required to use the reviewed flows.
- Music/video/audio link submissions require users to confirm they have posting rights or that the linked source is lawful and publicly referenceable; this confirmation is stored in review notes for moderation.
- Before enabling any self-operated paid digital content, membership, virtual asset, or ticket sale inside iOS, the app will use StoreKit / In-App Purchase where Apple rules require it.

## Japanese Text For Submission

レビュー用アカウントは提出前に App Store Connect の「サインイン情報」欄へ記載します。通常ユーザーとしてログインし、投稿・ユーザープロフィール・イベント・DJ・Set・Learn コンテンツから「通報」を確認できます。ブロックはユーザープロフィールまたはチャット設定から実行でき、ブロック済みユーザーは「プロフィール」→「設定」→「プライバシー設定」で管理できます。アカウント削除は「プロフィール」→「設定」→「アカウント安全」→「アカウントを削除」からアプリ内で完結します。通知は「プロフィール」→「設定」→「通知」から管理でき、iOS のプッシュ通知を拒否してもアプリ内通知は利用できます。位置情報を拒否した場合でも、対応フローでは手動検索または手入力で場所を指定できます。

RaveHub は音楽、DJ、フェスティバル、会場、イベント情報を、発見、コミュニティ投稿、チェックイン、評価、通報、ユーザー投稿のために表示します。第三者の音楽・イベント名、画像、ラインナップ、会場情報、外部リンクは、公式公開情報、主催者、提携元、またはユーザー投稿に基づくもので、通報および著作権窓口から修正・削除を依頼できます。チケットリンクが表示される場合、購入は第三者の主催者またはチケット事業者が提供する外部フローで行われます。今回の iOS 審査ビルドでは、RaveHub はアプリ内でチケット、会員、デジタルコンテンツ、仮想アイテムを販売せず、審査対象機能の利用に App 内課金は必要ありません。
