import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

interface CreateCommentInput {
  setId: string;
  userId: string;
  content: string;
  parentId?: string;
}

interface UpdateCommentInput {
  content: string;
}

export class CommentService {
  private readonly userSelect = {
    id: true,
    username: true,
    displayName: true,
    avatarUrl: true,
  } as const;

  /**
   * Get all comments for a DJ set
   */
  async getComments(setId: string) {
    // Get top-level comments (no parent)
    const comments = await prisma.comment.findMany({
      where: {
        setId,
        parentId: null,
      },
      include: {
        user: {
          select: this.userSelect,
        },
        replies: {
          include: {
            user: {
              select: this.userSelect,
            },
            replies: {
              include: {
                user: {
                  select: this.userSelect,
                },
              },
              orderBy: { createdAt: 'asc' },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return comments;
  }

  /**
   * Get comment count for a DJ set
   */
  async getCommentCount(setId: string) {
    const count = await prisma.comment.count({
      where: { setId },
    });
    return count;
  }

  /**
   * Create a new comment
   */
  async createComment(input: CreateCommentInput) {
    const { setId, userId, content, parentId } = input;

    // Validate content
    const trimmedContent = content.trim();
    if (!trimmedContent) {
      throw new Error('评论内容不能为空');
    }
    if (trimmedContent.length > 1000) {
      throw new Error('评论内容不能超过1000字符');
    }

    // Check if DJ set exists
    const djSet = await prisma.dJSet.findUnique({
      where: { id: setId },
      select: { id: true },
    });
    if (!djSet) {
      throw new Error('DJ Set not found');
    }

    // If parentId is provided, check if parent comment exists
    if (parentId) {
      const parentComment = await prisma.comment.findUnique({
        where: { id: parentId },
        select: { id: true, setId: true },
      });
      if (!parentComment) {
        throw new Error('Parent comment not found');
      }
      if (parentComment.setId !== setId) {
        throw new Error('Parent comment does not belong to this DJ set');
      }
    }

    // Create comment
    const comment = await prisma.comment.create({
      data: {
        setId,
        userId,
        content: trimmedContent,
        parentId,
      },
      include: {
        user: {
          select: this.userSelect,
        },
      },
    });

    return comment;
  }

  /**
   * Update a comment
   */
  async updateComment(commentId: string, userId: string, input: UpdateCommentInput) {
    const { content } = input;

    // Validate content
    const trimmedContent = content.trim();
    if (!trimmedContent) {
      throw new Error('评论内容不能为空');
    }
    if (trimmedContent.length > 1000) {
      throw new Error('评论内容不能超过1000字符');
    }

    // Check if comment exists and belongs to user
    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      select: { id: true, userId: true, createdAt: true },
    });

    if (!comment) {
      throw new Error('Comment not found');
    }

    if (comment.userId !== userId) {
      throw new Error('Forbidden');
    }

    // Check if comment is within edit time limit (5 minutes)
    const now = new Date();
    const createdAt = new Date(comment.createdAt);
    const diffMinutes = (now.getTime() - createdAt.getTime()) / 1000 / 60;
    if (diffMinutes > 5) {
      throw new Error('评论只能在发表后5分钟内编辑');
    }

    // Update comment
    const updated = await prisma.comment.update({
      where: { id: commentId },
      data: { content: trimmedContent },
      include: {
        user: {
          select: this.userSelect,
        },
      },
    });

    return updated;
  }

  /**
   * Delete a comment
   */
  async deleteComment(commentId: string, userId: string, role?: string) {
    // Check if comment exists
    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      select: { id: true, userId: true },
    });

    if (!comment) {
      throw new Error('Comment not found');
    }

    // Check permission (owner or admin)
    if (role !== 'admin' && comment.userId !== userId) {
      throw new Error('Forbidden');
    }

    // Delete comment (cascade will delete replies)
    await prisma.comment.delete({
      where: { id: commentId },
    });
  }

  /**
   * Get a single comment by ID
   */
  async getCommentById(commentId: string) {
    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      include: {
        user: {
          select: this.userSelect,
        },
      },
    });

    return comment;
  }
}

export default new CommentService();
