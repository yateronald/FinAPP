import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log: [
        { emit: 'event', level: 'error' },
        { emit: 'event', level: 'warn' },
      ],
    });
  }

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log('Connected to the database');
    } catch (err) {
      this.logger.error('Failed to connect to the database', err as Error);
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  /**
   * Helper to build a where clause that excludes soft-deleted rows.
   */
  notDeleted<T extends Record<string, any>>(where: T = {} as T) {
    return { ...where, deletedAt: null };
  }
}
