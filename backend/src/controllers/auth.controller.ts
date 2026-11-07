import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { AuthenticatedRequest } from '../middleware/auth.middleware';

const prisma = new PrismaClient();

const ACCESS_TOKEN_SECRET = process.env.ACCESS_TOKEN_SECRET || 'fitgoal_access_secret_2026';
const REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET || 'fitgoal_refresh_secret_2026';

// Helper to generate tokens
function generateTokens(userId: string, role: string) {
  const accessToken = jwt.sign({ userId, role }, ACCESS_TOKEN_SECRET, { expiresIn: '15m' });
  const refreshToken = jwt.sign({ userId, role }, REFRESH_TOKEN_SECRET, { expiresIn: '30d' });
  return { accessToken, refreshToken };
}

// 1. SIGN UP
export async function signup(req: Request, res: Response): Promise<void> {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      res.status(400).json({ code: 'BAD_REQUEST', message: 'Email and password are required.' });
      return;
    }

    // Check if user exists
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      res.status(409).json({ code: 'CONFLICT', message: 'User with this email already exists.' });
      return;
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);

    // Create User and Profile in a single database transaction
    const newUser = await prisma.user.create({
      data: {
        email,
        passwordHash,
        profile: {
          create: {
            displayName: displayName || email.split('@')[0],
          },
        },
      },
    });

    const tokens = generateTokens(newUser.id, newUser.role);

    res.status(201).json({
      message: 'User registered successfully',
      userId: newUser.id,
      ...tokens,
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ code: 'SERVER_ERROR', message: 'Internal server error during signup.' });
  }
}

// 2. LOGIN
export async function login(req: Request, res: Response): Promise<void> {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ code: 'BAD_REQUEST', message: 'Email and password are required.' });
      return;
    }

    // Find user
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      res.status(401).json({ code: 'UNAUTHORIZED', message: 'Invalid email or password.' });
      return;
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      res.status(401).json({ code: 'UNAUTHORIZED', message: 'Invalid email or password.' });
      return;
    }

    const tokens = generateTokens(user.id, user.role);

    res.status(200).json({
      message: 'Login successful',
      userId: user.id,
      ...tokens,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ code: 'SERVER_ERROR', message: 'Internal server error during login.' });
  }
}

export async function refreshAccessToken(
  req: Request,
  res: Response,
): Promise<void> {
  const { refreshToken } = req.body ?? {};
  if (typeof refreshToken !== 'string' || refreshToken.length === 0) {
    res.status(401).json({
      code: 'UNAUTHORIZED',
      message: 'A valid refresh token is required.',
    });
    return;
  }

  try {
    const decoded = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);
    if (
      typeof decoded === 'string' ||
      typeof decoded.userId !== 'string' ||
      typeof decoded.role !== 'string'
    ) {
      res.status(401).json({
        code: 'UNAUTHORIZED',
        message: 'The refresh token is invalid or expired.',
      });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: { id: true, role: true },
    });
    if (!user || user.role !== decoded.role) {
      res.status(401).json({
        code: 'UNAUTHORIZED',
        message: 'The refresh token is invalid or expired.',
      });
      return;
    }

    res.status(200).json({
      accessToken: jwt.sign(
        { userId: user.id, role: user.role },
        ACCESS_TOKEN_SECRET,
        { expiresIn: '15m' },
      ),
    });
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      res.status(401).json({
        code: 'UNAUTHORIZED',
        message: 'The refresh token is invalid or expired.',
      });
      return;
    }
    console.error('Access token refresh error:', error);
    res.status(500).json({
      code: 'SERVER_ERROR',
      message: 'Unable to refresh the access token.',
    });
  }
}

export async function changePassword(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const { currentPassword, newPassword } = req.body ?? {};
  const userId = req.user?.userId;

  if (
    typeof currentPassword !== 'string' ||
    typeof newPassword !== 'string' ||
    currentPassword.length === 0 ||
    newPassword.length < 8
  ) {
    res.status(400).json({
      code: 'BAD_REQUEST',
      message: 'A current password and a new password of at least 8 characters are required.',
    });
    return;
  }

  if (!userId) {
    res.status(401).json({
      code: 'UNAUTHORIZED',
      message: 'Please sign in again to change your password.',
    });
    return;
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true },
    });
    if (!user || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
      res.status(400).json({
        code: 'INVALID_PASSWORD',
        message: 'Your current password is incorrect.',
      });
      return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });

    res.status(200).json({ message: 'Password changed successfully.' });
  } catch (error) {
    console.error('Password change error:', error);
    res.status(500).json({
      code: 'SERVER_ERROR',
      message: 'Unable to change the password right now.',
    });
  }
}