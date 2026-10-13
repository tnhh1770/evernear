import { describe, it, expect, vi, beforeEach } from 'vitest';
import { UsersService } from './users.service';
import { ConflictException, NotFoundException } from '@nestjs/common';

describe('UsersService (Unit Tests)', () => {
  let usersService: UsersService;
  let userRepo: any;

  beforeEach(() => {
    userRepo = {
      findOne: vi.fn(),
      save: vi.fn((entity) => Promise.resolve(entity)),
      softRemove: vi.fn((entity) => Promise.resolve(entity)),
    };
    usersService = new UsersService(userRepo);
  });

  describe('updateProfile', () => {
    it('should throw NotFoundException if user does not exist', async () => {
      userRepo.findOne.mockResolvedValueOnce(null);

      await expect(
        usersService.updateProfile('non-existent-id', { displayName: 'John' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ConflictException if phone number is already registered by another user', async () => {
      const currentUser = { id: 'user-1', displayName: 'Current User', phoneNumber: '+84900000001' };
      userRepo.findOne
        .mockResolvedValueOnce(currentUser) // getProfile
        .mockResolvedValueOnce({ id: 'user-2', phoneNumber: '+84999999999' }); // phone check

      await expect(
        usersService.updateProfile('user-1', { phoneNumber: '+84999999999' }),
      ).rejects.toThrow(ConflictException);
    });

    it('should allow user to keep their own phone number', async () => {
      const currentUser = { id: 'user-1', displayName: 'Current User', phoneNumber: '+84999999999' };
      userRepo.findOne
        .mockResolvedValueOnce(currentUser) // getProfile
        .mockResolvedValueOnce({ id: 'user-1', phoneNumber: '+84999999999' }); // phone check (same user)

      const updated = await usersService.updateProfile('user-1', {
        displayName: 'Updated Name',
        phoneNumber: '+84999999999',
      });

      expect(updated.displayName).toBe('Updated Name');
      expect(updated.phoneNumber).toBe('+84999999999');
    });

    it('should update phone number successfully when phone is not taken', async () => {
      const currentUser = { id: 'user-1', displayName: 'Current User', phoneNumber: null };
      userRepo.findOne
        .mockResolvedValueOnce(currentUser) // getProfile
        .mockResolvedValueOnce(null); // phone check (not taken)

      const updated = await usersService.updateProfile('user-1', {
        phoneNumber: '+84988887777',
      });

      expect(updated.phoneNumber).toBe('+84988887777');
      expect(userRepo.save).toHaveBeenCalled();
    });
  });
});
