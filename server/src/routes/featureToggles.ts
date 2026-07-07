import { Router } from 'express';

const router = Router();

// Returns active feature toggles. Empty object = all toggles off.
// Replace with DB-backed values when flags are introduced.
router.get('/', (_req, res) => {
  res.json({
    familyTodo:     true,
    familyNotes:    false,
    orderFromMe:    false,
    familyInviteQR: true,
  });
});

export default router;
