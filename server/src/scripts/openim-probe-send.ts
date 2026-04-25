import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { openIMConfig } from '../services/openim/openim-config';
import { openIMClient } from '../services/openim/openim-client';
import { toOpenIMGroupID, toOpenIMUserID } from '../services/openim/openim-id';
import { openIMUserService } from '../services/openim/openim-user.service';

type ProbeSessionType = 'single' | 'group';
type OpenIMSendMessageResponse = {
  serverMsgID?: string;
  serverMsgId?: string;
  clientMsgID?: string;
  clientMsgId?: string;
  messageID?: string;
  messageId?: string;
};

const prisma = new PrismaClient();
const OPENIM_CONTENT_TYPE_TEXT = 101;
const OPENIM_SESSION_TYPE_SINGLE = 1;
const OPENIM_SESSION_TYPE_GROUP = 3;

const sleep = (ms: number): Promise<void> => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

const readOptional = (name: string, fallback = ''): string => {
  const value = (process.env[name] || '').trim();
  return value || fallback;
};

const readInt = (name: string, fallback: number, min: number, max: number): number => {
  const raw = Number(process.env[name]);
  if (!Number.isFinite(raw)) {
    return fallback;
  }
  const normalized = Math.floor(raw);
  return Math.min(max, Math.max(min, normalized));
};

const resolveSessionType = (): ProbeSessionType => {
  const raw = readOptional('OPENIM_PROBE_SESSION_TYPE', 'single').toLowerCase();
  return raw === 'group' ? 'group' : 'single';
};

const resolveUser = async (label: string, identifier: string): Promise<{ id: string; username: string }> => {
  const normalized = identifier.trim();
  if (!normalized) {
    throw new Error(`Missing required ${label} identifier`);
  }

  const user = await prisma.user.findFirst({
    where: {
      isActive: true,
      OR: [
        { id: normalized },
        { username: { equals: normalized, mode: 'insensitive' } },
        { email: { equals: normalized, mode: 'insensitive' } },
      ],
    },
    select: {
      id: true,
      username: true,
    },
  });

  if (!user) {
    throw new Error(`Cannot resolve ${label} user by identifier: ${normalized}`);
  }

  return user;
};

const readMessageId = (response: OpenIMSendMessageResponse, fallback: string): string => {
  return (
    response.serverMsgID ||
    response.serverMsgId ||
    response.clientMsgID ||
    response.clientMsgId ||
    response.messageID ||
    response.messageId ||
    fallback
  );
};

const sendProbeMessage = async (params: {
  sourceId: string;
  content: string;
  senderUserId: string;
  receiverUserId?: string | null;
  groupId?: string | null;
  runId: string;
  seq: number;
  sessionType: ProbeSessionType;
}): Promise<string> => {
  const payload: Record<string, unknown> = {
    sendID: toOpenIMUserID(params.senderUserId),
    senderPlatformID: openIMConfig.platformId,
    contentType: OPENIM_CONTENT_TYPE_TEXT,
    content: { content: params.content },
    sessionType: params.sessionType === 'group' ? OPENIM_SESSION_TYPE_GROUP : OPENIM_SESSION_TYPE_SINGLE,
    isOnlineOnly: false,
    notOfflinePush: true,
    sendTime: Date.now(),
    clientMsgID: params.sourceId,
    ex: JSON.stringify({
      source: 'raver_openim_probe',
      runId: params.runId,
      seq: params.seq,
    }),
  };

  if (params.sessionType === 'group') {
    if (!params.groupId) {
      throw new Error('groupId is required for group probe message');
    }
    payload.groupID = toOpenIMGroupID(params.groupId);
  } else {
    if (!params.receiverUserId) {
      throw new Error('receiverUserId is required for single probe message');
    }
    payload.recvID = toOpenIMUserID(params.receiverUserId);
  }

  const response = await openIMClient.post<OpenIMSendMessageResponse>(openIMConfig.paths.sendMessage, {
    ...payload,
    operationID: openIMClient.createOperationId('probe-send-message'),
  });
  return readMessageId(response, params.sourceId);
};

const main = async (): Promise<void> => {
  if (!openIMConfig.enabled) {
    throw new Error('OPENIM_ENABLED is false. Enable OpenIM before running probe send script.');
  }

  const sessionType = resolveSessionType();
  const senderIdentifier = readOptional('OPENIM_PROBE_SENDER_IDENTIFIER');
  const receiverIdentifier = readOptional('OPENIM_PROBE_RECEIVER_IDENTIFIER');
  const groupId = readOptional('OPENIM_PROBE_GROUP_ID');
  const count = readInt('OPENIM_PROBE_MESSAGE_COUNT', 3, 1, 500);
  const intervalMs = readInt('OPENIM_PROBE_INTERVAL_MS', 800, 0, 60_000);
  const prefix = readOptional('OPENIM_PROBE_MESSAGE_PREFIX', '[openim-probe]');

  const sender = await resolveUser('sender', senderIdentifier);
  const receiver = sessionType === 'single' ? await resolveUser('receiver', receiverIdentifier) : null;
  if (sessionType === 'group' && !groupId) {
    throw new Error('OPENIM_PROBE_GROUP_ID is required when OPENIM_PROBE_SESSION_TYPE=group');
  }
  if (sessionType === 'single') {
    await openIMUserService.ensureUsersByIds([sender.id, receiver!.id]);
  } else {
    await openIMUserService.ensureUsersByIds([sender.id]);
  }

  const runId = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  console.log('[openim-probe-send] start', {
    sessionType,
    sender: sender.username,
    receiver: receiver?.username ?? null,
    groupId: groupId || null,
    count,
    intervalMs,
    runId,
  });

  const sentIds: string[] = [];
  for (let index = 0; index < count; index += 1) {
    const seq = index + 1;
    const content = `${prefix} ${seq}/${count} ${new Date().toISOString()}`;
    const sourceId = `probe_${runId}_${seq}`;
    const messageId = await sendProbeMessage({
      sourceId,
      sessionType,
      senderUserId: sender.id,
      receiverUserId: receiver?.id ?? null,
      groupId: groupId || null,
      content,
      runId,
      seq,
    });
    sentIds.push(messageId);
    console.log('[openim-probe-send] sent', {
      seq,
      sourceId,
      messageId,
      content,
    });
    if (intervalMs > 0 && seq < count) {
      await sleep(intervalMs);
    }
  }

  console.log('[openim-probe-send] done', {
    runId,
    sentCount: sentIds.length,
    firstMessageId: sentIds[0] || null,
    lastMessageId: sentIds[sentIds.length - 1] || null,
  });
};

main()
  .catch((error) => {
    console.error('[openim-probe-send] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
