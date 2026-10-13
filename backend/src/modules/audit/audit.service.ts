import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from './entities/audit-log.entity';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(
    @InjectRepository(AuditLog)
    private readonly auditRepo: Repository<AuditLog>,
  ) {}

  async log(params: {
    userId?: string;
    action: string;
    resourceType: string;
    resourceId?: string;
    ipAddress?: string;
    userAgent?: string;
    details?: Record<string, any>;
  }): Promise<AuditLog> {
    const entry = this.auditRepo.create({
      userId: params.userId || undefined,
      action: params.action,
      resourceType: params.resourceType,
      resourceId: params.resourceId || undefined,
      ipAddress: params.ipAddress || undefined,
      userAgent: params.userAgent || undefined,
      details: params.details || {},
    });
    return this.auditRepo.save(entry);
  }
}
