import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async getProfile(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async updateProfile(
    userId: string,
    dto: {
      displayName?: string;
      phoneNumber?: string;
      timezone?: string;
      avatarUrl?: string;
      preferredLanguage?: string;
    },
  ) {
    const user = await this.getProfile(userId);
    if (dto.displayName !== undefined) user.displayName = dto.displayName.trim();
    if (dto.phoneNumber !== undefined) {
      const cleanPhone = dto.phoneNumber?.trim() || '';
      if (cleanPhone.length > 0) {
        const existing = await this.userRepository.findOne({
          where: { phoneNumber: cleanPhone },
        });
        if (existing && existing.id !== userId) {
          throw new ConflictException('Phone number already registered');
        }
      }
      user.phoneNumber = cleanPhone;
    }
    if (dto.timezone !== undefined) user.timezone = dto.timezone;
    if (dto.avatarUrl !== undefined) user.avatarUrl = dto.avatarUrl;
    if (dto.preferredLanguage !== undefined) {
      user.preferredLanguage = dto.preferredLanguage.trim().toLowerCase();
    }

    return this.userRepository.save(user);
  }

  async deleteAccount(userId: string) {
    const user = await this.getProfile(userId);
    await this.userRepository.softRemove(user);
    return { success: true, message: 'Account deleted successfully' };
  }
}
