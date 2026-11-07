import { Router } from 'express';
import { changePassword } from '../controllers/auth.controller';
import { authenticateToken } from '../middleware/auth.middleware';

const router = Router();

router.post('/change-password', authenticateToken, changePassword);

export default router;
