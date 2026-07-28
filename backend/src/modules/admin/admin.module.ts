import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [AuthModule], // for TokenService (hashing + session revocation)
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
