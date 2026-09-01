import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { trpcServer } from '@hono/trpc-server';

import { createServer, getServerPort } from '@devvit/web/server';
import { menu } from './routes/menu';
import { triggers } from './routes/triggers';
import { identity, state } from './routes/state';
import { appRouter } from './trpc';
import { createContext } from './context';

const app = new Hono();

const api = new Hono();
api.use(
  '/trpc/*',
  trpcServer({
    endpoint: '/api/trpc',
    router: appRouter,
    createContext,
  })
);
// Plain REST for the Flutter game client (persistence + identity only).
api.route('/state', state);
api.route('/identity', identity);

const internal = new Hono();
internal.route('/menu', menu);
internal.route('/triggers', triggers);

app.route('/api', api);
app.route('/internal', internal);

serve({
  fetch: app.fetch,
  createServer: createServer,
  port: getServerPort(),
});
