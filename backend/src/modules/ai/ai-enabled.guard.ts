import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AI_CONSENT_VERSION } from '../../common/constants/ai-consent';

/**
 * Server-side privacy boundary for every `/ai` endpoint.
 *
 * Client-side disabled states are only presentation. This guard is the actual
 * enforcement that prevents financial data from reaching an AI provider when
 * the user has not opted in to the current disclosure.
 */
@Injectable()
export class AiEnabledGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const userId = request.user?.userId as string | undefined;

    const settings = userId
      ? await this.prisma.userSettings.findUnique({
          where: { userId },
          select: {
            aiEnabled: true,
            aiConsentAt: true,
            aiConsentVersion: true,
          },
        })
      : null;

    if (
      !settings?.aiEnabled ||
      !settings.aiConsentAt ||
      settings.aiConsentVersion !== AI_CONSENT_VERSION
    ) {
      throw new ForbiddenException({
        code: 'AI_DISABLED',
        message:
          'AI features are disabled. Review the data-use disclosure and enable AI in Settings.',
      });
    }

    return true;
  }
}

