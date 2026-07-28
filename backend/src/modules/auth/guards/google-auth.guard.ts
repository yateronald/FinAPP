import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../../../common/decorators/public.decorator';
import { Reflector } from '@nestjs/core';

@Injectable()
export class GoogleAuthGuard extends AuthGuard('google') {
  constructor(private reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    // Google routes are public entry points (redirect flow).
    void this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    return super.canActivate(context);
  }

  /**
   * Carry the caller's intent through Google in the OAuth `state` parameter,
   * so the callback knows whether the user pressed "Sign in" or "Sign up".
   * Google echoes `state` back verbatim.
   */
  getAuthenticateOptions(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest();
    const intent = req.query?.intent === 'signup' ? 'signup' : 'signin';
    return { state: intent };
  }
}
