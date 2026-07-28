import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * When an admin resets a password we set `mustChangePassword`. This guard makes
 * that gate real: the account can do nothing but read its own profile and set a
 * new password until the flag is cleared.
 *
 * Enforcing it server-side matters — a client-only redirect is trivially
 * bypassed by calling the API directly.
 */
@Injectable()
export class PasswordChangeGuard implements CanActivate {
  /** Endpoints still reachable while a password change is pending. */
  private static readonly ALLOWED = [
    'POST /auth/change-password',
    'POST /auth/logout',
    'POST /auth/refresh',
    'GET /users/me',
  ];

  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    const user = req.user;
    if (!user?.userId) return true; // unauthenticated routes are handled elsewhere

    const path: string = (req.route?.path ?? req.url ?? '').replace(/\/api\/v\d+/, '');
    const key = `${req.method} ${path}`;
    if (PasswordChangeGuard.ALLOWED.some((a) => key.startsWith(a))) return true;

    const record = await this.prisma.user.findUnique({
      where: { id: user.userId },
      select: { mustChangePassword: true },
    });
    if (record?.mustChangePassword) {
      throw new ForbiddenException({
        message: 'You must change your password before continuing.',
        code: 'PASSWORD_CHANGE_REQUIRED',
      });
    }
    return true;
  }
}
