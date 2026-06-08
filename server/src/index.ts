import 'dotenv/config';
import express from 'express';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { handleASRUpgrade } from './routes/asr';
import featureToggles from './routes/featureToggles';
import auth from './routes/auth';
import families from './routes/families';
import pointSystem from './routes/pointSystem';
import voiceParse from './routes/voiceParse';

const app = express();
const port = process.env.PORT ?? 3000;

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/auth', auth);
app.use('/families', families);
app.use('/families', pointSystem);
app.use('/config/feature-toggles', featureToggles);
app.use('/voice', voiceParse);

const server = createServer(app);
const wss = new WebSocketServer({ noServer: true });

server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url ?? '', 'http://localhost');
  if (url.pathname === '/asr/stream') {
    wss.handleUpgrade(req, socket, head, (ws) => {
      handleASRUpgrade(ws, req);
    });
  } else {
    socket.destroy();
  }
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
