import 'dotenv/config';
import express from 'express';
import featureToggles from './routes/featureToggles';
import auth from './routes/auth';

const app = express();
const port = process.env.PORT ?? 3000;

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/auth', auth);
app.use('/config/feature-toggles', featureToggles);

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
