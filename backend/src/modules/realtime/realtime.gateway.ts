import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
} from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { WebSocketServer, WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import { parse } from 'url';
import { RealtimeService } from './realtime.service';

interface AuthenticatedWebSocket extends WebSocket {
  isAlive?: boolean;
  userId?: string;
}

@Injectable()
export class RealtimeGateway implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(RealtimeGateway.name);
  private wss: WebSocketServer | null = null;
  private pingInterval: NodeJS.Timeout | null = null;

  constructor(
    private readonly adapterHost: HttpAdapterHost,
    private readonly jwtService: JwtService,
    private readonly realtimeService: RealtimeService,
  ) {}

  onApplicationBootstrap() {
    try {
      const server = this.adapterHost.httpAdapter?.getHttpServer();
      if (!server) {
        this.logger.warn('HTTP server instance not available. WebSocket server skipped.');
        return;
      }

      this.wss = new WebSocketServer({ noServer: true });

      server.on('upgrade', (request: IncomingMessage, socket: any, head: Buffer) => {
        const { pathname, query } = parse(request.url || '', true);

        if (pathname === '/ws') {
          // Extract JWT token from query string (?token=...) or Authorization header
          let token = typeof query.token === 'string' ? query.token : undefined;

          if (!token && request.headers.authorization) {
            const parts = request.headers.authorization.split(' ');
            if (parts.length === 2 && parts[0] === 'Bearer') {
              token = parts[1];
            }
          }

          if (!token) {
            socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
            socket.destroy();
            return;
          }

          try {
            const payload = this.jwtService.verify(token);
            const userId = payload.sub || payload.userId || payload.id;
            if (!userId) {
              throw new Error('Token payload missing user ID');
            }

            this.wss!.handleUpgrade(request, socket, head, (ws) => {
              this.wss!.emit('connection', ws, request, userId);
            });
          } catch (err: any) {
            this.logger.warn(`WebSocket upgrade unauthorized: ${err.message}`);
            socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
            socket.destroy();
          }
        }
      });

      this.wss.on('connection', (ws: AuthenticatedWebSocket, request: IncomingMessage, userId: string) => {
        ws.isAlive = true;
        ws.userId = userId;

        this.realtimeService.registerClient(userId, ws);

        ws.on('pong', () => {
          ws.isAlive = true;
        });

        ws.on('message', (data: any) => {
          // Echo ping if client sends text ping
          try {
            const msg = data.toString();
            if (msg === 'ping') {
              ws.send('pong');
            }
          } catch {
            // Ignore
          }
        });

        ws.on('close', () => {
          this.realtimeService.removeClient(userId, ws);
        });

        ws.on('error', (err) => {
          this.logger.warn(`WebSocket client error for user ${userId}: ${err.message}`);
          this.realtimeService.removeClient(userId, ws);
        });
      });

      // Liveness probe every 30s to prune stale connections
      this.pingInterval = setInterval(() => {
        if (!this.wss) return;
        this.wss.clients.forEach((client: AuthenticatedWebSocket) => {
          if (client.isAlive === false) {
            if (client.userId) {
              this.realtimeService.removeClient(client.userId, client);
            }
            return client.terminate();
          }
          client.isAlive = false;
          client.ping();
        });
      }, 30000);

      this.logger.log('Carely Realtime Gateway initialized on path /ws');
    } catch (e: any) {
      this.logger.error(`Failed to initialize Realtime Gateway: ${e.message}`, e.stack);
    }
  }

  onModuleDestroy() {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }

    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }
  }
}
