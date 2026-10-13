import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { MonitoringService } from './monitoring.service';
import {
  CreateRelationshipDto,
  GenerateInviteCodeDto,
  AcceptInvitationDto,
  UpdateRelationshipDto,
  UpdateMonitoringConfigDto,
  PauseMonitoringDto,
} from './dto/monitoring.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('api/v1/monitoring')
@UseGuards(JwtAuthGuard)
export class MonitoringController {
  constructor(private readonly monitoringService: MonitoringService) {}

  @Post('relationships')
  async createRelationship(
    @CurrentUser() user: User,
    @Body() dto: CreateRelationshipDto,
  ) {
    return this.monitoringService.createRelationship(user.id, dto);
  }

  @Post('relationships/invite-code')
  @HttpCode(HttpStatus.CREATED)
  async generateInviteCode(
    @CurrentUser() user: User,
    @Body() dto: GenerateInviteCodeDto,
  ) {
    return this.monitoringService.generateInviteCode(user.id, dto);
  }

  @Post('relationships/accept')
  @HttpCode(HttpStatus.OK)
  async acceptInvitation(
    @CurrentUser() user: User,
    @Body() dto: AcceptInvitationDto,
  ) {
    return this.monitoringService.acceptInvitation(user.id, dto);
  }

  @Get('relationships')
  async listRelationships(@CurrentUser() user: User) {
    return this.monitoringService.listRelationships(user.id);
  }

  @Get('relationships/:id')
  async getRelationship(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ) {
    return this.monitoringService.getRelationship(user.id, id);
  }

  @Patch('relationships/:id')
  async updateRelationship(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: UpdateRelationshipDto,
  ) {
    return this.monitoringService.updateRelationshipStatus(user.id, id, dto.status);
  }

  @Get([':id/config', 'configs/:id'])
  async getConfig(@CurrentUser() user: User, @Param('id') id: string) {
    const { config } = await this.monitoringService.findConfigByRelOrConfigId(user.id, id);
    return config;
  }

  @Patch([':id/config', 'configs/:id'])
  async updateConfig(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: UpdateMonitoringConfigDto,
  ) {
    const { relationship } = await this.monitoringService.findConfigByRelOrConfigId(user.id, id);
    return this.monitoringService.updateConfig(user.id, relationship.id, dto);
  }

  @Post(['configs/:id/pause', ':id/pause'])
  @HttpCode(HttpStatus.OK)
  async pauseMonitoring(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto?: PauseMonitoringDto,
  ) {
    return this.monitoringService.pauseMonitoring(user.id, id, dto?.durationMinutes);
  }

  @Post(['configs/:id/resume', ':id/resume'])
  @HttpCode(HttpStatus.OK)
  async resumeMonitoring(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ) {
    return this.monitoringService.resumeMonitoring(user.id, id);
  }
}
