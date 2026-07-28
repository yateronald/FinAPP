import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Profile, Strategy, VerifyCallback } from 'passport-google-oauth20';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(config: ConfigService) {
    super({
      clientID: config.get<string>('google.clientId') || 'missing',
      clientSecret: config.get<string>('google.clientSecret') || 'missing',
      callbackURL: config.get<string>('google.callbackUrl'),
      scope: ['email', 'profile'],
    });
  }

  async validate(
    _accessToken: string,
    _refreshToken: string,
    profile: Profile,
    done: VerifyCallback,
  ) {
    const { id, name, emails, photos } = profile;
    const primary = emails?.[0];
    const user = {
      googleId: id,
      email: primary?.value,
      // Accounts are linked by email, so an unverified address would let a
      // stranger claim someone else's account. Passed through and enforced in
      // resolveGoogleAccount.
      emailVerified: (primary as { verified?: boolean | string } | undefined)?.verified !== false,
      firstName: name?.givenName,
      lastName: name?.familyName,
      avatarUrl: photos?.[0]?.value,
    };
    done(null, user);
  }
}
