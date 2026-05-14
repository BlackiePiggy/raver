import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export class PostInteractionNotFoundError extends Error {
  constructor(message = 'Post not found') {
    super(message);
    this.name = 'PostInteractionNotFoundError';
  }
}

export type PostInteractionPost = {
  id: string;
  userId: string;
  content: string;
};

export type PostShareInput = {
  channel?: unknown;
  status?: unknown;
};

export type PostHideInput = {
  reason?: unknown;
  note?: unknown;
};

const normalizeShareChannel = (input: unknown): string => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  const allowed = new Set(['system', 'copy_link', 'wechat', 'moments', 'other']);
  return allowed.has(value) ? value : 'system';
};

const normalizeShareStatus = (input: unknown): string => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  return value === 'intent' ? 'intent' : 'completed';
};

const normalizeHideReason = (input: unknown): string => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  const allowed = new Set(['not_relevant', 'seen_too_often', 'low_quality', 'author', 'other']);
  return allowed.has(value) ? value : 'not_relevant';
};

const normalizeHideNote = (input: unknown): string | null => {
  if (typeof input !== 'string') return null;
  const value = input.trim().slice(0, 500);
  return value || null;
};

export const fetchPostForInteraction = async (postId: string): Promise<PostInteractionPost> => {
  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { id: true, userId: true, content: true },
  });
  if (!post) {
    throw new PostInteractionNotFoundError();
  }
  return post;
};

export const likePost = async (
  postId: string,
  userId: string
): Promise<{ post: PostInteractionPost; createdLikeId: string | null }> => {
  const post = await fetchPostForInteraction(postId);
  let createdLikeId: string | null = null;

  await prisma.$transaction(async (tx) => {
    const existing = await tx.postLike.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (!existing) {
      const createdLike = await tx.postLike.create({
        data: {
          postId,
          userId,
        },
        select: { id: true },
      });
      createdLikeId = createdLike.id;

      await tx.post.update({
        where: { id: postId },
        data: { likeCount: { increment: 1 } },
      });
    }
  });

  return { post, createdLikeId };
};

export const unlikePost = async (postId: string, userId: string): Promise<void> => {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.postLike.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (existing) {
      await tx.postLike.delete({ where: { id: existing.id } });
      await tx.post.update({
        where: { id: postId },
        data: {
          likeCount: {
            decrement: 1,
          },
        },
      });
    }
  });
};

export const repostPost = async (postId: string, userId: string): Promise<void> => {
  await fetchPostForInteraction(postId);

  await prisma.$transaction(async (tx) => {
    const existing = await tx.postRepost.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (!existing) {
      await tx.postRepost.create({
        data: {
          postId,
          userId,
        },
      });
      await tx.post.update({
        where: { id: postId },
        data: {
          repostCount: {
            increment: 1,
          },
        },
      });
    }
  });
};

export const unrepostPost = async (postId: string, userId: string): Promise<void> => {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.postRepost.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (existing) {
      await tx.postRepost.delete({
        where: {
          id: existing.id,
        },
      });
      await tx.post.updateMany({
        where: {
          id: postId,
          repostCount: { gt: 0 },
        },
        data: {
          repostCount: {
            decrement: 1,
          },
        },
      });
    }
  });
};

export const savePost = async (postId: string, userId: string): Promise<void> => {
  await fetchPostForInteraction(postId);

  await prisma.$transaction(async (tx) => {
    const existing = await tx.postSave.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (!existing) {
      await tx.postSave.create({
        data: {
          postId,
          userId,
        },
      });
      await tx.post.update({
        where: { id: postId },
        data: { saveCount: { increment: 1 } },
      });
    }
  });
};

export const unsavePost = async (postId: string, userId: string): Promise<void> => {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.postSave.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (existing) {
      await tx.postSave.delete({ where: { id: existing.id } });
      await tx.post.updateMany({
        where: {
          id: postId,
          saveCount: { gt: 0 },
        },
        data: { saveCount: { decrement: 1 } },
      });
    }
  });
};

export const sharePost = async (
  postId: string,
  userId: string,
  input: PostShareInput
): Promise<void> => {
  await fetchPostForInteraction(postId);
  const channel = normalizeShareChannel(input.channel);
  const status = normalizeShareStatus(input.status);

  await prisma.$transaction(async (tx) => {
    await tx.postShare.create({
      data: {
        postId,
        userId,
        channel,
        status,
      },
    });

    if (status === 'completed') {
      await tx.post.update({
        where: { id: postId },
        data: { shareCount: { increment: 1 } },
      });
    }
  });
};

export const hidePost = async (
  postId: string,
  userId: string,
  input: PostHideInput
): Promise<void> => {
  await fetchPostForInteraction(postId);
  const reason = normalizeHideReason(input.reason);
  const note = normalizeHideNote(input.note);

  await prisma.$transaction(async (tx) => {
    const existing = await tx.postHide.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (existing) {
      await tx.postHide.update({
        where: { id: existing.id },
        data: { reason, note },
      });
    } else {
      await tx.postHide.create({
        data: {
          postId,
          userId,
          reason,
          note,
        },
      });
      await tx.post.update({
        where: { id: postId },
        data: { hideCount: { increment: 1 } },
      });
    }
  });
};

export const unhidePost = async (postId: string, userId: string): Promise<void> => {
  await prisma.$transaction(async (tx) => {
    const existing = await tx.postHide.findUnique({
      where: {
        postId_userId: {
          postId,
          userId,
        },
      },
    });

    if (existing) {
      await tx.postHide.delete({ where: { id: existing.id } });
      await tx.post.updateMany({
        where: {
          id: postId,
          hideCount: { gt: 0 },
        },
        data: { hideCount: { decrement: 1 } },
      });
    }
  });
};
