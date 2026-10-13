import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Query,
} from '@nestjs/common';
import { ActivityService } from './activity.service';
import { IngestActivityDto, BatchIngestActivitiesDto } from './dto/activity.dto';
import { HeartbeatDto } from './dto/heartbeat.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('api/v1')
@UseGuards(JwtAuthGuard)
export class ActivitiesController {
  constructor(private readonly activityService: ActivityService) {}

  @Post(['heartbeat', 'activities/heartbeat'])
  @HttpCode(HttpStatus.OK)
  async heartbeat(
    @CurrentUser() user: User,
    @Body() dto: HeartbeatDto,
  ) {
    return this.activityService.processHeartbeat(user.id, dto);
  }

  @Post('activities')
  @HttpCode(HttpStatus.CREATED)
  async ingestActivity(
    @CurrentUser() user: User,
    @Body() dto: IngestActivityDto,
  ) {
    return this.activityService.ingestActivity(user.id, dto);
  }

  @Post('activities/batch')
  @HttpCode(HttpStatus.CREATED)
  async ingestBatch(
    @CurrentUser() user: User,
    @Body() dto: BatchIngestActivitiesDto,
  ) {
    return this.activityService.ingestBatch(user.id, dto.activities);
  }

  @Get('activities')
  async listMyActivities(
    @CurrentUser() user: User,
    @Query('limit') limit?: number,
  ) {
    return this.activityService.listRecentActivities(user.id, limit ? Number(limit) : 50);
  }
}
