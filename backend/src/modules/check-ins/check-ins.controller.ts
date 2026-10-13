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
import { CheckInsService } from './check-ins.service';
import { CreateCheckInDto } from './dto/check-in.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('api/v1/check-ins')
@UseGuards(JwtAuthGuard)
export class CheckInsController {
  constructor(private readonly checkInsService: CheckInsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async checkIn(
    @CurrentUser() user: User,
    @Body() dto: CreateCheckInDto,
  ) {
    return this.checkInsService.processCheckIn(user.id, dto, user.displayName);
  }

  @Get()
  async listCheckIns(
    @CurrentUser() user: User,
    @Query('limit') limit?: number,
  ) {
    return this.checkInsService.listCheckIns(user.id, limit ? Number(limit) : 20);
  }
}
