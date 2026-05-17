import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import OSS from 'ali-oss';
import crypto from 'crypto';
import { hashPassword, comparePassword, generateToken } from '../utils/auth';
import { tencentIMUserService } from '../modules/im';
import { mediaAssetService } from '../services/media-asset.service';

const prisma = new PrismaClient();

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);
const ossUserAvatarsPrefix = (cleanEnv(process.env.OSS_USER_AVATARS_PREFIX) || 'users/avatars').replace(/^\/+|\/+$/g, '');

const ossClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

const normalizeDisplayName = (value: string | null | undefined): string => {
  return String(value || '').trim().replace(/\s+/g, ' ');
};

const normalizeDisplayNameForUniqueness = (value: string | null | undefined): string => {
  return normalizeDisplayName(value).toLocaleLowerCase('zh-Hans-CN');
};

const publicOssUrlForObjectKey = (objectKey: string): string => {
  if (!ossBucket || !ossRegion) {
    return `/${objectKey}`;
  }

  const endpointHost = ossEndpoint
    ? ossEndpoint.replace(/^https?:\/\//, '').replace(/^\/+|\/+$/g, '')
    : `${ossRegion}.aliyuncs.com`;
  const bucketHost = endpointHost.startsWith(`${ossBucket}.`) ? endpointHost : `${ossBucket}.${endpointHost}`;
  return `https://${bucketHost}/${objectKey}`;
};

const extensionForMimeType = (mimeType: string): string => {
  const normalized = mimeType.toLowerCase();
  if (normalized.includes('png')) return '.png';
  if (normalized.includes('webp')) return '.webp';
  if (normalized.includes('gif')) return '.gif';
  return '.jpg';
};

const uploadUserAvatarToOss = async (
  userId: string,
  file: Express.Multer.File
): Promise<{ assetId: string; url: string; objectKey: string }> => {
  if (!ossClient) {
    throw new Error('OSS is not configured. Require OSS_REGION/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET/OSS_BUCKET');
  }

  const ext = extensionForMimeType(file.mimetype);
  const objectKey = `${ossUserAvatarsPrefix}/${userId}/avatar-${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`;
  const result = await ossClient.put(objectKey, file.buffer, {
    headers: {
      'Content-Type': file.mimetype,
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
  const url = result.url || publicOssUrlForObjectKey(objectKey);
  const asset = await mediaAssetService.register({
    ownerType: 'user',
    ownerId: userId,
    purpose: 'avatar',
    provider: 'oss',
    objectKey,
    url,
    mimeType: file.mimetype,
    sizeBytes: file.size,
    uploadedById: userId,
    metadata: {
      originalName: file.originalname,
      source: 'api/auth/avatar',
    },
  });
  return {
    assetId: asset.id,
    url,
    objectKey,
  };
};

const syncTencentIMUserBestEffort = async (userId: string, reason: string): Promise<void> => {
  try {
    await tencentIMUserService.ensureUsersByIds([userId]);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[tencent-im] user sync skipped during ${reason}: ${message}`, { userId });
  }
};

export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, email, password, displayName } = req.body;
    const normalizedDisplayName = normalizeDisplayName(displayName);
    const displayNameKey = normalizeDisplayNameForUniqueness(normalizedDisplayName);

    if (!username || !email || !password || !normalizedDisplayName) {
      res.status(400).json({ error: 'Username, email, password, and displayName are required' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters' });
      return;
    }

    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [{ email }, { username }],
      },
    });

    if (existingUser) {
      res.status(409).json({ error: 'User already exists' });
      return;
    }

    const existingDisplayName = await prisma.user.findFirst({
      where: { displayNameNormalized: displayNameKey },
      select: { id: true },
    });

    if (existingDisplayName) {
      res.status(409).json({ error: '昵称已被使用' });
      return;
    }

    const passwordHash = await hashPassword(password);

    const user = await prisma.user.create({
      data: {
        username,
        email,
        passwordHash,
        displayName: normalizedDisplayName,
        displayNameNormalized: displayNameKey,
        displayNameStatus: 'pending',
      },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        createdAt: true,
      },
    });

    await prisma.userProfileModerationJob.create({
      data: {
        userId: user.id,
        targetType: 'display_name',
        targetValue: normalizedDisplayName,
        normalizedValue: displayNameKey,
        status: 'pending',
        provider: 'manual_review',
      },
    });

    const token = generateToken({
      userId: user.id,
      email: user.email,
      role: 'user',
    });

    await syncTencentIMUserBestEffort(user.id, 'auth-register');

    res.status(201).json({
      user,
      token,
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, identifier, password } = req.body as {
      email?: string;
      identifier?: string;
      password?: string;
    };
    const loginIdentifier = String(identifier || email || '').trim();

    if (!loginIdentifier || !password) {
      res.status(400).json({ error: 'Identifier and password are required' });
      return;
    }

    const user = await prisma.user.findFirst({
      where: {
        isActive: true,
        OR: [
          { email: { equals: loginIdentifier, mode: 'insensitive' } },
          { username: { equals: loginIdentifier, mode: 'insensitive' } },
          { displayNameNormalized: normalizeDisplayNameForUniqueness(loginIdentifier) },
        ],
      },
      orderBy: { createdAt: 'asc' },
    });

    if (!user) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const isPasswordValid = await comparePassword(password, user.passwordHash);

    if (!isPasswordValid) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    await syncTencentIMUserBestEffort(user.id, 'auth-login');

    const token = generateToken({
      userId: user.id,
      email: user.email,
      role: user.role,
    });

    res.json({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
      },
      token,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        favoriteDjIds: true,
        favoriteGenres: true,
        role: true,
        isVerified: true,
        createdAt: true,
      },
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(user);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getPublicProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({
      where: { id: id as string },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        favoriteDjIds: true,
        favoriteGenres: true,
        createdAt: true,
      },
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(user);
  } catch (error) {
    console.error('Get public profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const {
      displayName,
      bio,
      location,
      favoriteDjIds,
      favoriteGenres,
    } = req.body as {
      displayName?: string;
      bio?: string;
      location?: string;
      favoriteDjIds?: string[];
      favoriteGenres?: string[];
    };

    const data: {
      displayName?: string;
      displayNameNormalized?: string;
      displayNameStatus?: string;
      displayNameReviewNote?: string | null;
      bio?: string;
      location?: string;
      favoriteDjIds?: string[];
      favoriteGenres?: string[];
    } = {
      bio: bio ?? undefined,
      location: location ?? undefined,
      favoriteDjIds: Array.isArray(favoriteDjIds) ? favoriteDjIds : undefined,
      favoriteGenres: Array.isArray(favoriteGenres) ? favoriteGenres : undefined,
    };

    if (typeof displayName === 'string') {
      const trimmedDisplayName = normalizeDisplayName(displayName);
      if (!trimmedDisplayName) {
        res.status(400).json({ error: 'displayName cannot be empty' });
        return;
      }
      const displayNameKey = normalizeDisplayNameForUniqueness(trimmedDisplayName);
      const existingDisplayName = await prisma.user.findFirst({
        where: {
          displayNameNormalized: displayNameKey,
          id: { not: userId },
        },
        select: { id: true },
      });
      if (existingDisplayName) {
        res.status(409).json({ error: '昵称已被使用' });
        return;
      }
      data.displayName = trimmedDisplayName;
      data.displayNameNormalized = displayNameKey;
      data.displayNameStatus = 'pending';
      data.displayNameReviewNote = null;
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data,
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        favoriteDjIds: true,
        favoriteGenres: true,
        role: true,
        isVerified: true,
        createdAt: true,
      },
    });

    if (data.displayName && data.displayNameNormalized) {
      await prisma.userProfileModerationJob.create({
        data: {
          userId,
          targetType: 'display_name',
          targetValue: data.displayName,
          normalizedValue: data.displayNameNormalized,
          status: 'pending',
          provider: 'manual_review',
        },
      });
    }

    await syncTencentIMUserBestEffort(userId, 'auth-update-profile');

    res.json(updatedUser);
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const uploadAvatar = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const file = (req as Request & { file?: Express.Multer.File }).file;
    if (!file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }

    const previousUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { avatarUrl: true },
    });

    const upload = await uploadUserAvatarToOss(userId, file);
    const avatarUrl = upload.url;

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        avatarUrl,
        avatarStatus: 'pending',
        avatarReviewNote: null,
      },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        favoriteDjIds: true,
        favoriteGenres: true,
        role: true,
        isVerified: true,
        createdAt: true,
      },
    });

    if (previousUser?.avatarUrl && previousUser.avatarUrl !== avatarUrl) {
      await mediaAssetService.markReplacedByUrl(previousUser.avatarUrl);
    }

    await prisma.userProfileModerationJob.create({
      data: {
        userId,
        targetType: 'avatar',
        targetValue: avatarUrl,
        normalizedValue: upload.objectKey,
        status: 'pending',
        provider: 'manual_review',
      },
    });

    await syncTencentIMUserBestEffort(userId, 'auth-upload-avatar');

    res.status(201).json(updatedUser);
  } catch (error) {
    console.error('Upload avatar error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const searchUsers = async (req: Request, res: Response): Promise<void> => {
  try {
    const { q } = req.query;

    if (!q || typeof q !== 'string' || q.trim().length === 0) {
      res.status(400).json({ error: '请输入搜索关键词' });
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        OR: [
          { username: { contains: q.trim(), mode: 'insensitive' } },
          { displayName: { contains: q.trim(), mode: 'insensitive' } },
        ],
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
      take: 20,
    });

    res.json(users);
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Failed to search users' });
  }
};
