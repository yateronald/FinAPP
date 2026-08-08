/**
 * Copy for welcome and inactivity-reminder notifications, in both supported
 * languages.
 *
 * Kept in one file so the wording can be reviewed and changed without touching
 * the scheduling logic — these are the only strings a user reads unprompted,
 * so tone matters more than usual.
 */

type Lang = 'FR' | 'EN';

export interface EngagementMessage {
  title: string;
  message: string;
}

const fr = <T>(lang: Lang, frValue: T, enValue: T): T => (lang === 'EN' ? enValue : frValue);

export function welcomeMessage(lang: Lang, firstName?: string | null): EngagementMessage {
  const name = firstName?.trim();
  return {
    title: fr(
      lang,
      name ? `Bienvenue sur Fynexa, ${name} 👋` : 'Bienvenue sur Fynexa 👋',
      name ? `Welcome to Fynexa, ${name} 👋` : 'Welcome to Fynexa 👋',
    ),
    message: fr(
      lang,
      'Vous venez de faire le premier pas vers des finances plus sereines. ' +
        'Enregistrez votre première dépense aujourd’hui : en quelques jours, votre ' +
        'tableau de bord et votre assistant IA commenceront à révéler vos habitudes.',
      'You’ve just taken the first step toward calmer finances. Record your first ' +
        'expense today — within a few days your dashboard and AI assistant will start ' +
        'revealing your habits, and helping you save.',
    ),
  };
}

/**
 * Rotating variants so a daily reminder never reads like the same robot.
 * The caller picks by how many reminders it has already sent.
 */
const EXPENSE_REMINDERS: Record<Lang, EngagementMessage[]> = {
  FR: [
    {
      title: 'Pas de dépense depuis 2 jours 📝',
      message: '30 secondes suffisent pour garder vos comptes à jour.',
    },
    {
      title: 'Votre suivi vous attend',
      message: 'Chaque dépense notée rend votre analyse IA plus juste.',
    },
    {
      title: 'Un petit geste, un grand écart',
      message: 'Les dépenses oubliées sont celles qui font déraper un budget.',
    },
  ],
  EN: [
    {
      title: 'No expenses logged for 2 days 📝',
      message: '30 seconds keeps your books current.',
    },
    {
      title: 'Your tracker is waiting',
      message: 'Every expense you log sharpens your AI insights.',
    },
    {
      title: 'Small habit, big difference',
      message: 'Forgotten expenses are the ones that break a budget.',
    },
  ],
};

export function expenseReminder(lang: Lang, sentCount: number): EngagementMessage {
  const variants = EXPENSE_REMINDERS[lang] ?? EXPENSE_REMINDERS.FR;
  return variants[sentCount % variants.length];
}

export function incomeReminder(lang: Lang): EngagementMessage {
  return {
    title: fr(lang, 'Aucun revenu ce mois-ci 💰', 'No income recorded this month 💰'),
    message: fr(
      lang,
      'Ajoutez vos revenus pour débloquer votre taux d’épargne, vos prévisions et vos objectifs.',
      'Add your income to unlock your savings rate, forecasts and goals.',
    ),
  };
}

/**
 * Countdown for accounts that predate mandatory verification. The tone gets
 * firmer as the deadline nears, because the consequence is real: sign-in stops
 * working once the window closes.
 */
export function verificationReminder(
  lang: Lang,
  daysLeft: number,
  firstName?: string | null,
): EngagementMessage {
  const name = firstName?.trim();
  const urgent = daysLeft <= 3;
  return {
    title: fr(
      lang,
      urgent
        ? daysLeft <= 1
          ? '⚠️ Dernier jour pour confirmer votre e-mail'
          : `⚠️ Plus que ${daysLeft} jours pour confirmer votre e-mail`
        : 'Confirmez votre adresse e-mail',
      urgent
        ? daysLeft <= 1
          ? '⚠️ Last day to confirm your e-mail'
          : `⚠️ ${daysLeft} days left to confirm your e-mail`
        : 'Confirm your e-mail address',
    ),
    message: fr(
      lang,
      `${name ? `${name}, c` : 'C'}onfirmer votre adresse protège votre compte et ` +
        'vous permet de réinitialiser votre mot de passe si vous l’oubliez. ' +
        (urgent
          ? `Sans confirmation, la connexion sera bloquée dans ${daysLeft <= 1 ? 'moins d’un jour' : `${daysLeft} jours`}.`
          : `Il vous reste ${daysLeft} jours.`),
      `${name ? `${name}, c` : 'C'}onfirming your address protects your account and ` +
        'lets you reset your password if you ever forget it. ' +
        (urgent
          ? `Without it, sign-in stops working in ${daysLeft <= 1 ? 'less than a day' : `${daysLeft} days`}.`
          : `You have ${daysLeft} days left.`),
    ),
  };
}
