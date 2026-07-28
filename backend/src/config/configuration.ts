export default () => ({
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '4000', 10),
  apiPrefix: process.env.API_PREFIX || 'api/v1',
  corsOrigins: (process.env.CORS_ORIGINS || 'http://localhost:3000')
    .split(',')
    .map((o) => o.trim()),
  database: {
    url: process.env.DATABASE_URL,
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    // Web/default session length.
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
    // Mobile session length (longer — access is gated by biometric app-lock).
    refreshExpiresInMobile: process.env.JWT_REFRESH_EXPIRES_IN_MOBILE || '180d',
  },
  cookie: {
    secret: process.env.COOKIE_SECRET,
  },
  google: {
    clientId: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackUrl: process.env.GOOGLE_CALLBACK_URL,
  },
  gemini: {
    // Ordered list of keys: GEMINI_API_KEY, then GEMINI_API_KEY1..9.
    apiKeys: [
      process.env.GEMINI_API_KEY,
      ...Array.from({ length: 10 }, (_, i) => process.env[`GEMINI_API_KEY${i}`]),
    ].filter((k): k is string => !!k),
    model: process.env.GEMINI_MODEL || 'gemini-3-flash-preview',
  },
  agentRouter: {
    apiKey: process.env.AGENTROUTER_API_KEY,
    baseUrl: process.env.AGENTROUTER_BASE_URL || 'https://agentrouter.org/v1',
    model: process.env.AGENTROUTER_MODEL || 'claude-opus-4-8',
  },
  mail: {
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER,
    password: process.env.SMTP_PASSWORD,
    fromName: process.env.MAIL_FROM_NAME || 'FinApp',
    fromAddress: process.env.MAIL_FROM_ADDRESS || 'no-reply@finapp.local',
  },
  otp: {
    expiresMinutes: parseInt(process.env.OTP_EXPIRES_MINUTES || '10', 10),
  },
  auth: {
    // Unset = follow SMTP: with no mail server the OTP can never reach the
    // user, so requiring it would lock every new account out permanently.
    // Set to 'true'/'false' to force the behaviour either way.
    requireEmailVerification: process.env.AUTH_REQUIRE_EMAIL_VERIFICATION,
  },
  throttle: {
    ttl: parseInt(process.env.THROTTLE_TTL || '60', 10),
    limit: parseInt(process.env.THROTTLE_LIMIT || '100', 10),
  },
  webAppUrl: process.env.WEB_APP_URL || 'http://localhost:3000',
  defaultCurrency: process.env.DEFAULT_CURRENCY || 'XOF',
});
