import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { LocationsService } from './locations.service';
import { IngestLocationDto } from './dto/location.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('api/v1/locations')
@UseGuards(JwtAuthGuard)
export class LocationsController {
  constructor(private readonly locationsService: LocationsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async recordLocation(
    @CurrentUser() user: User,
    @Body() dto: IngestLocationDto,
  ) {
    return this.locationsService.recordLocation(user.id, dto);
  }

  @Get('latest')
  async getLatestLocation(
    @CurrentUser() user: User,
    @Query('userId') targetUserId?: string,
  ) {
    const target = targetUserId || user.id;
    return this.locationsService.getLatestLocation(user.id, target);
  }
}
