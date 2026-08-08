import { existsSync } from 'fs';
import { join } from 'path';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import {
  MailLang,
  OtpMailOptions,
  otpEmailHtml,
  otpPlainText,
  otpSubject,
} from './templates/otp.template';

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

  /**
   * Whether a real transporter exists. Flows that would strand a user when no
   * mail can leave the server (email-verification OTP) check this first.
   */
  get isConfigured(): boolean {
    return this.transporter !== null;
  }

  /**
   * The two brand images, attached inline. Resolved from disk at call time so
   * a missing file degrades to a logo-less but perfectly readable e-mail
   * rather than throwing mid-send.
   */
  private brandAttachments() {
    // __dirname is dist/modules/mail at runtime; nest-cli copies the PNGs there.
    const dir = join(__dirname, 'assets');
    return [
      { filename: 'fynexa-header.png', file: 'logo_header.png', cid: 'fynexa_logo_header' },
      { filename: 'fynexa-footer.png', file: 'logo_footer.png', cid: 'fynexa_logo_footer' },
    ]
      .map(({ filename, file, cid }) => ({ filename, path: join(dir, file), cid }))
      .filter((a) => existsSync(a.path));
  }

  private async send(
    to: string,
    subject: string,
    html: string,
    extra: { text?: string; attachments?: nodemailer.SendMailOptions['attachments'] } = {},
  ) {
    const fromName = this.config.get<string>('mail.fromName');
    const fromAddress = this.config.get<string>('mail.fromAddress');
    const from = `"${fromName}" <${fromAddress}>`;

    if (!this.transporter) {
      this.logger.debug(`[MAIL:MOCK] To: ${to} | Subject: ${subject}\n${extra.text ?? html}`);
      return;
    }
    await this.transporter.sendMail({ from, to, subject, html, ...extra });
    this.logger.log(`Email sent to ${to}: ${subject}`);
  }

  /**
   * Confirmation code. `purpose` selects the wording; the layout is shared so
   * both flows look like the same product.
   */
  async sendOtp(
    to: string,
    code: string,
    purpose: string,
    opts: { firstName?: string; expiresMinutes?: number; language?: string } = {},
  ) {
    const lang: MailLang = (opts.language ?? '').toUpperCase() === 'EN' ? 'en' : 'fr';
    const payload: OtpMailOptions = {
      code,
      lang,
      firstName: opts.firstName,
      expiresMinutes: opts.expiresMinutes ?? 3,
      supportEmail: this.config.get<string>('mail.supportAddress') ?? undefined,
      siteUrl: this.config.get<string>('frontendUrl') ?? undefined,
      purpose: purpose === 'PASSWORD_RESET' ? 'reset' : 'verify',
    };

    await this.send(to, otpSubject(payload), otpEmailHtml(payload), {
      text: otpPlainText(payload),
      attachments: this.brandAttachments(),
    });
  }

  async sendPasswordReset(
    to: string,
    code: string,
    opts: { firstName?: string; expiresMinutes?: number; language?: string } = {},
  ) {
    await this.sendOtp(to, code, 'PASSWORD_RESET', opts);
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
