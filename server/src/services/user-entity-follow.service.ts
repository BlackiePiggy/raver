import { Prisma } from '@prisma/client';

export const USER_ENTITY_RELATION_FOLLOW = 'follow';
export const USER_ENTITY_RELATION_FAVORITE = 'favorite';

export const USER_ENTITY_TARGET_USER = 'user';
export const USER_ENTITY_TARGET_DJ = 'dj';
export const USER_ENTITY_TARGET_EVENT = 'event';

export const userEntityFollowWhere = (
  userId: string,
  relationType: string,
  targetType: string,
  targetId: string
) => ({
  userId_relationType_targetType_targetId: {
    userId,
    relationType,
    targetType,
    targetId,
  },
});

export const upsertUserEntityRelation = async (
  tx: Prisma.TransactionClient,
  params: {
    userId: string;
    relationType: string;
    targetType: string;
    targetId: string;
  }
) =>
  tx.userEntityFollow.upsert({
    where: userEntityFollowWhere(params.userId, params.relationType, params.targetType, params.targetId),
    create: params,
    update: {},
  });

export const deleteUserEntityRelation = async (
  tx: Prisma.TransactionClient,
  params: {
    userId: string;
    relationType: string;
    targetType: string;
    targetId: string;
  }
) =>
  tx.userEntityFollow.deleteMany({
    where: params,
  });
