/**
 * Confirmation-code e-mail.
 *
 * Nested tables and inline styles on purpose: Outlook (Word engine) ignores
 * flexbox, grid, and most <style> rules. Only the two logos are images, and
 * they travel as CID attachments — so the mail needs no external host, raises
 * no "load images" prompt, and stays fully usable if a client blocks images.
 *
 * Responsiveness is hybrid: percentage widths carry every client (including
 * Outlook, which ignores media queries) and a media query on top trims padding
 * and the digit boxes on narrow screens.
 */

const BRAND = '#2563EB';
const BRAND_DARK = '#1D4ED8';
const INK = '#0F172A';
const MUTED = '#64748B';
const LINE = '#E2E8F0';
const PAGE = '#F1F5F9';

export type MailLang = 'fr' | 'en';

export interface OtpMailOptions {
  code: string;
  lang?: MailLang;
  firstName?: string;
  expiresMinutes?: number;
  supportEmail?: string;
  siteUrl?: string;
  /** Changes only the wording; the layout is shared. */
  purpose?: 'verify' | 'reset';
}

const COPY = {
  fr: {
    subjectVerify: 'Votre code de confirmation Fynexa',
    subjectReset: 'Réinitialisation de votre mot de passe Fynexa',
    hello: (n?: string) => (n ? `Bonjour ${n}` : 'Bonjour'),
    secure: 'Sécurisé',
    titleVerify: 'Voici votre code de confirmation',
    titleReset: 'Réinitialisez votre mot de passe',
    leadVerify: 'Utilisez le code ci-dessous pour confirmer votre action sur Fynexa.',
    leadReset:
      'Utilisez le code ci-dessous pour choisir un nouveau mot de passe.',
    yourCode: 'Votre code',
    expiresIn: (m: number) => `Expire dans <strong style="color:${BRAND};">${m} minutes</strong>`,
    warn: "Ne partagez ce code avec personne, pas même avec notre équipe. Si vous n'êtes pas à l'origine de cette demande, ignorez simplement cet e-mail.",
    helpTitle: "Besoin d'aide ?",
    helpBody: 'Notre équipe support est là pour vous.',
    tagline: 'Gérez. Épargnez. Atteignez vos objectifs.',
    rights: 'Tous droits réservés.',
    auto: "Cet e-mail a été envoyé automatiquement, merci de ne pas y répondre.",
    preheader: (c: string, m: number) =>
      `Votre code de confirmation Fynexa : ${c} — valable ${m} minutes.`,
    plain: (c: string, m: number) =>
      `Votre code de confirmation Fynexa est ${c}. Il expire dans ${m} minutes. Ne le partagez avec personne.`,
  },
  en: {
    subjectVerify: 'Your Fynexa confirmation code',
    subjectReset: 'Reset your Fynexa password',
    hello: (n?: string) => (n ? `Hello ${n}` : 'Hello'),
    secure: 'Secure',
    titleVerify: 'Here is your confirmation code',
    titleReset: 'Reset your password',
    leadVerify: 'Use the code below to confirm your action on Fynexa.',
    leadReset: 'Use the code below to choose a new password.',
    yourCode: 'Your code',
    expiresIn: (m: number) => `Expires in <strong style="color:${BRAND};">${m} minutes</strong>`,
    warn: 'Never share this code with anyone, not even our team. If you did not request it, simply ignore this e-mail.',
    helpTitle: 'Need help?',
    helpBody: 'Our support team is here for you.',
    tagline: 'Manage. Save. Reach your goals.',
    rights: 'All rights reserved.',
    auto: 'This e-mail was sent automatically, please do not reply.',
    preheader: (c: string, m: number) =>
      `Your Fynexa confirmation code: ${c} — valid for ${m} minutes.`,
    plain: (c: string, m: number) =>
      `Your Fynexa confirmation code is ${c}. It expires in ${m} minutes. Do not share it with anyone.`,
  },
} as const;

export function otpSubject(o: OtpMailOptions): string {
  const t = COPY[o.lang ?? 'fr'];
  return o.purpose === 'reset' ? t.subjectReset : t.subjectVerify;
}

export function otpPlainText(o: OtpMailOptions): string {
  const t = COPY[o.lang ?? 'fr'];
  return t.plain(o.code, o.expiresMinutes ?? 3);
}

export function otpEmailHtml(o: OtpMailOptions): string {
  const t = COPY[o.lang ?? 'fr'];
  const code = String(o.code ?? '');
  const minutes = o.expiresMinutes ?? 3;
  const supportEmail = o.supportEmail || 'fynexa@zohomail.com';
  const siteUrl = o.siteUrl || '';
  const isReset = o.purpose === 'reset';

  // One boxed cell per digit, mirroring the app's code input. letter-spacing
  // is unreliable in Outlook, so the spacing is real table geometry instead.
  const digits = code
    .split('')
    .map(
      (d, i) => `
        ${i ? '<td width="8" style="font-size:0;line-height:0;">&nbsp;</td>' : ''}
        <td align="center" valign="middle" class="digit"
            style="width:44px;height:56px;background:#FFFFFF;border:1.5px solid #BFDBFE;
                   border-radius:10px;font:700 26px/56px Arial,Helvetica,sans-serif;
                   color:${BRAND_DARK};">${d}</td>`,
    )
    .join('');

  return `<!doctype html>
<html lang="${o.lang ?? 'fr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<title>${isReset ? t.titleReset : t.titleVerify}</title>
<style>
  @media only screen and (max-width:600px) {
    .wrap  { padding:10px 6px !important; }
    .pad   { padding-left:18px !important; padding-right:18px !important; }
    .title { font-size:22px !important; }
    .digit { width:38px !important; height:50px !important;
             font-size:22px !important; line-height:50px !important; }
    .stack { display:block !important; width:100% !important;
             padding:0 !important; text-align:center !important; }
    .stack-gap { padding-top:12px !important; }
  }
</style>
</head>
<body style="margin:0;padding:0;background:${PAGE};">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
    ${t.preheader(code, minutes)}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
         style="background:${PAGE};">
    <tr><td align="center" class="wrap" style="padding:22px 10px;">

      <table role="presentation" width="90%" cellpadding="0" cellspacing="0" border="0"
             style="width:90%;max-width:600px;background:#FFFFFF;border-radius:16px;
                    border:1px solid ${LINE};">

        <!-- A flat brand rule: gradients do not render in Outlook. -->
        <tr><td style="background:${BRAND};height:4px;font-size:0;line-height:0;
                       border-radius:16px 16px 0 0;">&nbsp;</td></tr>

        <tr><td class="pad" style="padding:22px 28px 0;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr>
              <td align="left" valign="middle">
                <img src="cid:fynexa_logo_header" width="170" alt="Fynexa"
                     style="display:block;border:0;width:170px;max-width:58%;height:auto;">
              </td>
              <td align="right" valign="middle"
                  style="font:600 11.5px/1.4 Arial,Helvetica,sans-serif;color:${MUTED};">
                &#128274;&nbsp; ${t.secure}
              </td>
            </tr>
          </table>
        </td></tr>

        <tr><td align="center" class="pad" style="padding:26px 34px 0;">
          <div style="font:700 13px/1.4 Arial,Helvetica,sans-serif;color:${BRAND};
                      text-transform:uppercase;">
            ${t.hello(o.firstName)} &#128075;
          </div>
          <div class="title" style="font:700 26px/1.3 Arial,Helvetica,sans-serif;
                      color:${INK};padding-top:12px;">
            ${isReset ? t.titleReset : t.titleVerify}
          </div>
          <div style="font:400 14px/1.6 Arial,Helvetica,sans-serif;color:${MUTED};padding-top:12px;">
            ${isReset ? t.leadReset : t.leadVerify}
          </div>
        </td></tr>

        <tr><td align="center" class="pad" style="padding:26px 20px 0;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0"
                 style="background:#EFF6FF;border-radius:14px;">
            <tr><td align="center" style="padding:22px 20px;">
              <div style="font:600 11.5px/1.4 Arial,Helvetica,sans-serif;color:${MUTED};
                          text-transform:uppercase;padding-bottom:14px;">
                ${t.yourCode}
              </div>
              <table role="presentation" cellpadding="0" cellspacing="0" border="0"
                     style="margin:0 auto;"><tr>${digits}</tr></table>
              <div style="font:400 12.5px/1.5 Arial,Helvetica,sans-serif;color:${MUTED};padding-top:16px;">
                &#128337;&nbsp; ${t.expiresIn(minutes)}
              </div>
            </td></tr>
          </table>
        </td></tr>

        <tr><td align="center" class="pad" style="padding:20px 34px 0;">
          <div style="font:400 12.5px/1.6 Arial,Helvetica,sans-serif;color:${MUTED};">
            ${t.warn}
          </div>
        </td></tr>

        <tr><td class="pad" style="padding:22px 28px 0;">
          <div style="border-top:1px solid ${LINE};font-size:0;line-height:0;">&nbsp;</div>
        </td></tr>

        <tr><td class="pad" style="padding:18px 28px 0;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr>
              <td class="stack" valign="middle"
                  style="font:400 12.5px/1.5 Arial,Helvetica,sans-serif;color:${MUTED};">
                <strong style="color:${INK};">${t.helpTitle}</strong><br>${t.helpBody}
              </td>
              <td class="stack stack-gap" align="right" valign="middle"
                  style="font:600 12.5px/1.4 Arial,Helvetica,sans-serif;">
                <a href="mailto:${supportEmail}"
                   style="color:${BRAND};text-decoration:none;">&#9993;&#65039; ${supportEmail}</a>
                ${
                  siteUrl
                    ? `<br><a href="${siteUrl}" style="color:${BRAND};text-decoration:none;">&#127760; ${siteUrl.replace(
                        /^https?:\/\//,
                        '',
                      )}</a>`
                    : ''
                }
              </td>
            </tr>
          </table>
        </td></tr>

        <tr><td align="center" class="pad" style="padding:26px 28px 26px;">
          <img src="cid:fynexa_logo_footer" width="120" alt="Fynexa"
               style="display:block;margin:0 auto;border:0;width:120px;height:auto;">
          <div style="font:400 12px/1.5 Arial,Helvetica,sans-serif;color:${MUTED};padding-top:9px;">
            ${t.tagline}
          </div>
          <div style="font:400 11px/1.6 Arial,Helvetica,sans-serif;color:#94A3B8;padding-top:14px;">
            &copy; ${new Date().getFullYear()} Fynexa. ${t.rights}<br>${t.auto}
          </div>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}
