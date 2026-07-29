/// Terms of Use and Privacy Policy, in French and English.
///
/// Kept in the app rather than fetched so they are readable offline and before
/// an account exists. [kTermsVersion] / [kPrivacyVersion] must stay in sync
/// with `backend/src/common/constants/legal.ts` — the backend records which
/// version each user accepted so a future revision can re-prompt only them.
library;

const kTermsVersion = '1.0';
const kPrivacyVersion = '1.0';
const kLegalEffectiveDate = '29 July 2026';
const kLegalContactEmail = 'yateronald@gmail.com';
const kMinimumAge = 15;

String termsOfUse({required bool fr}) => fr ? _termsFr : _termsEn;
String privacyPolicy({required bool fr}) => fr ? _privacyFr : _privacyEn;

// ===========================================================================
// TERMS OF USE
// ===========================================================================

const _termsEn = '''
**Version $kTermsVersion · Effective $kLegalEffectiveDate**

## 1. Who is responsible
Fynexa is developed and operated by **Yate Asseke Ronald**, an independent developer.
Contact: **$kLegalContactEmail**

## 2. What Fynexa is
Fynexa is a personal finance tracker. You record your income and expenses, set budgets, and receive automated analysis to help you understand your spending and save more.

**Fynexa never connects to your bank and never stores card or bank details.** It only knows the figures you type in yourself. It cannot see, move or access any real money.

## 3. Not financial advice
Insights, forecasts and suggestions are generated automatically from the data you enter, partly using artificial intelligence. They are informational only, may be inaccurate, and are **not** professional financial, tax, investment or legal advice. Decisions you make based on them are your own.

## 4. Your account
You must be at least $kMinimumAge years old to use Fynexa. You are responsible for the accuracy of what you enter, and for keeping your password and device secure. One person, one account.

## 5. Acceptable use
Do not attempt to access other users' data, reverse-engineer or overload the service, or use it for unlawful purposes.

## 6. Availability
Fynexa is provided "as is". Features may change, be suspended or be discontinued. We do not guarantee uninterrupted availability, nor that automated insights will be correct.

## 7. Your data
You own the data you enter. You can permanently delete it at any time from **Settings → Delete my account**. Deletion is immediate and cannot be undone.

## 8. Termination
You may delete your account at any time. Accounts that breach these terms may be suspended.

## 9. Liability
To the fullest extent permitted by law, we are not liable for indirect or consequential loss, or for financial decisions taken in reliance on the app.

## 10. Changes
Material changes will be notified in the app, and you will be asked to accept the new version.
''';

const _termsFr = '''
**Version $kTermsVersion · En vigueur le $kLegalEffectiveDate**

## 1. Responsable
Fynexa est développé et exploité par **Yate Asseke Ronald**, développeur indépendant.
Contact : **$kLegalContactEmail**

## 2. Ce qu'est Fynexa
Fynexa est un outil de suivi de finances personnelles. Vous enregistrez vos revenus et vos dépenses, définissez des budgets et recevez une analyse automatique pour mieux comprendre vos dépenses et épargner davantage.

**Fynexa ne se connecte jamais à votre banque et n'enregistre aucune donnée bancaire ou de carte.** L'application ne connaît que les montants que vous saisissez vous-même. Elle ne peut ni voir, ni déplacer, ni accéder à de l'argent réel.

## 3. Ce n'est pas un conseil financier
Les analyses, prévisions et suggestions sont générées automatiquement à partir de vos données, en partie par intelligence artificielle. Elles sont fournies à titre informatif, peuvent être inexactes et ne constituent **pas** un conseil professionnel financier, fiscal, en investissement ou juridique. Les décisions que vous prenez relèvent de votre responsabilité.

## 4. Votre compte
Vous devez avoir au moins $kMinimumAge ans pour utiliser Fynexa. Vous êtes responsable de l'exactitude de vos saisies ainsi que de la sécurité de votre mot de passe et de votre appareil. Une personne, un compte.

## 5. Usage acceptable
N'essayez pas d'accéder aux données d'autres utilisateurs, de faire de l'ingénierie inverse, de surcharger le service, ni de l'utiliser à des fins illicites.

## 6. Disponibilité
Fynexa est fourni « en l'état ». Les fonctionnalités peuvent évoluer, être suspendues ou supprimées. Nous ne garantissons ni une disponibilité ininterrompue, ni l'exactitude des analyses automatiques.

## 7. Vos données
Vous restez propriétaire de vos données. Vous pouvez les supprimer définitivement à tout moment depuis **Réglages → Supprimer mon compte**. La suppression est immédiate et irréversible.

## 8. Résiliation
Vous pouvez supprimer votre compte à tout moment. Les comptes qui enfreignent ces conditions peuvent être suspendus.

## 9. Responsabilité
Dans la limite permise par la loi, nous ne sommes pas responsables des dommages indirects, ni des décisions financières prises sur la base de l'application.

## 10. Modifications
Toute modification importante sera signalée dans l'application et devra être acceptée.
''';

// ===========================================================================
// PRIVACY POLICY
// ===========================================================================

const _privacyEn = '''
**Version $kPrivacyVersion · Effective $kLegalEffectiveDate**

## 1. Who is responsible
**Yate Asseke Ronald**, independent developer.
Privacy contact: **$kLegalContactEmail**

## 2. What we collect

**Account** — email, first and last name, country, profile photo, your password (stored only as a hash), and your Google account identifier if you sign in with Google.

**Financial records** — everything you enter: titles, amounts, dates, descriptions, payment method, tags, categories, budgets and recurring entries.

**Technical** — IP address, device and browser type, sign-in timestamps, and a push-notification token if you enable notifications.

**Generated** — the AI insights and forecasts derived from your entries.

**We never collect card numbers, bank credentials or bank account data.** We do not use advertising trackers, and we do not sell your data.

## 3. Why we process it
- To provide the service — performance of our agreement with you
- For AI insights, forecasts and reminders — you can switch these off in Settings
- For security, abuse prevention and audit logs — our legitimate interest
- To meet legal record-keeping obligations

## 4. Artificial intelligence — please read
To produce insights and answer your questions, **the content of your financial records — transaction titles, amounts, categories and descriptions — is sent to third-party AI providers**: **Google (Gemini)** and **AgentRouter**. They process it on our instructions to generate a response. Their servers may be located outside the EU, including in the United States.

**You can disable AI features entirely in Settings → AI Assistant.** When disabled, none of your data is sent to these providers.

No automated decision produces legal or similarly significant effects for you.

## 5. Where your data is stored
Your account and financial data are stored on servers in a **data centre in Germany (European Union)**.

Other processors: **Google Firebase** (push notifications), **Google Gemini** and **AgentRouter** (AI analysis, as described above).

## 6. Security
Passwords are hashed with **argon2id** and are never stored in readable form. All traffic between the app and our servers is encrypted with TLS. The database is not exposed to the internet and is reachable only by the application. On mobile you can enable a biometric lock.

Please note: your financial records are stored in our database without additional field-level encryption. Access is restricted to the application and to the developer for maintenance purposes.

## 7. How long we keep it
- Your account and financial data — until you delete your account
- When you delete your account — **everything is erased immediately and permanently**, with no recovery
- Security audit logs — kept after deletion, but **anonymised**: your email, IP address and device information are removed, leaving only the action and its date
- Push notification tokens — until you disable notifications or sign out

## 8. Your rights
You may request access, correction, deletion, portability or restriction of your data, and object to processing. In the app you can delete everything yourself from **Settings → Delete my account**. For anything else, write to **$kLegalContactEmail**.

If you are in the EU, you also have the right to complain to your national data protection authority.

## 9. Children
Fynexa is not intended for anyone under $kMinimumAge.

## 10. Changes
Material changes will be notified in the app and will require your acceptance.
''';

const _privacyFr = '''
**Version $kPrivacyVersion · En vigueur le $kLegalEffectiveDate**

## 1. Responsable
**Yate Asseke Ronald**, développeur indépendant.
Contact vie privée : **$kLegalContactEmail**

## 2. Données collectées

**Compte** — e-mail, prénom et nom, pays, photo de profil, mot de passe (uniquement sous forme de hachage) et identifiant Google si vous utilisez la connexion Google.

**Données financières** — tout ce que vous saisissez : intitulés, montants, dates, descriptions, moyen de paiement, étiquettes, catégories, budgets et transactions récurrentes.

**Données techniques** — adresse IP, type d'appareil et de navigateur, dates de connexion, et jeton de notification si vous activez les notifications.

**Données générées** — les analyses et prévisions IA issues de vos saisies.

**Nous ne collectons jamais de numéro de carte, d'identifiants bancaires ni de données de compte bancaire.** Aucun traceur publicitaire n'est utilisé et vos données ne sont jamais vendues.

## 3. Finalités
- Fournir le service — exécution de notre contrat
- Analyses IA, prévisions et rappels — désactivables dans les Réglages
- Sécurité, prévention des abus et journaux d'audit — intérêt légitime
- Obligations légales de conservation

## 4. Intelligence artificielle — à lire attentivement
Pour produire les analyses et répondre à vos questions, **le contenu de vos données financières — intitulés, montants, catégories et descriptions — est transmis à des fournisseurs d'IA tiers** : **Google (Gemini)** et **AgentRouter**. Ils les traitent sur nos instructions pour générer une réponse. Leurs serveurs peuvent se situer hors de l'Union européenne, notamment aux États-Unis.

**Vous pouvez désactiver entièrement les fonctions IA dans Réglages → Assistant IA.** Aucune donnée n'est alors transmise à ces fournisseurs.

Aucune décision automatisée ne produit d'effet juridique ou significatif à votre égard.

## 5. Lieu d'hébergement
Votre compte et vos données financières sont hébergés dans un **centre de données situé en Allemagne (Union européenne)**.

Autres sous-traitants : **Google Firebase** (notifications push), **Google Gemini** et **AgentRouter** (analyse IA, comme décrit ci-dessus).

## 6. Sécurité
Les mots de passe sont hachés avec **argon2id** et ne sont jamais conservés en clair. Tous les échanges entre l'application et nos serveurs sont chiffrés en TLS. La base de données n'est pas exposée sur Internet et n'est accessible que par l'application. Sur mobile, vous pouvez activer un verrouillage biométrique.

À noter : vos données financières sont stockées dans notre base sans chiffrement supplémentaire au niveau des champs. L'accès est limité à l'application et au développeur à des fins de maintenance.

## 7. Durées de conservation
- Compte et données financières — jusqu'à la suppression de votre compte
- À la suppression du compte — **tout est effacé immédiatement et définitivement**, sans possibilité de récupération
- Journaux d'audit de sécurité — conservés après suppression, mais **anonymisés** : e-mail, adresse IP et informations d'appareil sont retirés, ne laissant que l'action et sa date
- Jetons de notification — jusqu'à la désactivation des notifications ou la déconnexion

## 8. Vos droits
Vous pouvez demander l'accès, la rectification, l'effacement, la portabilité ou la limitation de vos données, et vous opposer au traitement. Dans l'application, vous pouvez tout supprimer vous-même via **Réglages → Supprimer mon compte**. Pour toute autre demande, écrivez à **$kLegalContactEmail**.

Si vous résidez dans l'UE, vous pouvez également introduire une réclamation auprès de votre autorité de protection des données.

## 9. Mineurs
Fynexa n'est pas destiné aux personnes de moins de $kMinimumAge ans.

## 10. Modifications
Toute modification importante sera signalée dans l'application et devra être acceptée.
''';
