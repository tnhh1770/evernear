import {
  Controller,
  Get,
  Patch,
  Delete,
  Body,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from './entities/user.entity';

@Controller('api/v1/users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async getMe(@CurrentUser() user: User) {
    return this.usersService.getProfile(user.id);
  }

  @Patch('me')
  async updateMe(
    @CurrentUser() user: User,
    @Body()
    dto: {
      displayName?: string;
      phoneNumber?: string;
      timezone?: string;
      avatarUrl?: string;
      preferredLanguage?: string;
    },
  ) {
    return this.usersService.updateProfile(user.id, dto);
  }

  @Delete('me')
  async deleteMe(@CurrentUser() user: User) {
    return this.usersService.deleteAccount(user.id);
  }
}
