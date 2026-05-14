import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const userSelect = {
  id: true,
  username: true,
  displayName: true,
  avatarUrl: true,
} as const;

export type PostCommentPost = {
  id: string;
  userId: string;
  content: string;
};

export type PostCommentWithUsers = Awaited<ReturnType<typeof fetchPostComments>>[number];

export class PostCommentNotFoundError extends Error {
  constructor(message = 'Post not found') {
    super(message);
    this.name = 'PostCommentNotFoundError';
  }
}

export class PostCommentValidationError extends Error {
  readonly status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = 'PostCommentValidationError';
    this.status = status;
  }
}

const normalizeParentCommentId = (body: {
  parentCommentID?: unknown;
  parentCommentId?: unknown;
  replyToCommentID?: unknown;
  replyToCommentId?: unknown;
}): string | null => {
  const rawParentID =
    body.parentCommentID ??
    body.parentCommentId ??
    body.replyToCommentID ??
    body.replyToCommentId;
  const parentCommentID = typeof rawParentID === 'string' ? rawParentID.trim() : '';
  return parentCommentID.length > 0 ? parentCommentID : null;
};

export const fetchPostComments = async (postId: string) => {
  return prisma.postComment.findMany({
    where: { postId },
    include: {
      user: {
        select: userSelect,
      },
      replyToUser: {
        select: userSelect,
      },
    },
    orderBy: { createdAt: 'asc' },
  });
};

export const createPostComment = async (
  postId: string,
  userId: string,
  body: {
    content?: unknown;
    parentCommentID?: unknown;
    parentCommentId?: unknown;
    replyToCommentID?: unknown;
    replyToCommentId?: unknown;
  }
): Promise<{ post: PostCommentPost; comment: PostCommentWithUsers }> => {
  const content = String(body.content || '').trim();
  const normalizedParentCommentID = normalizeParentCommentId(body);

  if (!content) {
    throw new PostCommentValidationError('content is required');
  }

  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { id: true, userId: true, content: true },
  });
  if (!post) {
    throw new PostCommentNotFoundError();
  }

  const comment = await prisma.$transaction(async (tx) => {
    let parentComment:
      | {
          id: string;
          postId: string;
          userId: string;
          rootCommentId: string | null;
          depth: number;
        }
      | null = null;

    if (normalizedParentCommentID) {
      parentComment = await tx.postComment.findUnique({
        where: { id: normalizedParentCommentID },
        select: {
          id: true,
          postId: true,
          userId: true,
          rootCommentId: true,
          depth: true,
        },
      });

      if (!parentComment || parentComment.postId !== postId) {
        throw new PostCommentValidationError('parentCommentID is invalid');
      }
    }

    const rootCommentId = parentComment ? parentComment.rootCommentId ?? parentComment.id : null;
    const depth = parentComment ? Math.min((parentComment.depth ?? 0) + 1, 2) : 0;
    const replyToUserId = parentComment?.userId ?? null;

    const created = await tx.postComment.create({
      data: {
        postId,
        userId,
        content,
        parentCommentId: parentComment?.id ?? null,
        rootCommentId,
        depth,
        replyToUserId,
      },
      include: {
        user: {
          select: userSelect,
        },
        replyToUser: {
          select: userSelect,
        },
      },
    });

    await tx.post.update({
      where: { id: postId },
      data: { commentCount: { increment: 1 } },
    });

    return created;
  });

  return { post, comment };
};
