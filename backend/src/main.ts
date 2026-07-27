import { ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { WINSTON_MODULE_NEST_PROVIDER } from 'nest-winston';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);

  app.useLogger(app.get(WINSTON_MODULE_NEST_PROVIDER));

  // Security
  app.use(helmet());
  app.use(compression());
  app.use(cookieParser(config.get<string>('cookie.secret')));

  // CORS
  app.enableCors({
    origin: config.get<string[]>('corsOrigins'),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  // Global prefix + validation + serialization
  const apiPrefix = config.get<string>('apiPrefix') || 'api/v1';
  app.setGlobalPrefix(apiPrefix);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(new TransformInterceptor());

  // Swagger
  const swaggerConfig = new DocumentBuilder()
    .setTitle('FinApp API')
    .setDescription('AI Personal Finance Management Platform - REST API')
    .setVersion('1.0')
    .addBearerAuth()
    .addCookieAuth('refresh_token')
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup(`${apiPrefix}/docs`, app, document, {
    swaggerOptions: { persistAuthorization: true },
  });

  const port = config.get<number>('port') || 4000;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`🚀 FinApp API running on http://localhost:${port}/${apiPrefix}`);
  console.log(`📚 Swagger docs at http://localhost:${port}/${apiPrefix}/docs`);
}
bootstrap();
