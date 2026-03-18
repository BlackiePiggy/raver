import { Router, Request, Response } from 'express';
import type { IRouter } from 'express';
import commentService from '../services/comment.service';
import { authenticate, AuthRequest } from '../middleware/auth';

const router: IRouter = Router();

/**
 * GET /api/dj-sets/:setId/comments
 * Get all comments for a DJ set
 */
router.get('/:setId/comments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { setId } = req.params;
    const comments = await commentService.getComments(setId as string);
    res.json(comments);
  } catch (error) {
    console.error('Get comments error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/dj-sets/:setId/comments/count
 * Get comment count for a DJ set
 */
router.get('/:setId/comments/count', async (req: Request, res: Response): Promise<void> => {
  try {
    const { setId } = req.params;
    const count = await commentService.getCommentCount(setId as string);
    res.json({ count });
  } catch (error) {
    console.error('Get comment count error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * POST /api/dj-sets/:setId/comments
 * Create a new comment
 */
router.post('/:setId/comments', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { setId } = req.params;
    const { content, parentId } = req.body;

    if (!content) {
      res.status(400).json({ error: 'Content is required' });
      return;
    }

    const comment = await commentService.createComment({
      setId: setId as string,
      userId,
      content,
      parentId,
    });

    res.status(201).json(comment);
  } catch (error) {
    console.error('Create comment error:', error);
    const message = (error as Error).message;
    if (message === 'DJ Set not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message.includes('Parent comment')) {
      res.status(400).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

/**
 * PUT /api/comments/:id
 * Update a comment
 */
router.put('/comments/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const { content } = req.body;

    if (!content) {
      res.status(400).json({ error: 'Content is required' });
      return;
    }

    const comment = await commentService.updateComment(id as string, userId, { content });
    res.json(comment);
  } catch (error) {
    console.error('Update comment error:', error);
    const message = (error as Error).message;
    if (message === 'Comment not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Forbidden') {
      res.status(403).json({ error: '你只能编辑自己的评论' });
      return;
    }
    if (message.includes('5分钟')) {
      res.status(400).json({ error: message });
      return;
    }
    res.status(500).json({ error: message });
  }
});

/**
 * DELETE /api/comments/:id
 * Delete a comment
 */
router.delete('/comments/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    await commentService.deleteComment(id as string, userId, role);
    res.status(204).send();
  } catch (error) {
    console.error('Delete comment error:', error);
    const message = (error as Error).message;
    if (message === 'Comment not found') {
      res.status(404).json({ error: message });
      return;
    }
    if (message === 'Forbidden') {
      res.status(403).json({ error: '你只能删除自己的评论' });
      return;
    }
    res.status(500).json({ error: message });
  }
});

export default router;
