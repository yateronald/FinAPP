import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService) {
    const host = this.config.get<string>('mail.host');
    const user = this.config.get<string>('mail.user');
    const password = this.config.get<string>('mail.password');

    if (host && user && password && !user.startsWith('your_')) {
      this.transporter = nodemailer.createTransport({
        host,
        port: this.config.get<number>('mail.port'),
        secure: this.config.get<boolean>('mail.secure'),
        auth: { user, pass: password },
      });
    } else {
      this.logger.warn('SMTP not configured — emails will be logged instead of sent.');
    }
  }

  private async send(to: string, subject: string, html: string) {
    const fromName = this.config.get<string>('mail.fromName');
    const fromAddress = this.config.get<string>('mail.fromAddress');
    const from = `"${fromName}" <${fromAddress}>`;

    if (!this.transporter) {
      this.logger.debug(`[MAIL:MOCK] To: ${to} | Subject: ${subject}\n${html}`);
      return;
    }
    await this.transporter.sendMail({ from, to, subject, html });
    this.logger.log(`Email sent to ${to}: ${subject}`);
  }

  async sendOtp(to: string, code: string, purpose: string) {
    const html = this.wrap(
      'Your verification code',
      `<p>Use the following code to continue. It expires soon.</p>
       <p style="font-size:28px;font-weight:700;letter-spacing:6px;">${code}</p>
       <p style="color:#64748b;">Purpose: ${purpose}</p>`,
    );
    await this.send(to, 'FinApp verification code', html);
  }

  async sendPasswordReset(to: string, code: string) {
    const html = this.wrap(
      'Reset your password',
      `<p>We received a request to reset your password. Use this code:</p>
       <p style="font-size:28px;font-weight:700;letter-spacing:6px;">${code}</p>
       <p style="color:#64748b;">If you did not request this, you can ignore this email.</p>`,
    );
    await this.send(to, 'FinApp password reset', html);
  }

  async sendWelcome(to: string, name?: string) {
    const html = this.wrap(
      `Welcome to FinApp${name ? ', ' + name : ''}!`,
      `<p>Your account is ready. Start tracking your income, expenses and budgets, and let the AI coach help you save more.</p>`,
    );
    await this.send(to, 'Welcome to FinApp', html);
  }

  private wrap(title: string, body: string) {
    return `<div style="font-family:Inter,Arial,sans-serif;max-width:560px;margin:auto;padding:24px;">
      <h1 style="color:#4f46e5;">FinApp</h1>
      <h2 style="color:#0f172a;">${title}</h2>
      <div style="color:#334155;font-size:15px;line-height:1.6;">${body}</div>
      <hr style="border:none;border-top:1px solid #e2e8f0;margin:24px 0;"/>
      <p style="color:#94a3b8;font-size:12px;">FinApp — AI Personal Finance Management</p>
    </div>`;
  }
}
