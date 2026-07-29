/**
 * Current versions of the user-facing legal documents.
 *
 * Bump a version when the corresponding document changes materially. Accounts
 * store the version they accepted, so the app can re-prompt only the users who
 * agreed to an older text rather than everyone.
 *
 * The documents themselves live in the clients (mobile/web) so they can be read
 * offline and translated; these constants are the single source of truth for
 * *which* revision is in force.
 */
export const TERMS_VERSION = '1.0';
export const PRIVACY_VERSION = '1.0';

/** Minimum age to hold an account, as stated in the Terms. */
export const MINIMUM_AGE = 15;
