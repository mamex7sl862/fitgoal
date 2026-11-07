import { Router } from 'express';
import {
  login,
  refreshAccessToken,
  signup,
} from '../controllers/auth.controller';

const router = Router();

router.post('/signup', signup);
router.post('/login', login);
router.post('/refresh', refreshAccessToken);

export default router;