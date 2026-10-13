import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto, UpdateDeviceTokenDto } from './dto/device.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('api/v1/devices')
@UseGuards(JwtAuthGuard)
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Post()
  async register(
    @CurrentUser() user: User,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.devicesService.registerDevice(user.id, dto);
  }

  @Get()
  async list(@CurrentUser() user: User) {
    return this.devicesService.listDevices(user.id);
  }

  @Get(':id')
  async get(@CurrentUser() user: User, @Param('id') id: string) {
    return this.devicesService.getDevice(user.id, id);
  }

  @Post(':id/revoke')
  @HttpCode(HttpStatus.OK)
  async revoke(@CurrentUser() user: User, @Param('id') id: string) {
    return this.devicesService.revokeDevice(user.id, id);
  }

  @Patch(':id/push-token')
  async updatePushToken(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: UpdateDeviceTokenDto,
  ) {
    return this.devicesService.updatePushToken(user.id, id, dto.pushToken);
  }

  @Delete(':id')
  async remove(@CurrentUser() user: User, @Param('id') id: string) {
    return this.devicesService.deleteDevice(user.id, id);
  }
}
