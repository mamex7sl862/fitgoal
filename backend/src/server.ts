import dotenv from 'dotenv';
dotenv.config();

import express, { Request, Response } from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.routes';
import accountRoutes from './routes/account.routes';
import goalRoutes from './routes/goal.routes';
import loggerRoutes from './routes/logger.routes';
import mealPlanRoutes from './routes/meal_plan.routes';
import workoutRoutes from './routes/workout.routes';
import workoutSessionRoutes from './routes/workout_session.routes';
import exerciseRoutes from './routes/exercise.routes';
import animatedExerciseRoutes from './routes/animated_exercise.routes';
// ... rest of your code

// ... other middleware


const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use('/api/goals', goalRoutes);
app.use('/api/logger', loggerRoutes);
app.use('/api/meals', mealPlanRoutes);
app.use('/api/workouts', workoutRoutes);
app.use('/api/workouts', workoutSessionRoutes);
app.use('/api/exercises', exerciseRoutes);
app.use('/api/animated-exercises', animatedExerciseRoutes);
// Register Auth Routes
app.use('/api/auth', authRoutes);
app.use('/api/account', accountRoutes);

// Health Check Route
app.get('/api/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', message: 'FitGoal Smart Coach API is running!' });
});

app.listen(PORT, () => {
  console.log(`🚀 FitGoal Backend listening on http://localhost:${PORT}`);
});