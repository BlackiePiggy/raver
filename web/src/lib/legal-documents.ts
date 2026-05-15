export type LegalLanguage = 'zh' | 'en' | 'ja';

export type LegalParagraph = Record<LegalLanguage, string>;

export type LegalSection = {
  title: LegalParagraph;
  paragraphs: LegalParagraph[];
  bullets?: LegalParagraph[];
};

export type LegalPreviousVersion = {
  version: string;
  effectiveAt: string;
  href: string;
};

export type LegalDocument = {
  slug: string;
  title: LegalParagraph;
  version: string;
  effectiveAt: string;
  updatedAt: string;
  previousVersions: LegalPreviousVersion[];
  intro: LegalParagraph;
  contact?: LegalParagraph;
  sections: LegalSection[];
};

type LegalDocumentSeed = Omit<LegalDocument, 'version' | 'effectiveAt' | 'previousVersions'> & {
  version?: string;
  effectiveAt?: string;
  previousVersions?: LegalPreviousVersion[];
};

const CURRENT_LEGAL_VERSION = '2026.05.15-jp-compliance-draft';
const CURRENT_EFFECTIVE_AT = '2026-05-15';

const baselinePreviousVersion = (slug: string): LegalPreviousVersion => ({
  version: '2026.05.15-baseline',
  effectiveAt: '2026-05-15',
  href: `/legal/archive/${slug}/2026.05.15-baseline`,
});

const docs: LegalDocumentSeed[] = [
  {
    slug: 'privacy',
    title: {
      zh: '隐私政策',
      en: 'Privacy Policy',
      ja: 'プライバシーポリシー',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '本页说明我们如何收集、使用、共享和保存你的个人信息。',
      en: 'This page explains how we collect, use, share, and retain personal information.',
      ja: 'このページでは、個人情報の収集、利用、共有、保管について説明します。',
    },
    contact: {
      zh: '如需访问、更正、删除或停止使用相关信息，请通过 App 内客服或下方联系方式联系我们。',
      en: 'To access, correct, delete, or stop the use of related information, contact us through in-app support or the contact details below.',
      ja: '情報の開示、訂正、削除、利用停止をご希望の場合は、アプリ内サポートまたは下記の連絡先までご連絡ください。',
    },
    sections: [
      {
        title: {
          zh: '我们收集的信息',
          en: 'Information We Collect',
          ja: '収集する情報',
        },
        paragraphs: [
          {
            zh: '我们会在你注册、登录、发帖、评论、私信、关注、举报、上传内容或使用位置、推送、IM 等功能时收集必要信息。',
            en: 'We collect information when you register, sign in, post, comment, message, follow, report, upload content, or use features such as location, push notifications, and IM.',
            ja: '登録、ログイン、投稿、コメント、メッセージ、フォロー、通報、コンテンツ投稿、位置情報、プッシュ通知、IM などの機能利用時に必要な情報を収集します。',
          },
          {
            zh: '这可能包括账号资料、联系方式、头像、UGC、消息内容、设备标识、推送 token、日志和使用记录。',
            en: 'This may include account profile data, contact details, avatars, UGC, message content, device identifiers, push tokens, logs, and usage records.',
            ja: 'これには、アカウント情報、連絡先、アバター、UGC、メッセージ内容、端末識別子、プッシュトークン、ログ、利用記録が含まれます。',
          },
        ],
        bullets: [
          {
            zh: '账号与联系方式：用户 ID、用户名、昵称、邮箱、手机号、登录凭证状态。',
            en: 'Account and contact data: user ID, username, display name, email, phone number, and login credential state.',
            ja: 'アカウント・連絡先情報：ユーザー ID、ユーザー名、表示名、メール、電話番号、ログイン認証情報の状態。',
          },
          {
            zh: '用户内容：头像、资料简介、帖子、评论、图片、视频、音频、私信、群聊、小队内容、活动/DJ/Set 投稿。',
            en: 'User content: avatars, profile bio, posts, comments, images, videos, audio, direct messages, group chats, squad content, and event/DJ/Set submissions.',
            ja: 'ユーザーコンテンツ：アバター、プロフィール文、投稿、コメント、画像、動画、音声、ダイレクトメッセージ、グループチャット、Squad コンテンツ、イベント/DJ/Set 投稿。',
          },
          {
            zh: '位置与活动数据：发帖地点、活动地点、Squad 位置共享、打卡和路线相关记录。',
            en: 'Location and activity data: post locations, event locations, squad location sharing, check-ins, and route-related records.',
            ja: '位置情報・活動データ：投稿位置、イベント場所、Squad 位置共有、チェックイン、ルート関連記録。',
          },
          {
            zh: '设备与诊断：设备标识、APNs 推送 token、设备平台、错误日志、使用记录、通知投递状态。',
            en: 'Device and diagnostics: device identifiers, APNs push tokens, device platform, error logs, usage records, and notification delivery state.',
            ja: '端末・診断情報：端末識別子、APNs プッシュトークン、端末プラットフォーム、エラーログ、利用記録、通知配信状態。',
          },
        ],
      },
      {
        title: {
          zh: '我们如何使用信息',
          en: 'How We Use Information',
          ja: '情報の利用目的',
        },
        paragraphs: [
          {
            zh: '我们使用这些信息来提供服务、保持登录状态、投递通知、支持举报与申诉、执行社区规则和防止滥用。',
            en: 'We use this information to provide services, keep you signed in, deliver notifications, support reports and appeals, enforce community rules, and prevent abuse.',
            ja: 'これらの情報は、サービス提供、ログイン維持、通知配信、通報・異議申立て対応、コミュニティルールの執行、不正利用防止のために使用します。',
          },
          {
            zh: '在法律要求或你提交删除请求时，我们也会按适用规则进行删除、匿名化或保留。',
            en: 'Where required by law or when you request account deletion, we may delete, anonymize, or retain data according to applicable rules.',
            ja: '法令上の要請やアカウント削除の申請時には、適用ルールに従って削除、匿名化、または保存します。',
          },
        ],
        bullets: [
          {
            zh: '账号创建、登录、会话刷新、账号安全、账号删除和客服支持。',
            en: 'Account creation, sign-in, session refresh, account security, account deletion, and support.',
            ja: 'アカウント作成、ログイン、セッション更新、アカウント安全、アカウント削除、サポート。',
          },
          {
            zh: 'UGC 展示、消息、关注、推荐、搜索、通知、举报、拉黑、封禁、申诉和审核。',
            en: 'UGC display, messages, follows, recommendations, search, notifications, reports, blocks, bans, appeals, and moderation.',
            ja: 'UGC 表示、メッセージ、フォロー、推薦、検索、通知、通報、ブロック、制裁、異議申立て、モデレーション。',
          },
          {
            zh: '安全风控、防作弊、反垃圾、运营统计、故障排查和法定义务履行。',
            en: 'Safety controls, anti-abuse, anti-spam, operational analytics, troubleshooting, and legal compliance.',
            ja: '安全管理、不正防止、スパム対策、運用分析、障害調査、法令遵守。',
          },
        ],
      },
      {
        title: {
          zh: '分享与第三方',
          en: 'Sharing and Third Parties',
          ja: '共有と第三者提供',
        },
        paragraphs: [
          {
            zh: '我们会把实现服务所必需的数据发送给云存储、推送、IM、分析和内容供应商。',
            en: 'We may share data with cloud storage, push, IM, analytics, and content providers as necessary to run the service.',
            ja: 'サービス運営に必要な範囲で、クラウドストレージ、プッシュ、IM、分析、コンテンツ提供事業者にデータを共有することがあります。',
          },
          {
            zh: '我们不会出售你的个人信息。',
            en: 'We do not sell your personal information.',
            ja: '個人情報を販売することはありません。',
          },
        ],
        bullets: [
          {
            zh: 'Tencent IM / OpenIM：消息与会话能力、IM 登录凭证、群组同步。',
            en: 'Tencent IM / OpenIM: messaging and conversation features, IM credentials, and group synchronization.',
            ja: 'Tencent IM / OpenIM：メッセージ・会話機能、IM 認証情報、グループ同期。',
          },
          {
            zh: 'Ali OSS / SDWebImage：头像、图片、媒体文件存储、加载和缓存。',
            en: 'Ali OSS / SDWebImage: avatar, image, and media storage, loading, and caching.',
            ja: 'Ali OSS / SDWebImage：アバター、画像、メディアファイルの保存、読み込み、キャッシュ。',
          },
          {
            zh: 'APNs：设备推送 token、通知投递与送达状态。',
            en: 'APNs: device push tokens, notification delivery, and delivery state.',
            ja: 'APNs：端末プッシュトークン、通知配信、配信状態。',
          },
          {
            zh: '音乐/票务/资料来源：Spotify、SoundCloud、Discogs、外部票务或资料链接，仅在功能需要时请求或展示。',
            en: 'Music, ticketing, and reference sources: Spotify, SoundCloud, Discogs, and external ticketing or reference links are requested or shown only when needed by a feature.',
            ja: '音楽、チケット、参照情報：Spotify、SoundCloud、Discogs、外部チケット・参照リンクは、機能上必要な場合にのみ取得または表示します。',
          },
        ],
      },
      {
        title: {
          zh: '跨境传输',
          en: 'Cross-Border Transfers',
          ja: '越境移転',
        },
        paragraphs: [
          {
            zh: '为提供全球活动、IM、云存储、推送和审核能力，相关数据可能在你所在国家或地区以外被处理。',
            en: 'To provide global event, IM, cloud storage, push, and moderation features, related data may be processed outside your country or region.',
            ja: 'グローバルなイベント、IM、クラウドストレージ、プッシュ通知、モデレーション機能を提供するため、関連データがお住まいの国・地域外で処理されることがあります。',
          },
          {
            zh: '我们会根据适用法律采取访问控制、最小必要、日志审计和供应商安全评估等措施。',
            en: 'We apply safeguards such as access control, data minimization, audit logs, and vendor security reviews according to applicable law.',
            ja: '適用法に従い、アクセス制御、最小限の利用、監査ログ、委託先の安全性評価などの保護措置を講じます。',
          },
        ],
      },
      {
        title: {
          zh: '保留与删除',
          en: 'Retention and Deletion',
          ja: '保存期間と削除',
        },
        paragraphs: [
          {
            zh: '账号删除后，我们会撤销登录凭证并对部分资料进行匿名化；法律、审计、风控或纠纷处理所需的数据可能继续保留一段时间。',
            en: 'After account deletion, we revoke login credentials and anonymize certain profile data; data required for legal, audit, risk, or dispute handling may remain for a limited period.',
            ja: 'アカウント削除後はログイン認証情報を失効し、一部プロフィール情報を匿名化します。法務、監査、リスク管理、紛争対応に必要なデータは一定期間保持される場合があります。',
          },
        ],
        bullets: [
          {
            zh: '立即处理：refresh token、access token 有效性、APNs token、账号资料、头像、简介、位置和登录能力。',
            en: 'Immediate handling: refresh tokens, access-token validity, APNs tokens, account profile, avatar, bio, location, and sign-in capability.',
            ja: '即時処理：refresh token、access token の有効性、APNs トークン、アカウントプロフィール、アバター、自己紹介、位置情報、ログイン機能。',
          },
          {
            zh: '匿名化处理：公开内容的作者展示、昵称、头像和可识别个人资料按删除账号策略处理。',
            en: 'Anonymization: public author display, display name, avatar, and identifiable profile data are handled under the deleted-account policy.',
            ja: '匿名化：公開コンテンツの投稿者表示、表示名、アバター、識別可能なプロフィール情報は削除済みアカウント方針に従って処理されます。',
          },
          {
            zh: '可能保留：举报、处罚、审计、支付/税务、法定义务、争议处理、安全风控和备份恢复所需的最小数据。',
            en: 'Possible retention: minimum data needed for reports, enforcement, audit, payment/tax, legal obligations, dispute handling, safety controls, and backup recovery.',
            ja: '保持される可能性：通報、制裁、監査、支払・税務、法令義務、紛争対応、安全管理、バックアップ復旧に必要な最小限のデータ。',
          },
          {
            zh: '撤回同意：你可以关闭权限、撤销通知、停止位置共享或申请删除账号；部分功能可能因此不可用。',
            en: 'Withdrawal of consent: you may disable permissions, revoke notifications, stop location sharing, or request account deletion; some features may become unavailable.',
            ja: '同意の撤回：権限の無効化、通知の解除、位置共有の停止、アカウント削除申請ができます。一部機能が利用できなくなる場合があります。',
          },
        ],
      },
    ],
  },
  {
    slug: 'terms',
    title: {
      zh: '服务条款',
      en: 'Terms of Service',
      ja: '利用規約',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '本页概述你在使用 RaveHub 时需要遵守的基本规则。',
      en: 'This page summarizes the core rules that apply when you use RaveHub.',
      ja: 'RaveHub の利用時に守っていただく基本ルールをまとめています。',
    },
    sections: [
      {
        title: {
          zh: '账号与安全',
          en: 'Accounts and Security',
          ja: 'アカウントと安全性',
        },
        paragraphs: [
          {
            zh: '你需要确保账号信息真实、完整，并对账号下的行为负责。',
            en: 'You must keep your account information accurate and are responsible for activity under your account.',
            ja: 'アカウント情報は正確に保ち、アカウント下での行為に責任を負ってください。',
          },
        ],
      },
      {
        title: {
          zh: '内容与社区',
          en: 'Content and Community',
          ja: 'コンテンツとコミュニティ',
        },
        paragraphs: [
          {
            zh: '你发布的内容不得侵犯他人权利、传播违法内容或恶意骚扰他人。',
            en: 'Content you post must not infringe rights, distribute unlawful material, or harass other users.',
            ja: '投稿内容は、他者の権利を侵害したり、違法な内容を拡散したり、他人を嫌がらせたりしてはいけません。',
          },
          {
            zh: 'RaveHub 不提供成人内容。色情、露骨性内容、性招揽和任何涉及未成年人的性内容均为禁止内容，平台可拒绝发布、下架、限制功能或处罚账号。',
            en: 'RaveHub does not provide adult content. Pornographic, explicit sexual, sexual solicitation, and any sexual content involving minors are prohibited; the platform may reject, remove, restrict features, or enforce against accounts.',
            ja: 'RaveHub は成人向けコンテンツを提供しません。ポルノ、露骨な性的表現、性的勧誘、未成年者に関する性的コンテンツは禁止され、投稿拒否、削除、機能制限、アカウント措置の対象になります。',
          },
          {
            zh: '提交音乐、视频、音频或外部链接时，你需要确认拥有发布权利，或确认来源合法且可公开引用。',
            en: 'When submitting music, video, audio, or external links, you must confirm that you have posting rights or that the source is lawful and publicly referenceable.',
            ja: '音楽、動画、音声、外部リンクを提出する場合、投稿権利があること、または出典が合法で公開参照可能であることを確認する必要があります。',
          },
        ],
      },
      {
        title: {
          zh: '平台权利',
          en: 'Our Rights',
          ja: '当社の権利',
        },
        paragraphs: [
          {
            zh: '在违反规则、存在安全风险或法律要求时，我们可以下架内容、限制功能、冻结账号或终止服务。',
            en: 'We may remove content, limit features, freeze accounts, or terminate service when rules are violated, safety risks arise, or the law requires it.',
            ja: '規約違反、安全上のリスク、法令上の要請がある場合、コンテンツ削除、機能制限、アカウント凍結、サービス終了を行うことがあります。',
          },
        ],
      },
    ],
  },
  {
    slug: 'community-guidelines',
    title: {
      zh: '社区规范',
      en: 'Community Guidelines',
      ja: 'コミュニティガイドライン',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '我们希望这里是一个对电音爱好者友善、清晰、可举报的社区。',
      en: 'We want this to be a friendly, clear, and reportable community for electronic music fans.',
      ja: 'ここを、電子音楽ファンにとって親しみやすく、分かりやすく、通報しやすい場にしたいと考えています。',
    },
    sections: [
      {
        title: {
          zh: '允许的行为',
          en: 'Allowed Behavior',
          ja: '許可される行為',
        },
        paragraphs: [
          {
            zh: '分享音乐、活动、创作、现场体验、评论和有建设性的反馈。',
            en: 'Share music, events, creations, live experiences, comments, and constructive feedback.',
            ja: '音楽、イベント、制作物、ライブ体験、コメント、建設的なフィードバックを共有してください。',
          },
        ],
      },
      {
        title: {
          zh: '禁止的行为',
          en: 'Prohibited Behavior',
          ja: '禁止される行為',
        },
        paragraphs: [
          {
            zh: '骚扰、仇恨、诈骗、垃圾信息、侵犯隐私、虚假身份、未经授权的内容搬运都不被允许。',
            en: 'Harassment, hate, fraud, spam, privacy violations, impersonation, and unauthorized reposting are not allowed.',
            ja: '嫌がらせ、ヘイト、詐欺、スパム、プライバシー侵害、なりすまし、無断転載は禁止です。',
          },
        ],
      },
    ],
  },
  {
    slug: 'contact',
    title: {
      zh: '联系方式',
      en: 'Contact',
      ja: 'お問い合わせ',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '如果你有隐私、条款、申诉、举报或账号删除相关问题，请使用以下方式联系我们。',
      en: 'For privacy, terms, appeals, reports, or account deletion questions, contact us using the channels below.',
      ja: 'プライバシー、規約、異議申立て、通報、アカウント削除に関するお問い合わせは、以下の窓口をご利用ください。',
    },
    sections: [
      {
        title: {
          zh: '客服与支持',
          en: 'Support',
          ja: 'サポート',
        },
        paragraphs: [
          {
            zh: 'App 内“设置 -> 账号安全”可提交账号删除和申诉；站内举报可在各内容页面发起。',
            en: 'Use Settings -> Account Security in the app to request account deletion or submit appeals; use report actions on content pages to send reports.',
            ja: 'アプリ内の「設定 -> アカウント安全」からアカウント削除や異議申立てを送信できます。通報は各コンテンツ画面から行えます。',
          },
        ],
      },
      {
        title: {
          zh: '联系邮箱',
          en: 'Email',
          ja: 'メール',
        },
        paragraphs: [
          {
            zh: 'support@raver.app',
            en: 'support@raver.app',
            ja: 'support@raver.app',
          },
        ],
      },
    ],
  },
  {
    slug: 'tokushoho',
    title: {
      zh: '特定商取引法表示',
      en: 'Specified Commercial Transactions Act',
      ja: '特定商取引法に基づく表記',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '本页列出 RaveHub 在日本提供有偿服务时需要展示的交易条件。当前 App Store 版本不提供 App 内有偿销售；任何收费功能上线前，本页会由日本法务确认并替换正式经营者信息。',
      en: 'This page lists the transaction terms required when RaveHub offers paid services in Japan. The current App Store version does not offer in-app paid sales; before any paid feature launches, Japan legal review will confirm and replace the formal operator details.',
      ja: 'このページでは、RaveHubが日本で有償サービスを提供する場合に表示すべき取引条件を記載します。現在のApp Store版ではアプリ内の有償販売を提供していません。有償機能を開始する前に、日本法務の確認を経て正式な事業者情報に差し替えます。',
    },
    sections: [
      {
        title: {
          zh: '当前状态',
          en: 'Current Status',
          ja: '現在の状況',
        },
        paragraphs: [
          {
            zh: 'RaveHub 当前面向日本区审核的 iOS 版本不销售会员、虚拟资产、数字内容、投稿加速、推广位或 App 内票券。活动页如展示票务信息，仅为活动主办方、官方来源、合作来源或用户提交的第三方外部链接；RaveHub 不售票、不处理票款、不提供退款或入场支持、不抽取票务佣金。交易主体、支付、退款和入场规则应以对应活动页面和主办方条款为准。',
            en: 'The iOS version prepared for Japan App Review currently does not sell memberships, virtual assets, digital content, post boosts, promotion placements, or in-app tickets. If an event page shows ticketing information, it is only a third-party external link supplied by the organizer, official source, partner source, or user submission; RaveHub does not sell tickets, process ticket payments, provide refunds or admission support, or take ticketing commissions. The transaction party, payment, refund, and admission rules are governed by the relevant event page and organizer terms.',
            ja: '日本のApp Review向けiOS版では、現在、会員、仮想資産、デジタルコンテンツ、投稿ブースト、広告枠、アプリ内チケットを販売していません。イベントページにチケット情報が表示される場合、それは主催者、公式情報源、提携情報源、またはユーザー投稿による第三者外部リンクに限られます。RaveHub はチケットを販売せず、決済処理、返金、入場サポート、チケット手数料の取得を行いません。取引主体、支払、返金、入場条件は該当イベントページおよび主催者の条件に従います。',
          },
        ],
      },
      {
        title: {
          zh: '经营者信息',
          en: 'Operator Information',
          ja: '事業者情報',
        },
        paragraphs: [
          {
            zh: '正式收费上线前必须补齐经营者名称、负责人、所在地、电话和可公开邮箱。当前客服邮箱为 support@raver.app；电话和地址如依法可通过邮件请求后提供，应在日本法务确认后明确说明。',
            en: 'Before paid services launch, the operator name, representative, address, telephone number, and public email must be completed. The current support email is support@raver.app; if telephone number and address are provided upon email request as permitted by law, Japan legal review must confirm that wording.',
            ja: '有償サービス開始前に、事業者名、代表者、所在地、電話番号、公開メールアドレスを記載します。現在のサポート窓口は support@raver.app です。電話番号および住所を法令上認められる範囲でメール請求後に開示する場合、その記載は日本法務の確認を経て掲載します。',
          },
        ],
        bullets: [
          {
            zh: '经营者名称：上线前由公司主体确认。',
            en: 'Operator name: to be confirmed by the corporate entity before launch.',
            ja: '事業者名：公開前に法人主体に基づき確定します。',
          },
          {
            zh: '负责人：上线前由公司主体确认。',
            en: 'Representative: to be confirmed by the corporate entity before launch.',
            ja: '責任者：公開前に法人主体に基づき確定します。',
          },
          {
            zh: '联系方式：support@raver.app。',
            en: 'Contact: support@raver.app.',
            ja: '連絡先：support@raver.app。',
          },
        ],
      },
      {
        title: {
          zh: '价格、费用和支付方式',
          en: 'Price, Fees, and Payment Methods',
          ja: '販売価格、手数料および支払方法',
        },
        paragraphs: [
          {
            zh: '如上线会员、数字内容、活动票券、虚拟资产、推广位或其他有偿服务，页面必须按商品或服务列明含税价格、附加费用、支付方式、支付时点、计费周期和自动续订条件。',
            en: 'If memberships, digital content, event tickets, virtual assets, promotion placements, or other paid services launch, the page must list tax-inclusive prices, additional fees, payment methods, payment timing, billing cycles, and auto-renewal terms for each product or service.',
            ja: '会員、デジタルコンテンツ、イベントチケット、仮想資産、広告枠、その他の有償サービスを開始する場合、商品またはサービスごとに税込価格、追加手数料、支払方法、支払時期、請求周期、自動更新条件を表示します。',
          },
        ],
        bullets: [
          {
            zh: 'iOS App 内数字商品：必须使用 Apple In-App Purchase，价格和退款由 App Store 显示和处理。',
            en: 'Digital goods in the iOS app: Apple In-App Purchase must be used; prices and refunds are shown and handled by the App Store.',
            ja: 'iOSアプリ内のデジタル商品：Apple In-App Purchaseを使用し、価格表示および返金はApp Storeの仕組みに従います。',
          },
          {
            zh: '活动票券或线下服务：应在活动页列明币种、含税/不含税、平台费、主办方和入场条件。',
            en: 'Event tickets or offline services: the event page should state currency, tax treatment, platform fees, organizer, and admission conditions.',
            ja: 'イベントチケットまたはオフラインサービス：イベントページに通貨、税込/税別、プラットフォーム手数料、主催者、入場条件を表示します。',
          },
          {
            zh: '非日本币种或跨境支付：必须说明汇率、手续费承担和支付服务提供方。',
            en: 'Non-JPY or cross-border payments: exchange rates, fee allocation, and payment service provider must be disclosed.',
            ja: '日本円以外または越境決済：為替レート、手数料負担、決済サービス提供者を表示します。',
          },
        ],
      },
      {
        title: {
          zh: '提供时点与使用环境',
          en: 'Delivery Timing and Operating Environment',
          ja: '提供時期および動作環境',
        },
        paragraphs: [
          {
            zh: '数字服务通常在支付确认后立即提供；票券、活动和线下服务按对应活动页面展示的时间、地点和入场规则提供。使用环境应列明支持的 iOS 版本、网络连接和账号登录要求。',
            en: 'Digital services are generally provided immediately after payment confirmation; tickets, events, and offline services are provided according to the time, venue, and admission rules shown on the relevant event page. Operating environment should state supported iOS versions, network connectivity, and sign-in requirements.',
            ja: 'デジタルサービスは通常、支払確認後ただちに提供されます。チケット、イベント、オフラインサービスは、該当イベントページに表示される日時、場所、入場条件に従って提供されます。動作環境として、対応iOSバージョン、通信環境、ログイン要件を表示します。',
          },
        ],
      },
      {
        title: {
          zh: '取消、退款和例外',
          en: 'Cancellation, Refunds, and Exceptions',
          ja: 'キャンセル、返金および例外',
        },
        paragraphs: [
          {
            zh: '收费功能上线前必须明确取消、退款、冷静期不适用、活动延期/取消、重复购买、未成年人购买和账号处罚/删除时的处理规则。',
            en: 'Before paid features launch, cancellation, refunds, cooling-off exceptions, event postponement/cancellation, duplicate purchases, minor purchases, and handling during account enforcement or deletion must be clearly stated.',
            ja: '有償機能開始前に、キャンセル、返金、クーリング・オフ適用除外、イベント延期/中止、重複購入、未成年者の購入、アカウント処分または削除時の取扱いを明記します。',
          },
        ],
        bullets: [
          {
            zh: 'App Store IAP 退款：用户应通过 Apple 的退款流程申请。',
            en: 'App Store IAP refunds: users should request refunds through Apple’s refund process.',
            ja: 'App Store IAPの返金：ユーザーはAppleの返金手続を通じて申請します。',
          },
          {
            zh: '活动票券退款：按活动页面、主办方规则和适用法律处理。',
            en: 'Event ticket refunds: handled according to the event page, organizer rules, and applicable law.',
            ja: 'イベントチケットの返金：イベントページ、主催者ルール、適用法令に従って対応します。',
          },
          {
            zh: '账号删除：可访问隐私政策和数据请求页面确认个人数据删除与保留范围；未消费的付费权益需按具体条款处理。',
            en: 'Account deletion: users can review the Privacy Policy and Data Requests page for deletion and retention scope; unused paid benefits are handled under the specific terms.',
            ja: 'アカウント削除：個人データの削除および保存範囲はプライバシーポリシーとデータ関連の請求ページで確認できます。未使用の有償権利は個別条件に従って取り扱います。',
          },
        ],
      },
    ],
  },
  {
    slug: 'data-requests',
    title: {
      zh: '数据请求',
      en: 'Data Requests',
      ja: 'データ関連の請求',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '你可以通过账号安全和支持渠道发起访问、更正、删除、停止使用或导出的请求。',
      en: 'You can use the account security and support channels to request access, correction, deletion, suspension of use, or export.',
      ja: 'アカウント安全やサポート窓口から、開示、訂正、削除、利用停止、エクスポートを申請できます。',
    },
    sections: [
      {
        title: {
          zh: '可请求的事项',
          en: 'Available Requests',
          ja: '請求できる内容',
        },
        paragraphs: [
          {
            zh: '账号信息、手机号、邮箱、头像、公开内容、删除请求状态和相关保留范围。',
            en: 'Account information, phone number, email, avatar, public content, deletion status, and retained categories.',
            ja: 'アカウント情報、電話番号、メール、アバター、公開コンテンツ、削除状況、保存対象の範囲を確認できます。',
          },
        ],
        bullets: [
          {
            zh: '访问：确认我们保存的账号、资料、内容和删除状态。',
            en: 'Access: confirm account, profile, content, and deletion status we retain.',
            ja: '開示：保存されているアカウント、プロフィール、コンテンツ、削除状況を確認できます。',
          },
          {
            zh: '更正：更正账号资料、联系方式或公开资料中的错误信息。',
            en: 'Correction: correct account profile, contact, or public profile information.',
            ja: '訂正：アカウント情報、連絡先、公開プロフィールの誤りを訂正できます。',
          },
          {
            zh: '删除/停止使用：删除账号、停用推送 token、停止位置共享或限制特定用途。',
            en: 'Deletion or suspension of use: delete your account, deactivate push tokens, stop location sharing, or limit specific uses.',
            ja: '削除・利用停止：アカウント削除、プッシュトークン無効化、位置共有停止、特定用途の制限を申請できます。',
          },
          {
            zh: '导出：在技术可行范围内导出账号资料、公开内容和关键操作记录。',
            en: 'Export: export account profile, public content, and key activity records where technically feasible.',
            ja: 'エクスポート：技術的に可能な範囲で、アカウント情報、公開コンテンツ、主要な操作記録を出力できます。',
          },
        ],
      },
      {
        title: {
          zh: '处理流程',
          en: 'Request Process',
          ja: '請求手続',
        },
        paragraphs: [
          {
            zh: '你可以通过 App 内“设置 -> 账号安全”、举报/申诉入口或 support@raver.app 提交请求。为保护账号安全，我们可能需要验证账号所有权。',
            en: 'Submit requests through Settings -> Account Security in the app, report/appeal flows, or support@raver.app. To protect your account, we may need to verify account ownership.',
            ja: 'アプリ内の「設定 -> アカウント安全」、通報・異議申立てフロー、または support@raver.app から申請できます。アカウント保護のため、本人確認をお願いする場合があります。',
          },
          {
            zh: '我们会记录请求类型、提交时间、处理状态、必要的内部备注和完成结果，并在合理期限内回复。',
            en: 'We record the request type, submission time, processing state, necessary internal notes, and completion result, and respond within a reasonable period.',
            ja: '請求種別、提出時刻、処理状態、必要な内部メモ、完了結果を記録し、合理的な期間内に回答します。',
          },
        ],
      },
    ],
  },
  {
    slug: 'copyright',
    title: {
      zh: '版权投诉',
      en: 'Copyright',
      ja: '著作権',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '如果你认为平台内容侵犯了你的版权，请通过支持渠道提交投诉并附上必要证据。',
      en: 'If you believe content on the platform infringes your copyright, submit a complaint through support with the necessary evidence.',
      ja: 'プラットフォーム上のコンテンツが著作権を侵害していると思われる場合は、必要な証拠を添えてサポートへご連絡ください。',
    },
    sections: [
      {
        title: {
          zh: '处理范围',
          en: 'What We Handle',
          ja: '対応範囲',
        },
        paragraphs: [
          {
            zh: '我们会评估下架、恢复、重复侵权处理以及反通知流程。',
            en: 'We assess takedown, restoration, repeat-infringement handling, and counter-notice flow.',
            ja: '削除、復元、繰り返し侵害への対応、異議申立て手続を確認します。',
          },
        ],
      },
      {
        title: {
          zh: '投诉与反通知',
          en: 'Complaints and Counter-Notices',
          ja: '申立てと異議通知',
        },
        paragraphs: [
          {
            zh: '投诉应包含权利人身份、被投诉内容链接、权利证明、联系方式以及善意声明。收到有效投诉后，我们可以临时下架内容、通知提交者，并记录处理状态。',
            en: 'Complaints should include the rights holder identity, the content URL, proof of rights, contact details, and a good-faith statement. After receiving a valid complaint, we may temporarily remove the content, notify the submitter, and record the handling state.',
            ja: '申立てには、権利者情報、対象コンテンツの URL、権利証明、連絡先、誠実な申告を含めてください。有効な申立てを受領した場合、当社は一時的な削除、投稿者への通知、対応状況の記録を行うことがあります。',
          },
          {
            zh: '提交者认为下架有误时，可以提交反通知并附上授权、来源或合理使用说明。我们会复核并根据法律要求决定维持下架、恢复内容或对重复侵权账号采取处罚。',
            en: 'If the submitter believes removal was mistaken, they may file a counter-notice with authorization, source, or fair-use information. We review it and decide whether to keep the content down, restore it, or enforce against repeat infringement.',
            ja: '投稿者が削除に誤りがあると考える場合、許諾、出典、または正当利用に関する説明を添えて異議通知を提出できます。当社は再確認し、削除維持、復元、または繰り返し侵害への措置を判断します。',
          },
        ],
      },
      {
        title: {
          zh: '提交者确认',
          en: 'Submitter Confirmation',
          ja: '投稿者の確認',
        },
        paragraphs: [
          {
            zh: '用户提交音乐、视频、音频或外部链接时，需要确认拥有发布权利，或确认链接来源合法且可公开引用。无法确认的内容可能被拒绝、临时下架或要求补充来源说明。',
            en: 'When users submit music, video, audio, or external links, they must confirm that they have posting rights or that the linked source is lawful and publicly referenceable. Content without confirmation may be rejected, temporarily removed, or require additional source information.',
            ja: 'ユーザーが音楽、動画、音声、外部リンクを提出する場合、投稿権利があること、またはリンク元が合法で公開参照可能であることを確認する必要があります。確認できないコンテンツは拒否、一時削除、または出典説明の追加を求める場合があります。',
          },
        ],
      },
    ],
  },
  {
    slug: 'minor-safety',
    title: {
      zh: '未成年人安全',
      en: 'Minor Safety',
      ja: '未成年者の安全',
    },
    updatedAt: '2026-05-15',
    intro: {
      zh: '我们会持续收紧未成年人、夜间活动、陌生人私信和位置共享相关的安全策略。',
      en: 'We continuously tighten safety policies for minors, late-night events, stranger messaging, and location sharing.',
      ja: '未成年者、深夜イベント、見知らぬ相手からのメッセージ、位置情報共有に関する安全対策を継続的に強化します。',
    },
    sections: [
      {
        title: {
          zh: '重点规则',
          en: 'Key Rules',
          ja: '主なルール',
        },
        paragraphs: [
          {
            zh: '我们优先处理骚扰、隐私泄露、危险约见和不适龄内容。',
            en: 'We prioritize harassment, privacy leaks, dangerous meetups, and age-inappropriate content.',
            ja: '嫌がらせ、プライバシー漏えい、危険な待ち合わせ、年齢不適切なコンテンツを優先的に扱います。',
          },
        ],
      },
      {
        title: {
          zh: '年龄声明与区域保护',
          en: 'Age Declaration and Regional Protections',
          ja: '年齢申告と地域別保護',
        },
        paragraphs: [
          {
            zh: '在日本区域，我们会在注册时收集出生年份并生成年龄段，用于最低年龄要求、未成年人安全保护和适龄体验。',
            en: 'For the Japan region, we collect birth year at registration and derive an age band for minimum-age checks, minor safety protections, and age-appropriate experiences.',
            ja: '日本地域では、登録時に生年を収集し、最低年齢確認、未成年者保護、年齢に応じた体験のために年齢区分を生成します。',
          },
          {
            zh: '未成年人账号会受到更严格的陌生人私信、位置共享、深夜活动第三方票务外链和不适龄内容限制。',
            en: 'Minor accounts are subject to stricter limits on stranger direct messages, location sharing, late-night third-party event ticket links, and age-inappropriate content.',
            ja: '未成年者アカウントには、見知らぬ相手からの DM、位置情報共有、深夜イベントの第三者チケットリンク、年齢不適切なコンテンツについて、より厳しい制限が適用されます。',
          },
        ],
      },
      {
        title: {
          zh: '监护人联系',
          en: 'Guardian Contact',
          ja: '保護者からの連絡',
        },
        paragraphs: [
          {
            zh: '家长或监护人可以通过 App 内客服、举报/申诉入口或 support@raver.app 联系我们，要求了解、限制或删除未成年人账号相关信息。',
            en: 'Parents or guardians may contact us through in-app support, report/appeal flows, or support@raver.app to ask about, restrict, or delete information related to a minor account.',
            ja: '保護者は、アプリ内サポート、通報・異議申立てフロー、または support@raver.app から、未成年者アカウントに関する情報確認、制限、削除を依頼できます。',
          },
        ],
      },
    ],
  },
];

export const legalDocuments: LegalDocument[] = docs.map((doc) => ({
  ...doc,
  version: doc.version ?? CURRENT_LEGAL_VERSION,
  effectiveAt: doc.effectiveAt ?? CURRENT_EFFECTIVE_AT,
  previousVersions: doc.previousVersions ?? [baselinePreviousVersion(doc.slug)],
}));

export const legalDocumentSlugs = legalDocuments.map((item) => item.slug);

export const legalDocumentMap = new Map(legalDocuments.map((item) => [item.slug, item]));
