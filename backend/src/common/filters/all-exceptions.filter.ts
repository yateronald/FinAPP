import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';
    let error = 'InternalServerError';
    // Stable machine-readable code (e.g. PASSWORD_CHANGE_REQUIRED) so clients
    // branch on this instead of matching translatable message text.
    let code: string | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object' && res !== null) {
        message = (res as any).message ?? message;
        error = (res as any).error ?? exception.name;
        code = (res as any).code;
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      const mapped = this.mapPrismaError(exception);
      status = mapped.status;
      message = mapped.message;
      error = 'DatabaseError';
    } else if (exception instanceof Error) {
      message = exception.message;
    }

    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url} -> ${status}`,
        (exception as Error)?.stack,
      );
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      error,
      message,
      ...(code ? { code } : {}),
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }

  private mapPrismaError(e: Prisma.PrismaClientKnownRequestError): {
    status: number;
    message: string;
  } {
    switch (e.code) {
      case 'P2002':
        return { status: HttpStatus.CONFLICT, message: 'A record with this value already exists' };
      case 'P2025':
        return { status: HttpStatus.NOT_FOUND, message: 'Record not found' };
      case 'P2003':
        return { status: HttpStatus.BAD_REQUEST, message: 'Related record constraint failed' };
      default:
        return { status: HttpStatus.BAD_REQUEST, message: 'Database request error' };
    }
  }
}
