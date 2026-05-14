import { NextFunction, Response } from 'express';
import { AuthRequest } from '../../middleware/auth';
import type { JWTPayload } from '../../utils/auth';

export type AdminRole = 'admin' | 'operator';

export const ADMIN_ROLE = 'admin';
export const OPERATOR_ROLE = 'operator';

export const isAdmin = (user?: JWTPayload | null): boolean => {
  return user?.role === ADMIN_ROLE;
};

export const isAdminOrOperator = (user?: JWTPayload | null): boolean => {
  return user?.role === ADMIN_ROLE || user?.role === OPERATOR_ROLE;
};

export const requireAdmin = (req: AuthRequest, res: Response, next: NextFunction): void => {
  if (!req.user) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  if (!isAdmin(req.user)) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  next();
};

export const requireAdminOrOperator = (req: AuthRequest, res: Response, next: NextFunction): void => {
  if (!req.user) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  if (!isAdminOrOperator(req.user)) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  next();
};

export const guardAdminOrOperator = (req: AuthRequest, res: Response): boolean => {
  if (!req.user?.userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }

  if (!isAdminOrOperator(req.user)) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }

  return true;
};
