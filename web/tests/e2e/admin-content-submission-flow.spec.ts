import { expect, test, type Page, type Route } from '@playwright/test';

const adminUser = {
  id: 'admin-user-content-flow',
  username: 'admin',
  email: 'admin@example.com',
  displayName: 'Admin User',
  avatarUrl: null,
  role: 'admin',
};

const tinyPng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9s1o1T8AAAAASUVORK5CYII=',
  'base64'
);
const tinyPngDataUrl = `data:image/png;base64,${tinyPng.toString('base64')}`;

type SubmissionEntityType = 'dj' | 'brand';

type SubmissionState = {
  id: string;
  submitterId: string;
  entityType: SubmissionEntityType;
  status: 'reviewing' | 'approved';
  title: string;
  payload: Record<string, unknown>;
  reviewReason: string | null;
  reviewNotes: Record<string, unknown> | null;
  reviewedAt: string | null;
  reviewedBy: string | null;
  createdEntityId: string | null;
  createdAt: string;
  updatedAt: string;
  versions: Array<{
    id: string;
    submissionId: string;
    version: number;
    title: string;
    payload: Record<string, unknown>;
    submittedAt: string;
    submittedBy: string | null;
    changeNote: string | null;
  }>;
};

const setupAdminAuth = async (page: Page) => {
  await page.route('**/v1/auth/refresh', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user: adminUser,
        token: 'content-flow-token',
        accessToken: 'content-flow-token',
      }),
    });
  });

  await page.route('**/v1/profile/me', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(adminUser),
    });
  });
};

const createImageFile = (name: string) => ({
  name,
  mimeType: 'image/png',
  buffer: tinyPng,
});

const buildSubmissionState = (
  entityType: SubmissionEntityType,
  payload: Record<string, unknown>,
  title: string,
  submissionId: string
): SubmissionState => {
  const now = new Date().toISOString();
  return {
    id: submissionId,
    submitterId: adminUser.id,
    entityType,
    status: 'reviewing',
    title,
    payload,
    reviewReason: null,
    reviewNotes: null,
    reviewedAt: null,
    reviewedBy: null,
    createdEntityId: null,
    createdAt: now,
    updatedAt: now,
    versions: [
      {
        id: `${submissionId}-v1`,
        submissionId,
        version: 1,
        title,
        payload,
        submittedAt: now,
        submittedBy: adminUser.id,
        changeNote: 'Playwright regression submission',
      },
    ],
  };
};

const fulfillJson = async (route: Route, body: unknown) => {
  await route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify(body),
  });
};

test('Web Admin DJ create -> review -> edit detail backfill flow works', async ({ page }) => {
  await setupAdminAuth(page);

  let submission: SubmissionState | null = null;
  let persistedDJ: Record<string, unknown> | null = null;

  await page.route('**/v1/djs/upload-image', async (route) => {
    const usage = route.request().postDataBuffer()?.toString().includes('banner') ? 'banner' : '';
    const routeUsage =
      route.request().postDataBuffer()?.toString().includes('proof') ? 'proof' : usage || 'avatar';
    await fulfillJson(route, {
      url: tinyPngDataUrl,
      originalUrl: tinyPngDataUrl,
      fileName: `dj-${routeUsage}.png`,
    });
  });

  await page.route('**/v1/djs/delete-images', async (route) => {
    await fulfillJson(route, { success: true });
  });

  await page.route('**/v1/djs/manual/import', async (route) => {
    const payload = route.request().postDataJSON() as Record<string, unknown>;
    submission = buildSubmissionState('dj', payload, String(payload.name), 'submission-dj-001');
    await fulfillJson(route, {
      data: {
        message: 'DJ 已进入审核队列',
        submission: {
          id: submission.id,
          entityType: submission.entityType,
          status: submission.status,
          title: submission.title,
          createdEntityId: null,
        },
      },
    });
  });

  await page.route('**/v1/djs/*', async (route) => {
    const pathname = new URL(route.request().url()).pathname;
    if (route.request().method() === 'GET' && pathname === '/v1/djs/dj-approved-001' && persistedDJ) {
      await fulfillJson(route, { data: persistedDJ });
      return;
    }
    await route.fallback();
  });

  await page.route('**/api/admin/v1/content-submissions**', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname;

    if (!submission) {
      await fulfillJson(route, {
        items: [],
        total: 0,
        pagination: { page: 1, limit: 20, total: 0, totalPages: 1 },
      });
      return;
    }

    if (request.method() === 'GET' && path === '/api/admin/v1/content-submissions') {
      const includeApproved = url.searchParams.get('status') === 'approved';
      const shouldInclude = submission.status === 'reviewing' || includeApproved;
      await fulfillJson(route, {
        items: shouldInclude ? [submission] : [],
        total: shouldInclude ? 1 : 0,
        pagination: { page: 1, limit: 20, total: shouldInclude ? 1 : 0, totalPages: 1 },
      });
      return;
    }

    if (request.method() === 'GET' && path === `/api/admin/v1/content-submissions/${submission.id}`) {
      await fulfillJson(route, { submission });
      return;
    }

    if (request.method() === 'POST' && path === `/api/admin/v1/content-submissions/${submission.id}/review`) {
      const body = request.postDataJSON() as { decision: 'approved' | 'rejected'; reviewNotes?: Record<string, unknown> };
      submission = {
        ...submission,
        status: body.decision === 'approved' ? 'approved' : 'reviewing',
        reviewNotes: body.reviewNotes || null,
        reviewedAt: new Date().toISOString(),
        reviewedBy: adminUser.id,
        createdEntityId: 'dj-approved-001',
        updatedAt: new Date().toISOString(),
      };
      persistedDJ = {
        id: 'dj-approved-001',
        name: submission.payload.name,
        nameI18n: submission.payload.nameI18n,
        aliases: submission.payload.aliases,
        genres: submission.payload.genres,
        bio: submission.payload.bio,
        bioI18n: submission.payload.bioI18n,
        avatarUrl: submission.payload.avatarUrl,
        bannerUrl: submission.payload.bannerUrl,
        country: submission.payload.country,
        countryI18n: submission.payload.countryI18n,
        spotifyId: submission.payload.spotifyId,
        spotifyUrl: submission.payload.spotifyUrl,
        spotifyFollowers: submission.payload.spotifyFollowers,
        appleMusicId: submission.payload.appleMusicId,
        instagramUrl: submission.payload.instagramUrl,
        facebookUrl: submission.payload.facebookUrl,
        soundcloudUrl: submission.payload.soundcloudUrl,
        soundcloudId: submission.payload.soundcloudId,
        twitterUrl: submission.payload.twitterUrl,
        youtubeUrl: submission.payload.youtubeUrl,
        neteaseUrl: submission.payload.neteaseUrl,
        qqMusicUrl: submission.payload.qqMusicUrl,
        website: submission.payload.website,
        otherPlatformUrl: submission.payload.otherPlatformUrl,
        trackCount: submission.payload.trackCount,
        playlistCount: submission.payload.playlistCount,
        soundCloudFollowers: submission.payload.soundCloudFollowers,
        soundCloudFavorites: submission.payload.soundCloudFavorites,
        canEdit: true,
      };

      await fulfillJson(route, {
        message: '审核通过，内容已入库',
        submission,
      });
      return;
    }

    await route.fallback();
  });

  await page.goto('/admin/content/djs/new');

  await page.getByPlaceholder('例如：Martin Garrix').fill('回填测试 DJ');
  await page.locator('input[type="file"]').nth(0).setInputFiles(createImageFile('dj-avatar.png'));
  await page.locator('input[type="file"]').nth(1).setInputFiles(createImageFile('dj-banner.png'));
  await page.locator('input[type="file"]').nth(2).setInputFiles(createImageFile('dj-proof.png'));
  await page.getByPlaceholder('例如：Ytram').fill('YTRAM');
  await page.getByPlaceholder('例如：Progressive House').fill('Progressive House');
  await page.getByPlaceholder('例如：荷兰').fill('荷兰');
  await page.getByPlaceholder('DJ 简介、风格、代表经历等').fill('这是一条用于回填验证的 DJ 简介。');
  await page.getByRole('button', { name: '下一步' }).click();

  await page.getByLabel('Spotify 编号').fill('spotify-dj-001');
  await page.getByLabel('Spotify 链接').fill('https://open.spotify.com/artist/dj-001');
  await page.getByLabel('Apple Music 编号').fill('apple-dj-001');
  await page.getByLabel('Instagram 链接').fill('https://instagram.com/dj-001');
  await page.getByLabel('Facebook 链接').fill('https://facebook.com/dj-001');
  await page.getByLabel('SoundCloud 链接').fill('https://soundcloud.com/dj-001');
  await page.getByLabel('SoundCloud 编号').fill('soundcloud-dj-001');
  await page.getByLabel('X / Twitter 链接').fill('https://x.com/dj-001');
  await page.getByLabel('YouTube 链接').fill('https://youtube.com/dj-001');
  await page.getByLabel('网易云 URL').fill('https://music.163.com/#/artist?id=1001');
  await page.getByLabel('QQ 音乐 URL').fill('https://y.qq.com/n/ryqq/singer/001');
  await page.getByLabel('官网 URL').fill('https://dj-001.example.com');
  await page.getByLabel('其他平台 URL').fill('https://linktr.ee/dj-001');
  await page.getByLabel('Spotify Followers').fill('123456');
  await page.getByLabel('曲目数').fill('88');
  await page.getByLabel('歌单数').fill('12');
  await page.getByLabel('SoundCloud 粉丝数').fill('34567');
  await page.getByLabel('SoundCloud 收藏数').fill('890');
  await page.getByRole('button', { name: '下一步' }).click();

  await page.getByRole('button', { name: '提交 DJ' }).click();
  await expect(page.getByText('DJ 已进入审核队列')).toBeVisible();

  await page.goto('/admin/content/reviews/submissions');
  await expect(page.getByRole('heading', { name: '内容贡献审核' })).toBeVisible();
  await expect(page.getByRole('heading', { name: '回填测试 DJ' })).toBeVisible();
  await page.getByRole('button', { name: 'Approve' }).click();
  await expect(page.getByRole('heading', { name: '审核已通过，可继续处理推送' })).toBeVisible();
  await page.getByRole('link', { name: '打开已入库内容' }).click();

  await expect(page).toHaveURL(/\/admin\/content\/djs\/dj-approved-001\/edit/);
  await expect(page.getByPlaceholder('例如：Martin Garrix')).toHaveValue('回填测试 DJ');
  await expect(page.getByPlaceholder('例如：Ytram')).toHaveValue('YTRAM');
  await expect(page.getByPlaceholder('例如：Progressive House')).toHaveValue('Progressive House');
  await expect(page.getByPlaceholder('例如：荷兰')).toHaveValue('荷兰');
  await expect(page.getByPlaceholder('DJ 简介、风格、代表经历等')).toHaveValue('这是一条用于回填验证的 DJ 简介。');

  await page.getByRole('button', { name: '下一步' }).click();
  await expect(page.getByLabel('Spotify 编号')).toHaveValue('spotify-dj-001');
  await expect(page.getByLabel('Spotify 链接')).toHaveValue('https://open.spotify.com/artist/dj-001');
  await expect(page.getByLabel('Apple Music 编号')).toHaveValue('apple-dj-001');
  await expect(page.getByLabel('Instagram 链接')).toHaveValue('https://instagram.com/dj-001');
  await expect(page.getByLabel('SoundCloud 链接')).toHaveValue('https://soundcloud.com/dj-001');
  await expect(page.getByLabel('曲目数')).toHaveValue('88');
  await expect(page.getByLabel('歌单数')).toHaveValue('12');
  await expect(page.getByLabel('SoundCloud 粉丝数')).toHaveValue('34567');
  await expect(page.getByLabel('SoundCloud 收藏数')).toHaveValue('890');
});

test('Web Admin brand create -> review -> edit detail backfill flow works', async ({ page }) => {
  await setupAdminAuth(page);

  let submission: SubmissionState | null = null;
  let persistedBrand: Record<string, unknown> | null = null;

  await page.route('**/v1/wiki/brands/upload-image', async (route) => {
    const raw = route.request().postDataBuffer()?.toString() || '';
    const usage = raw.includes('background') ? 'background' : raw.includes('proof') ? 'proof' : 'avatar';
    await fulfillJson(route, {
      url: tinyPngDataUrl,
      originalUrl: tinyPngDataUrl,
      fileName: `brand-${usage}.png`,
    });
  });

  await page.route('**/v1/wiki/brands/delete-images', async (route) => {
    await fulfillJson(route, { success: true });
  });

  await page.route('**/v1/learn/festivals', async (route) => {
    if (route.request().method() !== 'POST') {
      await route.fallback();
      return;
    }
    const payload = route.request().postDataJSON() as Record<string, unknown>;
    submission = buildSubmissionState('brand', payload, String(payload.name), 'submission-brand-001');
    await fulfillJson(route, {
      data: {
        message: '主办方已进入审核队列',
        submission: {
          id: submission.id,
          entityType: submission.entityType,
          status: submission.status,
          title: submission.title,
          createdEntityId: null,
        },
      },
    });
  });

  await page.route('**/v1/learn/festivals/*', async (route) => {
    const pathname = new URL(route.request().url()).pathname;
    if (route.request().method() === 'GET' && pathname === '/v1/learn/festivals/brand-approved-001' && persistedBrand) {
      await fulfillJson(route, { data: persistedBrand });
      return;
    }
    await route.fallback();
  });

  await page.route('**/api/admin/v1/content-submissions**', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const path = url.pathname;

    if (!submission) {
      await fulfillJson(route, {
        items: [],
        total: 0,
        pagination: { page: 1, limit: 20, total: 0, totalPages: 1 },
      });
      return;
    }

    if (request.method() === 'GET' && path === '/api/admin/v1/content-submissions') {
      const includeApproved = url.searchParams.get('status') === 'approved';
      const shouldInclude = submission.status === 'reviewing' || includeApproved;
      await fulfillJson(route, {
        items: shouldInclude ? [submission] : [],
        total: shouldInclude ? 1 : 0,
        pagination: { page: 1, limit: 20, total: shouldInclude ? 1 : 0, totalPages: 1 },
      });
      return;
    }

    if (request.method() === 'GET' && path === `/api/admin/v1/content-submissions/${submission.id}`) {
      await fulfillJson(route, { submission });
      return;
    }

    if (request.method() === 'POST' && path === `/api/admin/v1/content-submissions/${submission.id}/review`) {
      const body = request.postDataJSON() as { decision: 'approved' | 'rejected'; reviewNotes?: Record<string, unknown> };
      submission = {
        ...submission,
        status: body.decision === 'approved' ? 'approved' : 'reviewing',
        reviewNotes: body.reviewNotes || null,
        reviewedAt: new Date().toISOString(),
        reviewedBy: adminUser.id,
        createdEntityId: 'brand-approved-001',
        updatedAt: new Date().toISOString(),
      };
      persistedBrand = {
        id: 'brand-approved-001',
        name: submission.payload.name,
        nameI18n: submission.payload.nameI18n,
        revision: 7,
        abbreviation: submission.payload.abbreviation,
        aliases: submission.payload.aliases,
        country: submission.payload.country,
        countryI18n: submission.payload.countryI18n,
        city: submission.payload.city,
        cityI18n: submission.payload.cityI18n,
        foundedYear: submission.payload.foundedYear,
        frequency: submission.payload.frequency,
        frequencyI18n: {
          zh: submission.payload.frequency,
          en: submission.payload.frequency,
          ja: '',
          enFull: '',
        },
        tagline: submission.payload.tagline,
        introduction: submission.payload.introduction,
        descriptionI18n: submission.payload.descriptionI18n,
        officialWebsite: submission.payload.officialWebsite,
        facebookUrl: submission.payload.facebookUrl,
        instagramUrl: submission.payload.instagramUrl,
        twitterUrl: submission.payload.twitterUrl,
        youtubeUrl: submission.payload.youtubeUrl,
        tiktokUrl: submission.payload.tiktokUrl,
        avatarUrl: submission.payload.avatarUrl,
        backgroundUrl: submission.payload.backgroundUrl,
        imageAssets: submission.payload.imageAssets,
        links: submission.payload.links,
        canEdit: true,
      };

      await fulfillJson(route, {
        message: '审核通过，内容已入库',
        submission,
      });
      return;
    }

    await route.fallback();
  });

  await page.goto('/admin/content/organizers/new');

  await page.locator('input[type="file"]').nth(0).setInputFiles(createImageFile('brand-avatar.png'));
  await page.locator('input[type="file"]').nth(1).setInputFiles(createImageFile('brand-background.png'));
  await page.locator('input[type="file"]').nth(2).setInputFiles(createImageFile('brand-proof.png'));

  await page.getByPlaceholder('例如：Tomorrowland').fill('回填测试主办方');
  await page.getByLabel('简称').fill('RBT');
  await page.getByLabel('别名（逗号或换行分隔）').fill('RBT One\nRBT Two');
  await page.getByPlaceholder('例如：比利时').fill('日本');
  await page.getByPlaceholder('例如：Boom').fill('东京');
  await page.getByLabel('成立年份').fill('2018');
  await page.getByLabel('举办频率').fill('Quarterly');
  await page.getByLabel('一句话标签').fill('全球电子音乐品牌');
  await page.getByPlaceholder('填写中文介绍，其他语言通过右侧按钮补充。').fill('这是一条用于主办方回填验证的介绍。');
  await page.getByLabel('官方网站').fill('https://brand.example.com');
  await page.getByLabel('Instagram').fill('https://instagram.com/brand-001');
  await page.getByLabel('Facebook').fill('https://facebook.com/brand-001');
  await page.getByLabel('X / Twitter').fill('https://x.com/brand-001');
  await page.getByLabel('YouTube').fill('https://youtube.com/brand-001');
  await page.getByLabel('TikTok').fill('https://tiktok.com/@brand-001');

  await page.getByRole('button', { name: '添加链接' }).click();
  await page.getByPlaceholder('标题，例如 Ticket').fill('Ticket');
  await page.getByPlaceholder('icon，例如 link / ticket').fill('ticket');
  await page.locator('input[placeholder="https://..."]').last().fill('https://tickets.brand.example.com');

  await page.getByRole('checkbox', { name: '我确认当前图片、链接和文案具备可用权利' }).check();
  await page.getByRole('checkbox', { name: '我确认这确实是要创建或编辑的目标主办方实体' }).check();
  await page.getByRole('button', { name: '创建主办方' }).click();
  await expect(page.getByText('主办方已进入审核队列')).toBeVisible();

  await page.goto('/admin/content/reviews/submissions');
  await expect(page.getByRole('heading', { name: '内容贡献审核' })).toBeVisible();
  await expect(page.getByRole('heading', { name: '回填测试主办方' })).toBeVisible();
  await page.getByRole('button', { name: 'Approve' }).click();
  await expect(page.getByRole('heading', { name: '审核已通过，可继续处理推送' })).toBeVisible();
  await page.getByRole('link', { name: '打开已入库内容' }).click();

  await expect(page).toHaveURL(/\/admin\/content\/organizers\/brand-approved-001\/edit/);
  await expect(page.getByPlaceholder('例如：Tomorrowland')).toHaveValue('回填测试主办方');
  await expect(page.getByLabel('简称')).toHaveValue('RBT');
  await expect(page.getByLabel('别名（逗号或换行分隔）')).toHaveValue('RBT One\nRBT Two');
  await expect(page.getByPlaceholder('例如：比利时')).toHaveValue('日本');
  await expect(page.getByPlaceholder('例如：Boom')).toHaveValue('东京');
  await expect(page.getByLabel('成立年份')).toHaveValue('2018');
  await expect(page.getByLabel('举办频率')).toHaveValue('Quarterly');
  await expect(page.getByLabel('一句话标签')).toHaveValue('全球电子音乐品牌');
  await expect(page.getByPlaceholder('填写中文介绍，其他语言通过右侧按钮补充。')).toHaveValue('这是一条用于主办方回填验证的介绍。');
  await expect(page.getByLabel('官方网站')).toHaveValue('https://brand.example.com');
  await expect(page.getByLabel('Instagram')).toHaveValue('https://instagram.com/brand-001');
  await expect(page.getByLabel('Facebook')).toHaveValue('https://facebook.com/brand-001');
  await expect(page.getByLabel('X / Twitter')).toHaveValue('https://x.com/brand-001');
  await expect(page.getByLabel('YouTube')).toHaveValue('https://youtube.com/brand-001');
  await expect(page.getByLabel('TikTok')).toHaveValue('https://tiktok.com/@brand-001');
  await expect(page.locator('input[value="Ticket"]')).toBeVisible();
  await expect(page.locator('input[value="https://tickets.brand.example.com"]')).toBeVisible();
  await expect(page.getByText('当前为已持久化头像')).toBeVisible();
  await expect(page.getByText('当前为已持久化背景图')).toBeVisible();
});
