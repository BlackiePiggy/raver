import { Prisma, PrismaClient } from '@prisma/client';
import { Request, Response } from 'express';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

const SALUTATIONS = new Set(['Miss.', 'Mr.', '先生', '女士']);
const DECISIONS = new Set(['SELECTED', 'NOT_SELECTED', 'WAITLIST']);
const NOTIFICATION_CHANNELS = new Set(['EMAIL', 'SMS', 'WECHAT', 'IN_APP']);

const DEFAULT_SUCCESS_MESSAGE = '预登记完成，请等待抽取内测资格，请静候佳音。';

const parsePositiveInt = (value: unknown, fallback: number): number => {
  const num = Number(value);
  if (!Number.isFinite(num) || num <= 0) return fallback;
  return Math.floor(num);
};

const parseBooleanFlag = (value: unknown): boolean | null => {
  if (value === undefined || value === null || value === '') return null;
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'y'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'n'].includes(normalized)) return false;
  return null;
};

const cleanText = (value: unknown): string | undefined => {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
};

const normalizePhoneNumber = (value: string | undefined): string | undefined => {
  if (!value) return undefined;
  const normalized = value.replace(/[\s\-()]/g, '');
  return normalized || undefined;
};

const normalizeEmail = (value: unknown): string => String(value || '').trim().toLowerCase();

const isValidEmail = (email: string): boolean => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

const isValidCountryCode = (value: string): boolean => /^\+\d{1,4}$/.test(value);

const isValidWechatId = (value: string): boolean => /^[a-zA-Z0-9_-]{3,64}$/.test(value);

const isValidSalutationName = (value: string): boolean =>
  /^[\p{L}\p{N}·•\-\s]{1,32}$/u.test(value);

const buildFullSalutation = (salutationName: string | null | undefined, salutation: string): string => {
  const name = (salutationName || '').trim();
  if (!name) return salutation;
  return `${name}${salutation}`;
};

const buildPreRegistrationSearchWhere = (search: string): Prisma.PreRegistrationWhereInput => ({
  OR: [
    { email: { contains: search, mode: 'insensitive' } },
    { phoneNumber: { contains: search, mode: 'insensitive' } },
    { wechatId: { contains: search, mode: 'insensitive' } },
    { salutationName: { contains: search, mode: 'insensitive' } },
  ],
});

export const createPreRegistration = async (req: Request, res: Response): Promise<void> => {
  try {
    const email = normalizeEmail(req.body.email);
    const salutationName = cleanText(req.body.salutationName);
    const salutation = cleanText(req.body.salutation);
    const phoneCountryCode = cleanText(req.body.phoneCountryCode);
    const phoneNumber = normalizePhoneNumber(cleanText(req.body.phoneNumber));
    const wechatId = cleanText(req.body.wechatId);
    const expectationMessage = cleanText(req.body.expectationMessage);
    const source = cleanText(req.body.source) || 'landing-home';

    if (!email) {
      res.status(400).json({ error: '邮箱为必填项' });
      return;
    }
    if (!isValidEmail(email)) {
      res.status(400).json({ error: '邮箱格式不正确' });
      return;
    }
    if (!salutation || !SALUTATIONS.has(salutation)) {
      res.status(400).json({ error: '请选择称呼' });
      return;
    }
    if (!salutationName) {
      res.status(400).json({ error: '请填写称呼名（如：李）' });
      return;
    }
    if (!isValidSalutationName(salutationName)) {
      res.status(400).json({ error: '称呼名格式不正确，建议使用姓名或昵称（1-32字符）' });
      return;
    }
    if (phoneCountryCode && !isValidCountryCode(phoneCountryCode)) {
      res.status(400).json({ error: '手机号国家区号格式不正确，应为 +XX' });
      return;
    }
    if (phoneNumber && !phoneCountryCode) {
      res.status(400).json({ error: '填写手机号时请先选择国家区号' });
      return;
    }
    if (phoneCountryCode && !phoneNumber) {
      res.status(400).json({ error: '填写国家区号后请补全手机号' });
      return;
    }
    if (wechatId && !isValidWechatId(wechatId)) {
      res.status(400).json({ error: '微信号格式不正确，仅支持字母、数字、下划线、减号' });
      return;
    }
    if (expectationMessage && expectationMessage.length > 500) {
      res.status(400).json({ error: '期望留言不能超过 500 字' });
      return;
    }

    const existing = await prisma.preRegistration.findUnique({ where: { email } });
    if (existing) {
      const updated = await prisma.preRegistration.update({
        where: { email },
        data: {
          salutationName,
          salutation,
          phoneCountryCode: phoneCountryCode ?? null,
          phoneNumber: phoneNumber ?? null,
          wechatId: wechatId ?? null,
          expectationMessage: expectationMessage ?? null,
          source,
        },
        select: {
          id: true,
          email: true,
          salutationName: true,
          salutation: true,
          status: true,
          updatedAt: true,
        },
      });

      res.json({
        message: DEFAULT_SUCCESS_MESSAGE,
        alreadyRegistered: true,
        registration: {
          ...updated,
          fullSalutation: buildFullSalutation(updated.salutationName, updated.salutation),
        },
      });
      return;
    }

    const created = await prisma.preRegistration.create({
      data: {
        email,
        salutationName,
        salutation,
        phoneCountryCode: phoneCountryCode ?? null,
        phoneNumber: phoneNumber ?? null,
        wechatId: wechatId ?? null,
        expectationMessage: expectationMessage ?? null,
        source,
      },
      select: {
        id: true,
        email: true,
        salutationName: true,
        salutation: true,
        status: true,
        createdAt: true,
      },
    });

    res.status(201).json({
      message: DEFAULT_SUCCESS_MESSAGE,
      alreadyRegistered: false,
      registration: {
        ...created,
        fullSalutation: buildFullSalutation(created.salutationName, created.salutation),
      },
    });
  } catch (error) {
    console.error('Create pre-registration error:', error);
    res.status(500).json({ error: '预登记提交失败，请稍后重试' });
  }
};

export const listPreRegistrations = async (req: Request, res: Response): Promise<void> => {
  try {
    const page = parsePositiveInt(req.query.page, 1);
    const limit = parsePositiveInt(req.query.limit, 20);
    const search = cleanText(req.query.search);
    const status = cleanText(req.query.status);
    const source = cleanText(req.query.source);
    const hasPhone = parseBooleanFlag(req.query.hasPhone);
    const hasWechat = parseBooleanFlag(req.query.hasWechat);

    const where: Prisma.PreRegistrationWhereInput = {};
    if (search) {
      Object.assign(where, buildPreRegistrationSearchWhere(search));
    }
    if (status) {
      where.status = status;
    }
    if (source) {
      where.source = source;
    }
    if (hasPhone === true) {
      where.phoneNumber = { not: null };
    } else if (hasPhone === false) {
      where.phoneNumber = null;
    }
    if (hasWechat === true) {
      where.wechatId = { not: null };
    } else if (hasWechat === false) {
      where.wechatId = null;
    }

    const [total, items] = await Promise.all([
      prisma.preRegistration.count({ where }),
      prisma.preRegistration.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    res.json({
      items: items.map((item) => ({
        ...item,
        fullSalutation: buildFullSalutation(item.salutationName, item.salutation),
      })),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      },
    });
  } catch (error) {
    console.error('List pre-registrations error:', error);
    res.status(500).json({ error: '获取预登记列表失败' });
  }
};

export const createPreRegistrationBatch = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const batchName = cleanText(req.body.batchName);
    const note = cleanText(req.body.note);
    const plannedSlotsValue = req.body.plannedSlots;

    if (!batchName) {
      res.status(400).json({ error: '批次名称不能为空' });
      return;
    }

    let plannedSlots: number | null = null;
    if (plannedSlotsValue !== undefined && plannedSlotsValue !== null && plannedSlotsValue !== '') {
      const parsed = parsePositiveInt(plannedSlotsValue, -1);
      if (parsed <= 0) {
        res.status(400).json({ error: '计划名额必须为正整数' });
        return;
      }
      plannedSlots = parsed;
    }

    const created = await prisma.preRegistrationBatch.create({
      data: {
        batchName,
        plannedSlots,
        note: note ?? null,
        createdBy: actorId,
      },
    });

    await prisma.adminAuditLog.create({
      data: {
        actorId,
        action: 'pre_registration.batch.create',
        targetType: 'pre_registration_batch',
        targetId: created.id,
        detail: {
          batchName: created.batchName,
          plannedSlots: created.plannedSlots,
        },
      },
    });

    res.status(201).json(created);
  } catch (error) {
    console.error('Create pre-registration batch error:', error);
    res.status(500).json({ error: '创建抽取批次失败' });
  }
};

export const listPreRegistrationBatches = async (_req: Request, res: Response): Promise<void> => {
  try {
    const batches = await prisma.preRegistrationBatch.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    const batchIds = batches.map((batch) => batch.id);
    const decisionCounts = batchIds.length
      ? await prisma.preRegistrationDecision.groupBy({
          by: ['batchId', 'decision'],
          where: { batchId: { in: batchIds } },
          _count: { _all: true },
        })
      : [];

    const statsMap = new Map<string, { total: number; selected: number; notSelected: number; waitlist: number }>();
    for (const row of decisionCounts) {
      const current = statsMap.get(row.batchId) || {
        total: 0,
        selected: 0,
        notSelected: 0,
        waitlist: 0,
      };
      current.total += row._count._all;
      if (row.decision === 'SELECTED') current.selected += row._count._all;
      if (row.decision === 'NOT_SELECTED') current.notSelected += row._count._all;
      if (row.decision === 'WAITLIST') current.waitlist += row._count._all;
      statsMap.set(row.batchId, current);
    }

    const items = batches.map((batch) => ({
      ...batch,
      stats: statsMap.get(batch.id) || {
        total: 0,
        selected: 0,
        notSelected: 0,
        waitlist: 0,
      },
    }));

    res.json({ items });
  } catch (error) {
    console.error('List pre-registration batches error:', error);
    res.status(500).json({ error: '获取抽取批次失败' });
  }
};

export const applyPreRegistrationDecisions = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const batchId = cleanText(req.params.batchId);
    const decision = cleanText(req.body.decision);
    const decisionReason = cleanText(req.body.decisionReason);
    const registrationIdsInput: unknown[] = Array.isArray(req.body.registrationIds) ? req.body.registrationIds : [];
    const registrationIds = Array.from(
      new Set<string>(
        registrationIdsInput
          .map((id) => cleanText(id))
          .filter((id): id is string => typeof id === 'string')
      )
    );

    if (!batchId) {
      res.status(400).json({ error: '批次 ID 不能为空' });
      return;
    }
    if (!decision || !DECISIONS.has(decision)) {
      res.status(400).json({ error: 'decision 必须是 SELECTED / NOT_SELECTED / WAITLIST' });
      return;
    }
    if (registrationIds.length === 0) {
      res.status(400).json({ error: 'registrationIds 不能为空' });
      return;
    }

    const batch = await prisma.preRegistrationBatch.findUnique({ where: { id: batchId } });
    if (!batch) {
      res.status(404).json({ error: '抽取批次不存在' });
      return;
    }

    const existingRegistrations = await prisma.preRegistration.findMany({
      where: { id: { in: registrationIds } },
      select: { id: true },
    });
    const existingIds = new Set(existingRegistrations.map((item) => item.id));
    const missingIds = registrationIds.filter((id) => !existingIds.has(id));
    if (missingIds.length > 0) {
      res.status(400).json({
        error: '部分登记记录不存在',
        missingRegistrationIds: missingIds,
      });
      return;
    }

    const operations: Prisma.PrismaPromise<unknown>[] = [];
    for (const registrationId of registrationIds) {
      operations.push(
        prisma.preRegistrationDecision.upsert({
          where: {
            batchId_registrationId: {
              batchId,
              registrationId,
            },
          },
          create: {
            batchId,
            registrationId,
            decision,
            decisionBy: actorId,
            decisionReason: decisionReason ?? null,
          },
          update: {
            decision,
            decisionBy: actorId,
            decisionReason: decisionReason ?? null,
          },
        })
      );
    }

    operations.push(
      prisma.preRegistration.updateMany({
        where: { id: { in: registrationIds } },
        data: { status: decision },
      })
    );

    operations.push(
      prisma.adminAuditLog.create({
        data: {
          actorId,
          action: 'pre_registration.batch.apply_decision',
          targetType: 'pre_registration_batch',
          targetId: batchId,
          detail: {
            decision,
            decisionReason: decisionReason ?? null,
            affectedCount: registrationIds.length,
            registrationIds,
          },
        },
      })
    );

    await prisma.$transaction(operations);

    res.json({
      message: '批次决策已更新',
      batchId,
      decision,
      affectedCount: registrationIds.length,
    });
  } catch (error) {
    console.error('Apply pre-registration decisions error:', error);
    res.status(500).json({ error: '更新抽取结果失败' });
  }
};

export const getPreRegistrationBatchResults = async (req: Request, res: Response): Promise<void> => {
  try {
    const batchId = cleanText(req.params.batchId);
    const page = parsePositiveInt(req.query.page, 1);
    const limit = parsePositiveInt(req.query.limit, 50);
    const decision = cleanText(req.query.decision);
    const search = cleanText(req.query.search);

    if (!batchId) {
      res.status(400).json({ error: '批次 ID 不能为空' });
      return;
    }

    const where: Prisma.PreRegistrationDecisionWhereInput = { batchId };
    if (decision) {
      where.decision = decision;
    }
    if (search) {
      where.registration = buildPreRegistrationSearchWhere(search);
    }

    const [total, items] = await Promise.all([
      prisma.preRegistrationDecision.count({ where }),
      prisma.preRegistrationDecision.findMany({
        where,
        include: {
          registration: {
            select: {
              id: true,
              email: true,
              phoneCountryCode: true,
              phoneNumber: true,
              wechatId: true,
              salutationName: true,
              salutation: true,
              status: true,
              createdAt: true,
            },
          },
        },
        orderBy: { updatedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    res.json({
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      },
    });
  } catch (error) {
    console.error('Get pre-registration batch results error:', error);
    res.status(500).json({ error: '获取批次结果失败' });
  }
};

export const createPreRegistrationNotifications = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorId = req.user?.userId;
    if (!actorId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const batchId = cleanText(req.body.batchId);
    const channel = cleanText(req.body.channel);
    const templateKey = cleanText(req.body.templateKey);
    const registrationIdsInput: unknown[] = Array.isArray(req.body.registrationIds) ? req.body.registrationIds : [];
    const registrationIds = Array.from(
      new Set<string>(
        registrationIdsInput
          .map((id) => cleanText(id))
          .filter((id): id is string => typeof id === 'string')
      )
    );

    if (!channel || !NOTIFICATION_CHANNELS.has(channel)) {
      res.status(400).json({ error: 'channel 必须是 EMAIL / SMS / WECHAT / IN_APP' });
      return;
    }
    if (!templateKey) {
      res.status(400).json({ error: 'templateKey 不能为空' });
      return;
    }
    if (registrationIds.length === 0) {
      res.status(400).json({ error: 'registrationIds 不能为空' });
      return;
    }

    if (batchId) {
      const batch = await prisma.preRegistrationBatch.findUnique({ where: { id: batchId } });
      if (!batch) {
        res.status(404).json({ error: '抽取批次不存在' });
        return;
      }
    }

    const existing = await prisma.preRegistration.findMany({
      where: { id: { in: registrationIds } },
      select: { id: true },
    });
    if (existing.length !== registrationIds.length) {
      const existingSet = new Set(existing.map((item) => item.id));
      const missing = registrationIds.filter((id) => !existingSet.has(id));
      res.status(400).json({ error: '部分登记记录不存在', missingRegistrationIds: missing });
      return;
    }

    const created = await prisma.preRegistrationNotification.createMany({
      data: registrationIds.map((registrationId) => ({
        registrationId,
        batchId: batchId ?? null,
        channel,
        templateKey,
        sendStatus: 'PENDING',
      })),
    });

    await prisma.adminAuditLog.create({
      data: {
        actorId,
        action: 'pre_registration.notification.enqueue',
        targetType: 'pre_registration_notification',
        targetId: batchId || 'manual',
        detail: {
          channel,
          templateKey,
          batchId: batchId ?? null,
          affectedCount: registrationIds.length,
        },
      },
    });

    res.status(201).json({
      message: '通知任务已创建',
      createdCount: created.count,
      channel,
      templateKey,
    });
  } catch (error) {
    console.error('Create pre-registration notifications error:', error);
    res.status(500).json({ error: '创建通知任务失败' });
  }
};
