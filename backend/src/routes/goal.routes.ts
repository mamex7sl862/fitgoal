import { Router } from 'express';
import { getUserGoal, saveUserGoal } from '../controllers/goal.controller';
import { authenticateToken } from '../middleware/auth.middleware';

const router = Router();

router.get('/current', authenticateToken, getUserGoal);
router.post('/set-goal', authenticateToken, saveUserGoal);

export default router;