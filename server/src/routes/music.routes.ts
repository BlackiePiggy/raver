import { Router, Request, Response } from 'express';
import type { IRouter } from 'express';
import musicSearchService from '../services/music-search.service';

const router: IRouter = Router();

/**
 * GET /api/music/spotify/auth-status
 * 获取Spotify鉴权状态
 */
router.get('/spotify/auth-status', async (_req: Request, res: Response): Promise<void> => {
  try {
    const status = await musicSearchService.getSpotifyAuthStatus();
    res.json({
      ...status,
      authUrl: 'https://developer.spotify.com/dashboard',
    });
  } catch (error) {
    console.error('Spotify auth status error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/music/netease/search
 * 搜索网易云音乐
 */
router.get('/netease/search', async (req: Request, res: Response): Promise<void> => {
  try {
    const { keyword } = req.query;

    if (!keyword || typeof keyword !== 'string') {
      res.status(400).json({ error: 'Keyword is required' });
      return;
    }

    const results = await musicSearchService.searchNetease(keyword);
    res.json({ songs: results });
  } catch (error) {
    console.error('Netease search error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

/**
 * GET /api/music/spotify/search
 * 搜索Spotify
 */
router.get('/spotify/search', async (req: Request, res: Response): Promise<void> => {
  try {
    const { keyword } = req.query;

    if (!keyword || typeof keyword !== 'string') {
      res.status(400).json({ error: 'Keyword is required' });
      return;
    }

    const results = await musicSearchService.searchSpotify(keyword);
    res.json({ tracks: results });
  } catch (error) {
    console.error('Spotify search error:', error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export default router;
