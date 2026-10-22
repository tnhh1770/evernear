import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { IncidentsService } from './incidents.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { IncidentStatus } from '../../common/enums';

@Controller('api/v1/incidents')
@UseGuards(JwtAuthGuard)
export class IncidentsController {
  constructor(private readonly incidentsService: IncidentsService) {}

  @Get()
  async list(
    @CurrentUser() user: User,
    @Query('status') status?: IncidentStatus,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.incidentsService.listIncidents(user.id, status, limit, offset);
  }

  @Get(':id')
  async get(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ) {
    return this.incidentsService.getIncident(user.id, id);
  }

  @Post(':id/acknowledge')
  @HttpCode(HttpStatus.OK)
  async acknowledge(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ) {
    return this.incidentsService.acknowledgeIncident(user.id, id);
  }

  @Post(':id/resolve')
  @HttpCode(HttpStatus.OK)
  async resolve(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body('note') note?: string,
  ) {
    return this.incidentsService.resolveIncident(user.id, id, note);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  async deleteIncident(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ) {
    return this.incidentsService.deleteIncident(user.id, id);
  }

  @Delete()
  @HttpCode(HttpStatus.OK)
  async clearAllIncidents(
    @CurrentUser() user: User,
  ) {
    return this.incidentsService.clearAllIncidents(user.id);
  }
}
