import {
  Controller,
  Get,
  UseGuards,
  Request,
  Sse,
  MessageEvent,
} from '@nestjs/common';
import { Observable, Subject } from 'rxjs';
import { RealtimeService } from './realtime.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('realtime')
export class RealtimeController {
  private readonly sseSubjects = new Map<string, Subject<MessageEvent>>();

  constructor(private readonly realtimeService: RealtimeService) {}

  @Get('health')
  getHealth() {
    return {
      status: 'UP',
      transport: 'WebSocket + SSE',
      path: '/ws',
      connectedUsers: this.realtimeService.getConnectedUserCount(),
      activeSockets: this.realtimeService.getActiveSocketCount(),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Sse('stream')
  streamEvents(@Request() req: any): Observable<MessageEvent> {
    const userId = req.user.id;
    if (!this.sseSubjects.has(userId)) {
      this.sseSubjects.set(userId, new Subject<MessageEvent>());
    }

    const subject = this.sseSubjects.get(userId)!;
    // Initial welcome packet
    setTimeout(() => {
      subject.next({
        data: {
          type: 'CONNECTED',
          transport: 'SSE',
          userId,
          timestamp: new Date().toISOString(),
        },
      });
    }, 100);

    return subject.asObservable();
  }
}
