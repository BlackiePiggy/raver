import { Router } from 'express';
import multer from 'multer';
import { register, login, getProfile, getPublicProfile, updateProfile, uploadAvatar, searchUsers } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth';

const router: Router = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'));
      return;
    }
    cb(null, true);
  },
});

router.post('/register', register);
router.post('/login', login);
router.get('/users/search', searchUsers);
router.get('/users/:id', getPublicProfile);
router.get('/profile', authenticate, getProfile);
router.put('/profile', authenticate, updateProfile);
router.post('/avatar', authenticate, upload.single('avatar'), uploadAvatar);

export default router;
