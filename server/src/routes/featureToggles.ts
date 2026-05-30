import { Router } from 'express';

const router = Router();

// Returns active feature toggles. Empty object = all toggles off.
// Replace with DB-backed values when flags are introduced.
router.get('/', (_req, res) => {
  res.json({
  });
});

export default router;
