import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

interface JwtPayload {
  userId: string;
  email: string;
  role?: string;
}

export interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}

export const authenticateToken = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Extracts "Bearer <TOKEN>"

  if (!token) {
    return res.status(401).json({ 
      code: 'UNAUTHORIZED', 
      message: 'Access token missing or malformed.' 
    });
  }

  const jwtSecret =
    process.env.ACCESS_TOKEN_SECRET || 'fitgoal_access_secret_2026';

  jwt.verify(token, jwtSecret, (err, decoded) => {
    if (err) {
      return res.status(403).json({ 
        code: 'FORBIDDEN', 
        message: 'Invalid or expired token.' 
      });
    }

    req.user = decoded as JwtPayload;
    next();
  });
};