import { openIMClient, OpenIMClientError } from './openim-client';
import { openIMConfig } from './openim-config';
import { toOpenIMGroupID, toOpenIMUserID } from './openim-id';
import { openIMUserService } from './openim-user.service';

type OpenIMSessionType = 'single' | 'group';

interface SendHistoricalMessageInput {
  sourceId: string;
  sessionType: OpenIMSessionType;
  senderUserId: string;
  receiverUserId?: string | null;
  groupId?: string | null;
  content: string;
  messageType?: string | null;
  imageUrl?: string | null;
  sendTime: Date;
}

interface OpenIMSendMessageResponse {
  serverMsgID?: string;
  serverMsgId?: string;
  clientMsgID?: string;
  clientMsgId?: string;
  messageID?: string;
  messageId?: string;
}

interface RevokeMessageInput {
  messageId: string;
  conversationId?: string | null;
  groupId?: string | null;
  userId?: string | null;
}

interface DeleteMessageInput {
  messageId: string;
  conversationId?: string | null;
  groupId?: string | null;
  userId?: string | null;
}

const OPENIM_CONTENT_TYPE_TEXT = 101;
const OPENIM_CONTENT_TYPE_IMAGE = 102;
const OPENIM_SESSION_TYPE_SINGLE = 1;
const OPENIM_SESSION_TYPE_GROUP = 3;

const normalize = (value: string | null | undefined): string | null => {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const tryPostWithFallback = async (
  primaryPath: string,
  fallbackPath: string,
  payload: Record<string, unknown>,
  operationPrefix: string
): Promise<void> => {
  const operationID = openIMClient.createOperationId(operationPrefix);
  try {
    await openIMClient.post(primaryPath, {
      ...payload,
      operationID,
    });
  } catch (error) {
    const canFallback =
      error instanceof OpenIMClientError &&
      error.status === 404 &&
      fallbackPath !== primaryPath;

    if (!canFallback) {
      throw error;
    }

    await openIMClient.post(fallbackPath, {
      ...payload,
      operationID,
    });
  }
};

const normalizeMessageType = (value: string | null | undefined): string => {
  const normalized = normalize(value)?.toLowerCase();
  return normalized || 'text';
};

const buildMessageContent = (
  type: string,
  content: string,
  imageUrl: string | null
): { contentType: number; content: Record<string, unknown> } => {
  if (type === 'image' && imageUrl) {
    const picture = {
      uuid: imageUrl,
      type: 'image',
      url: imageUrl,
      size: 0,
      width: 0,
      height: 0,
    };
    return {
      contentType: OPENIM_CONTENT_TYPE_IMAGE,
      content: {
        sourcePicture: picture,
        bigPicture: picture,
        snapshotPicture: picture,
      },
    };
  }

  return {
    contentType: OPENIM_CONTENT_TYPE_TEXT,
    content: {
      content,
    },
  };
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

export const openIMMessageService = {
  async sendHistoricalMessage(input: SendHistoricalMessageInput): Promise<string> {
    if (!openIMConfig.enabled) {
      throw new Error('OpenIM is disabled');
    }

    const sourceId = normalize(input.sourceId);
    const senderUserId = normalize(input.senderUserId);
    if (!sourceId || !senderUserId) {
      throw new Error('sourceId and senderUserId are required for historical message migration');
    }

    const messageType = normalizeMessageType(input.messageType);
    const content = input.content || '';
    const imageUrl = normalize(input.imageUrl);
    const contentPayload = buildMessageContent(messageType, content, imageUrl);
    const clientMsgID = `raver_migration_${sourceId.replace(/[^a-zA-Z0-9_]/g, '')}`;

    const payload: Record<string, unknown> = {
      sendID: toOpenIMUserID(senderUserId),
      senderPlatformID: openIMConfig.platformId,
      content: contentPayload.content,
      contentType: contentPayload.contentType,
      sessionType: input.sessionType === 'group' ? OPENIM_SESSION_TYPE_GROUP : OPENIM_SESSION_TYPE_SINGLE,
      isOnlineOnly: false,
      notOfflinePush: true,
      sendTime: input.sendTime.getTime(),
      clientMsgID,
      ex: JSON.stringify({
        source: 'raver_openim_migration',
        sourceId,
        sourceMessageType: messageType,
      }),
    };

    if (input.sessionType === 'group') {
      const groupId = normalize(input.groupId);
      if (!groupId) {
        throw new Error('groupId is required for historical group message migration');
      }
      await openIMUserService.ensureUsersByIds([senderUserId]);
      payload.groupID = toOpenIMGroupID(groupId);
    } else {
      const receiverUserId = normalize(input.receiverUserId);
      if (!receiverUserId) {
        throw new Error('receiverUserId is required for historical direct message migration');
      }
      await openIMUserService.ensureUsersByIds([senderUserId, receiverUserId]);
      payload.recvID = toOpenIMUserID(receiverUserId);
    }

    const response = await openIMClient.post<OpenIMSendMessageResponse>(
      openIMConfig.paths.sendMessage,
      {
        ...payload,
        operationID: openIMClient.createOperationId('migration-send-message'),
      }
    );

    return readMessageId(response, clientMsgID);
  },

  async revokeMessage(input: RevokeMessageInput): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const messageId = normalize(input.messageId);
    if (!messageId) {
      throw new Error('messageId is required for revoke');
    }

    const payload: Record<string, unknown> = {
      messageID: messageId,
    };

    const conversationID = normalize(input.conversationId);
    const groupID = normalize(input.groupId);
    const userID = normalize(input.userId);

    if (conversationID) payload.conversationID = conversationID;
    if (groupID) payload.groupID = groupID;
    if (userID) payload.userID = userID;

    await tryPostWithFallback(
      openIMConfig.paths.revokeMessage,
      '/msg/revoke_msg',
      payload,
      'revoke-message'
    );
  },

  async deleteMessage(input: DeleteMessageInput): Promise<void> {
    if (!openIMConfig.enabled) {
      return;
    }

    const messageId = normalize(input.messageId);
    if (!messageId) {
      throw new Error('messageId is required for delete');
    }

    const payload: Record<string, unknown> = {
      messageIDs: [messageId],
    };

    const conversationID = normalize(input.conversationId);
    const groupID = normalize(input.groupId);
    const userID = normalize(input.userId);

    if (conversationID) payload.conversationID = conversationID;
    if (groupID) payload.groupID = groupID;
    if (userID) payload.userID = userID;

    await tryPostWithFallback(
      openIMConfig.paths.deleteMessage,
      '/msg/delete_msg',
      payload,
      'delete-message'
    );
  },
};
