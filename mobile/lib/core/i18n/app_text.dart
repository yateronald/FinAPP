import 'package:flutter/material.dart';

/// All user-facing strings, in French and English. Access via `context.t`.
class AppText {
  final String lang; // 'fr' | 'en'
  const AppText(this.lang);

  bool get _fr => lang == 'fr';

  /// Whether the UI language is French (used to build AI prompts).
  bool get isFr => _fr;
  String _s(String fr, String en) => _fr ? fr : en;

  // ---------------------------------------------------------- Common
  String get retry => _s('Réessayer', 'Retry');
  String get cancel => _s('Annuler', 'Cancel');
  String get save => _s('Enregistrer', 'Save');
  String get delete => _s('Supprimer', 'Delete');
  String get edit => _s('Modifier', 'Edit');
  String get create => _s('Créer', 'Create');
  String get add => _s('Ajouter', 'Add');
  String get addSheetSubtitle =>
      _s('Que voulez-vous enregistrer ?', 'What would you like to record?');
  String get search => _s('Rechercher…', 'Search…');
  String get seeAll => _s('Voir tout', 'See all');
  String get send => _s('Envoyer', 'Send');
  String get update => _s('Mettre à jour', 'Update');
  String get copied => _s('Copié', 'Copied');
  String get required => _s('Requis', 'Required');
  String get genericError =>
      _s('Une erreur est survenue', 'Something went wrong');
  String get noData => _s('Aucune donnée', 'No data');

  // ---------------------------------------------------------- Nav
  String get navHome => _s('Accueil', 'Home');
  String get navFinances => _s('Finances', 'Finances');
  String get navBudgets => _s('Budgets', 'Budgets');
  String get navAiShort => _s('IA', 'AI');
  String get navMore => _s('Plus', 'More');
  String get titleHome => _s('Accueil', 'Home');
  String get titleFinances => _s('Finances', 'Finances');
  String get titleBudgets => _s('Budgets', 'Budgets');
  String get titleAi => _s('Assistant IA', 'AI Assistant');
  String get settings => _s('Réglages', 'Settings');
  String get reports => _s('Rapports', 'Reports');
  String get notifications => _s('Notifications', 'Notifications');
  String get categories => _s('Catégories', 'Categories');

  // ------------------------------------------------------------- Loans
  /// Short label for the bottom navigation.
  String get navLoans => _s('Prêts', 'Loans');
  String get titleLoans => _s('Mes prêts', 'My loans');
  String get loanNew => _s('Nouveau prêt', 'New loan');
  String get loanEdit => _s('Modifier le prêt', 'Edit loan');
  String get loanName => _s('Nom du prêt', 'Loan name');
  String get loanNameHint => _s('Ex. Crédit auto', 'e.g. Car loan');
  String get loanLender => _s('Prêteur (optionnel)', 'Lender (optional)');
  String get loanLenderHint =>
      _s('Ex. Ecobank, un proche…', 'e.g. Ecobank, a relative…');
  String get loanDescription =>
      _s('Description (optionnel)', 'Description (optional)');
  String get loanDescriptionHint =>
      _s('Ex. Raison du prêt, notes…', 'e.g. Reason, notes…');
  String get loanCreateAction => _s('Créer le prêt', 'Create loan');
  String get loanSaveAction => _s('Enregistrer le prêt', 'Save loan');
  String get loanPrincipal =>
      _s('Montant total emprunté', 'Total amount borrowed');
  String get loanAlreadyPaid => _s('Déjà remboursé', 'Already repaid');
  String get loanAlreadyPaidHelp => _s(
    'Si vous avez déjà remboursé une partie avant d’utiliser Fynexa, '
        'indiquez le montant total ici pour un suivi exact.',
    'If you repaid part of it before using Fynexa, enter the total here so '
        'the tracking stays accurate.',
  );
  String get loanAlreadyPaidTooHigh => _s(
    'Ne peut pas dépasser le montant emprunté',
    'Cannot exceed the amount borrowed',
  );
  String get loanStartDate => _s('Date de début', 'Start date');
  String get loanEndDate => _s('Fin prévue', 'Expected end');
  String get loanNoEndDate => _s('Non définie', 'Not set');

  String get loanRemaining => _s('Restant', 'Remaining');
  String get loanPaid => _s('Remboursé', 'Repaid');
  String get loanTotal => _s('Total', 'Total');
  String get loanPerMonth => _s('/ mois conseillé', 'suggested / month');
  String loanMonthsLeft(int n) =>
      _s('$n mois restants', '$n month${n == 1 ? '' : 's'} left');
  String get loanOverdue => _s('En retard', 'Overdue');
  String get loanPaidOff => _s('Remboursé ✓', 'Paid off ✓');
  String get loanActive => _s('En cours', 'Active');
  String loanPaymentCount(int n) =>
      _s('$n versement${n > 1 ? 's' : ''}', '$n payment${n == 1 ? '' : 's'}');

  String get loanEmptyTitle => _s('Aucun prêt suivi', 'No loans tracked');
  String get loanEmptyBody => _s(
    'Ajoutez un prêt pour suivre ce qu’il vous reste à rembourser, et liez '
        'vos dépenses à celui-ci pour une progression automatique.',
    'Add a loan to track what is left to repay, and link your expenses to '
        'it so progress updates automatically.',
  );
  String get loanCreateFirst => _s('Créer un prêt', 'Create a loan');
  String get loanHistory => _s('Historique des versements', 'Payment history');
  String get loanNoPayments => _s(
    'Aucun versement enregistré. Ajoutez une dépense et cochez « Je rembourse un prêt ».',
    'No payments yet. Add an expense and tick “This repays a loan”.',
  );
  String get loanDeleteTitle => _s('Supprimer ce prêt ?', 'Delete this loan?');
  String get loanDeleteBody => _s(
    'Le prêt sera supprimé, mais les dépenses liées resteront dans votre '
        'historique — elles correspondent à de l’argent réellement dépensé.',
    'The loan will be removed, but its linked expenses stay in your history '
        '— they are money you really spent.',
  );

  // Expense → loan link
  String get expenseIsLoanPayment =>
      _s('Je rembourse un prêt', 'This repays a loan');
  String get expenseChooseLoan => _s('Choisir le prêt', 'Choose the loan');
  String get expenseNoLoanYet => _s(
    'Vous n’avez aucun prêt enregistré. Créez-en un pour lier ce paiement, '
        'ou décochez la case pour enregistrer une dépense simple.',
    'You have no loans yet. Create one to link this payment, or untick the '
        'box to record a plain expense.',
  );
  String get expenseUntickLoan => _s('Décocher', 'Untick');
  String get expenseLoanToggleHint => _s(
    'Activez pour imputer cette dépense à un prêt',
    'Turn on to count this expense towards a loan',
  );
  String get expenseLoanRequired => _s(
    'Sélectionnez le prêt remboursé, ou décochez « Je rembourse un prêt » '
        'pour enregistrer une dépense simple.',
    'Select the loan being repaid, or untick “This repays a loan” to record '
        'a plain expense.',
  );

  // ---------------------------------------------------- Onboarding
  String get onbSkip => _s('Passer', 'Skip');
  String get onbNext => _s('Suivant', 'Next');
  String get onbStart => _s('Commencer', 'Get started');
  String get onb1Title => _s('Maîtrisez vos finances', 'Master your finances');
  String get onb1Body => _s(
    'Suivez vos revenus et dépenses en un coup d\'œil.',
    'Track your income and expenses at a glance.',
  );
  String get onb2Title => _s('Budgets intelligents', 'Smart budgets');
  String get onb2Body => _s(
    'Fixez des budgets et recevez des alertes en temps réel.',
    'Set budgets and get real-time alerts.',
  );
  String get onb3Title => _s('Assistant IA', 'AI Assistant');
  String get onb3Body => _s(
    'Posez des questions et obtenez des conseils personnalisés.',
    'Ask questions and get personalized advice.',
  );
  String get onb4Title => _s('Sécurité bancaire', 'Bank-grade security');
  String get onb4Body => _s(
    'Vos données sont chiffrées et protégées.',
    'Your data is encrypted and protected.',
  );

  // ---------------------------------------------------------- Auth
  String get appTagline => _s(
    'Gérez. Épargnez. Atteignez vos objectifs.',
    'Manage. Save. Reach your goals.',
  );
  String get featSecure => _s('Sécurisé', 'Secure');
  String get featConfidential => _s('Confidentiel', 'Private');
  String get featSmart => _s('Intelligent', 'Smart');
  String get featSecureBody => _s('Données protégées', 'Data protected');
  String get featPrivateBody =>
      _s('Confidentiel et privé', 'Private and confidential');
  String get featSmartBody =>
      _s('Conseils intelligents', 'Smart financial insights');
  String get loginWelcome => _s('Bon retour !', 'Welcome back!');
  String get loginSubtitle => _s(
    'Connectez-vous pour poursuivre votre chemin vers la liberté financière.',
    'Sign in to continue your journey towards financial freedom.',
  );
  String get authSecurityTitle =>
      _s('Protection de niveau bancaire', 'Bank-grade protection');
  String get chooseSignInMethod => _s(
    'Comment souhaitez-vous vous connecter ?',
    'How would you like to sign in?',
  );
  String get chooseSignInMethodBody => _s(
    'Choisissez la méthode qui vous convient. Vous pourrez la modifier à tout moment.',
    'Choose the method that works best for you. You can use either one anytime.',
  );
  String get signInWithEmail =>
      _s('Continuer avec vos identifiants', 'Continue with your credentials');
  String get signInWithEmailBody => _s(
    'Utilisez votre adresse e-mail et votre mot de passe',
    'Use your email address and password',
  );
  String get signInWithGoogleBody => _s(
    'Connectez-vous rapidement avec votre compte Google',
    'Sign in quickly with your Google account',
  );
  String get backToSignInOptions =>
      _s('Choisir une autre méthode', 'Choose another sign-in method');
  String get loginSecure =>
      _s('Connexion sécurisée & chiffrée', 'Secure & encrypted connection');
  String get email => _s('Email', 'Email');
  String get emailAddress => _s('Adresse e-mail', 'Email address');
  String get emailHint =>
      _s('Entrez votre adresse e-mail', 'Enter your email address');
  String get password => _s('Mot de passe', 'Password');
  String get passwordHint =>
      _s('Entrez votre mot de passe', 'Enter your password');
  String get emailInvalid => _s('Email invalide', 'Invalid email');
  String get signIn => _s('Se connecter', 'Sign in');
  String get signInFailed => _s('Connexion impossible', 'Sign-in failed');
  String get rememberMe => _s('Se souvenir de moi', 'Remember me');
  String get forgotPassword => _s('Mot de passe oublié ?', 'Forgot password?');
  String get forgotTitle => _s('Mot de passe oublié', 'Forgot password');
  String get forgotBody => _s(
    'Entrez votre email pour recevoir un code de réinitialisation.',
    'Enter your email to receive a reset code.',
  );
  String get forgotSent => _s(
    'Si ce compte existe, un code a été envoyé par email.',
    'If the account exists, a code has been sent by email.',
  );
  String get continueWith => _s('ou continuer avec', 'or continue with');
  String get continueWithGoogle =>
      _s('Continuer avec Google', 'Continue with Google');
  String get comingSoon => _s('Bientôt disponible', 'Coming soon');
  String get bankGrade => _s(
    'Vos données sont protégées avec un chiffrement de niveau bancaire.',
    'Your data is protected with bank-grade encryption.',
  );
  String get noAccount =>
      _s('Vous n\'avez pas de compte ?', 'Don\'t have an account?');
  String get haveAccount =>
      _s('Vous avez déjà un compte ?', 'Already have an account?');
  String get signUp => _s('S\'inscrire', 'Sign up');
  String get createAccount => _s('Créer un compte', 'Create account');
  String get createTitlePrefix => _s('Créer votre ', 'Create your ');
  String get createTitleAccent => _s('compte', 'account');
  String get registerSubtitle => _s(
    'Rejoignez Fynexa et prenez le contrôle de vos finances.',
    'Join Fynexa and take control of your finances.',
  );
  String get chooseSignUpMethod => _s(
    'Comment souhaitez-vous créer votre compte ?',
    'How would you like to create your account?',
  );
  String get chooseSignUpMethodBody => _s(
    'Renseignez vos informations ou utilisez Google pour commencer plus rapidement.',
    'Enter your information or use Google to get started faster.',
  );
  String get signUpWithDetails =>
      _s('Renseigner mes informations', 'Enter my information');
  String get signUpWithDetailsBody => _s(
    'Créez votre profil avec une adresse e-mail et un mot de passe',
    'Create your profile with an email address and password',
  );
  String get signUpWithGoogleBody => _s(
    'Créez votre compte en quelques secondes avec Google',
    'Create your account in seconds with Google',
  );
  String get backToSignUpOptions =>
      _s('Choisir une autre méthode', 'Choose another sign-up method');
  String get regFeat1Title => _s('Sécurisé', 'Secure');
  String get regFeat1Body =>
      _s('Vos données sont protégées', 'Your data is protected');
  String get regFeat2Title => _s('Intelligent', 'Smart');
  String get regFeat2Body => _s(
    'Analyses et conseils personnalisés',
    'Personalized insights & advice',
  );
  String get regFeat3Title => _s('Rapide', 'Fast');
  String get regFeat3Body =>
      _s('Inscription en moins d\'une minute', 'Sign up in under a minute');
  String get stepInfo => _s('Informations', 'Details');
  String get stepVerify => _s('Vérification', 'Verification');
  String get stepReady => _s('Prêt !', 'Ready!');
  String get firstName => _s('Prénom', 'First name');
  String get firstNameHint =>
      _s('Entrez votre prénom', 'Enter your first name');
  String get lastName => _s('Nom', 'Last name');
  String get lastNameHint => _s('Entrez votre nom', 'Enter your last name');
  String get createPasswordHint =>
      _s('Créez un mot de passe', 'Create a password');
  String get confirmPasswordHint =>
      _s('Confirmez votre mot de passe', 'Confirm your password');
  String get pwStrength => _s('Sécurité :', 'Strength:');
  String get pwWeak => _s('Faible', 'Weak');
  String get pwMedium => _s('Moyen', 'Medium');
  String get pwStrong => _s('Fort', 'Strong');
  String get preferredCurrency => _s('Devise préférée', 'Preferred currency');
  String get countryOfResidence =>
      _s('Pays de résidence', 'Country of residence');
  String get selectCountry =>
      _s('Sélectionnez votre pays', 'Select your country');
  String get acceptPrefix => _s('J\'accepte les ', 'I accept the ');
  String get termsOfUse => _s('Conditions d\'utilisation', 'Terms of Use');
  String get acceptMiddle => _s(' et la ', ' and the ');
  String get privacyPolicy =>
      _s('Politique de confidentialité', 'Privacy Policy');
  String get mustAcceptTerms =>
      _s('Veuillez accepter les conditions.', 'Please accept the terms.');
  String get createMyAccount => _s('Créer mon compte', 'Create my account');
  String get verifyTitle => _s('Vérifiez votre email', 'Verify your email');
  String get verifyBody => _s(
    'Entrez le code à 6 chiffres envoyé à',
    'Enter the 6-digit code sent to',
  );
  String get verifyResend => _s('Renvoyer le code', 'Resend code');
  String get verify => _s('Vérifier', 'Verify');

  // Verification screen
  String get verifyHeadline =>
      _s('Confirmez votre adresse', 'Confirm your address');
  String get verifyIntro => _s(
    'Nous avons envoyé un code à 6 chiffres à',
    'We sent a 6-digit code to',
  );
  String get verifyCheckSpam => _s(
    'Pensez à vérifier vos courriers indésirables.',
    'Remember to check your spam folder.',
  );
  String verifyExpiresIn(String mmss) =>
      _s('Expire dans $mmss', 'Expires in $mmss');
  String get verifyExpired =>
      _s('Ce code a expiré', 'This code has expired');
  String verifyAttemptsLeft(int n) => _s(
    n > 1 ? '$n tentatives restantes' : 'Dernière tentative',
    n > 1 ? '$n attempts left' : 'Last attempt',
  );
  String get verifyLocked => _s(
    'Trop de tentatives. Demandez un nouveau code.',
    'Too many attempts. Request a new code.',
  );
  String get verifyWrongCode => _s('Code incorrect', 'Incorrect code');
  String get verifyNoCode =>
      _s('Aucun code actif. Renvoyez-en un.', 'No active code. Request a new one.');
  String verifyResendIn(String mmss) =>
      _s('Renvoyer dans $mmss', 'Resend in $mmss');
  String verifyResendsLeft(int n) => _s(
    n > 1 ? '$n renvois restants cette heure' : '1 renvoi restant cette heure',
    n > 1 ? '$n resends left this hour' : '1 resend left this hour',
  );
  String get verifyResendLimit => _s(
    'Limite de renvois atteinte. Réessayez plus tard.',
    'Resend limit reached. Try again later.',
  );
  String get verifyCodeSent =>
      _s('Nouveau code envoyé', 'New code sent');
  String get verifySuccess =>
      _s('Adresse confirmée', 'Address confirmed');
  String get verifyWrongAddress =>
      _s('Ce n’est pas votre adresse ?', 'Not your address?');
  String get verifyChangeAccount =>
      _s('Utiliser un autre compte', 'Use another account');

  // Password reset
  String get resetHeadline =>
      _s('Nouveau mot de passe', 'New password');
  String get resetIntro => _s(
    'Saisissez le code reçu par e-mail, puis choisissez votre nouveau mot de passe.',
    'Enter the code we e-mailed you, then choose your new password.',
  );
  String get resetNewPassword =>
      _s('Nouveau mot de passe', 'New password');
  String get resetConfirmPassword =>
      _s('Confirmez le mot de passe', 'Confirm password');
  String get resetMismatch =>
      _s('Les mots de passe ne correspondent pas', 'Passwords do not match');
  String get resetTooShort => _s(
    'Au moins 8 caractères, avec une majuscule et un chiffre',
    'At least 8 characters, with an uppercase letter and a digit',
  );
  String get resetAction =>
      _s('Réinitialiser', 'Reset password');
  String get resetDone => _s(
    'Mot de passe réinitialisé. Connectez-vous.',
    'Password reset. Please sign in.',
  );
  String get resetSessionsRevoked => _s(
    'Toutes vos autres sessions ont été déconnectées.',
    'All your other sessions have been signed out.',
  );

  // Verification banner / badge
  String verifyBannerTitle(int days) => _s(
    days > 1
        ? 'Confirmez votre e-mail sous $days jours'
        : 'Dernier jour pour confirmer votre e-mail',
    days > 1
        ? 'Confirm your e-mail within $days days'
        : 'Last day to confirm your e-mail',
  );
  String get verifyBannerBody => _s(
    'Sans confirmation, vous ne pourrez plus vous connecter ni réinitialiser '
        'votre mot de passe.',
    'Without it you will not be able to sign in, or reset your password.',
  );
  String get verifyBannerCta => _s('Confirmer maintenant', 'Confirm now');
  String get verifyBannerLater => _s('Plus tard', 'Later');
  String get emailVerifiedBadge => _s('Vérifié', 'Verified');
  String get emailUnverifiedBadge => _s('Non vérifié', 'Not verified');

  // ---------------------------------------------------- App lock
  String get lockTitle => _s('Application verrouillée', 'App locked');
  String get lockSubtitle => _s(
    'Authentifiez-vous pour accéder à vos finances',
    'Authenticate to access your finances',
  );
  String get unlock => _s('Déverrouiller', 'Unlock');
  String get unlockReason =>
      _s('Déverrouillez Fynexa pour continuer', 'Unlock Fynexa to continue');

  // ---------------------------------------------------- Dashboard
  String greeting(String name) => _s('Bonjour $name 👋', 'Hello $name 👋');
  String get dashSubtitle => _s(
    'Voici un aperçu de vos finances.',
    'Here\'s an overview of your finances.',
  );
  String get overview => _s('Vue d\'ensemble', 'Overview');
  String get income => _s('Revenus', 'Income');
  String get expenses => _s('Dépenses', 'Expenses');
  String get netSavings => _s('Épargne nette', 'Net savings');
  String get savingsRate => _s('Taux d\'épargne', 'Savings rate');
  String get budgetAlerts => _s('Alertes budgets', 'Budget alerts');
  String get spendingByCategory =>
      _s('Dépenses par catégorie', 'Spending by category');
  String get viewDetail => _s('Voir le détail', 'View details');
  String get incomeVsExpenses =>
      _s('Revenus vs Dépenses', 'Income vs Expenses');
  String get viewReport => _s('Voir le rapport', 'View report');
  String get aiInsights => _s('Insights IA', 'AI Insights');
  String get recentTransactions =>
      _s('Transactions récentes', 'Recent transactions');
  String vsMonth(String month) => _s('vs $month', 'vs $month');
  String get stable => _s('stable', 'stable');

  // Insight builders
  String savedMore(int pct, String month) => _s(
    'Vous avez épargné $pct% de plus qu\'en $month.',
    'You saved $pct% more than in $month.',
  );
  String savingsDropped(int pct, String month) => _s(
    'Votre épargne a baissé de $pct% vs $month.',
    'Your savings dropped $pct% vs $month.',
  );
  String budgetExceeded(String cat, String amount) => _s(
    '$cat dépassé. Dépassement de $amount.',
    '$cat exceeded. Over by $amount.',
  );
  String budgetNearLimit(String cat, String amount) => _s(
    '$cat presque dépassé. Il reste $amount.',
    '$cat almost exceeded. $amount left.',
  );
  String savingTip(String cat, String amount) => _s(
    'Réduisez vos dépenses en $cat et économisez jusqu\'à $amount.',
    'Cut your $cat spending and save up to $amount.',
  );

  // ---------------------------------------------------- Finances
  String get expensesTab => _s('Dépenses', 'Expenses');
  String get incomeTab => _s('Revenus', 'Income');
  String get totalExpenses => _s('Dépenses totales', 'Total expenses');
  String get totalIncome => _s('Revenus totaux', 'Total income');
  String get vsPrevPeriod => _s('vs période préc.', 'vs prev. period');
  String get distributionByCategory =>
      _s('Répartition par catégorie', 'Breakdown by category');
  String get avgPerDay => _s('Dépense moyenne / jour', 'Average / day');
  String get avgPerMonth => _s('Revenu moyen / mois', 'Average / month');
  String get daysLeft => _s('Jours restants', 'Days left');
  String get days => _s('jours', 'days');
  String get expenseAnalysis => _s('Analyse des dépenses', 'Expense analysis');
  String get incomeAnalysis => _s('Analyse des revenus', 'Income analysis');
  String get transactions => _s('Transactions', 'Transactions');
  String opsCount(int n) => _s('$n opérations', '$n transactions');
  String get choosePeriod => _s('Choisir la période', 'Choose period');
  String get customPeriod => _s('Période personnalisée', 'Custom range');
  String noneForPeriod(String kind) =>
      _s('Aucune $kind sur cette période', 'No $kind for this period');
  String get expenseWord => _s('dépense', 'expense');
  String get incomeWord => _s('revenu', 'income');
  String addExpense() => _s('Ajouter une dépense', 'Add an expense');
  String addIncome() => _s('Ajouter un revenu', 'Add income');

  // Finance analysis builders
  String spendLess(int pct) => _s(
    'Vous dépensez $pct% de moins que la période précédente.',
    'You\'re spending $pct% less than last period.',
  );
  String spendMore(int pct) => _s(
    'Vous dépensez $pct% de plus que la période précédente.',
    'You\'re spending $pct% more than last period.',
  );
  String incomeDown(int pct) => _s(
    'Vos revenus ont baissé de $pct% vs la période précédente.',
    'Your income dropped $pct% vs last period.',
  );
  String incomeUp(int pct) => _s(
    'Vos revenus ont augmenté de $pct% vs la période précédente.',
    'Your income rose $pct% vs last period.',
  );
  String categoryWeight(String cat, int pct, bool isIncome) => isIncome
      ? _s(
          '$cat représente $pct% de vos revenus.',
          '$cat is $pct% of your income.',
        )
      : _s(
          '$cat représente $pct% de vos dépenses.',
          '$cat is $pct% of your spending.',
        );
  String diversifyTip(String cat) => _s(
    'Diversifiez vos sources au-delà de $cat pour plus de stabilité.',
    'Diversify beyond $cat for more stability.',
  );

  // ---------------------------------------------------- Budgets
  String get budgetsAndGoals => _s('Budgets & Objectifs', 'Budgets & Goals');
  String get monthBudget => _s('Budget du mois', 'Monthly budget');
  String get onOf => _s('sur', 'of');
  String get byCategory => _s('Par catégorie', 'By category');
  String get noBudget =>
      _s('Aucun budget défini pour ce mois', 'No budget set for this month');
  String get setBudget => _s('Définir un budget', 'Set a budget');
  String get editBudget => _s('Modifier le budget', 'Edit budget');
  String get monthlyAmount => _s('Montant mensuel', 'Monthly amount');
  String get category => _s('Catégorie', 'Category');
  String get selectCategory => _s('Choisir une catégorie', 'Choose a category');
  String get amount => _s('Montant', 'Amount');
  String get chooseCategory =>
      _s('Choisissez une catégorie', 'Choose a category');
  String get invalidAmount => _s('Montant invalide', 'Invalid amount');
  String get statusExceeded => _s('Dépassé', 'Exceeded');
  String get statusCritical => _s('Critique', 'Critical');
  String get statusWarning => _s('Attention', 'Warning');
  String get statusOk => _s('En bonne voie', 'On track');
  String get spentWord => _s('dépensé', 'spent');
  String spentLabel(String amount) => _s('$amount dépensés', '$amount spent');
  String remainingLabel(String amount) =>
      _s('$amount restants', '$amount left');
  String overLabel(String amount) => _s('$amount de trop', '$amount over');

  // Overall (month-wide) budget — every expense counts against it.
  String get budgetOverallTitle =>
      _s('Budget global du mois', 'Overall monthly budget');
  String get budgetOverallSubtitle => _s(
    'Toutes vos dépenses du mois y sont comptées, quelle que soit la catégorie.',
    'Every expense of the month counts against it, whatever its category.',
  );
  String get budgetOverallNone =>
      _s('Aucun budget global', 'No overall budget');
  String get budgetOverallNoneBody => _s(
    'Fixez un plafond pour le mois entier et suivez tout ce que vous dépensez, '
        'même hors des catégories que vous surveillez.',
    'Set a cap for the whole month and track everything you spend, even '
        'outside the categories you watch.',
  );
  String get budgetSetOverall =>
      _s('Définir le budget du mois', 'Set the monthly budget');
  String get budgetEditOverall =>
      _s('Modifier le budget du mois', 'Edit the monthly budget');

  // Tabs
  String get budgetTabCategories => _s('Par catégorie', 'By category');
  String get budgetTabMonth => _s('Mois entier', 'Whole month');

  // Category coverage — deliberately NOT called "the month's budget".
  String get budgetCoverageTitle =>
      _s('Budget total des catégories', 'Total category budget');
  String budgetCoverageCount(int n) =>
      _s('$n catégorie${n > 1 ? 's' : ''}', '$n categor${n > 1 ? 'ies' : 'y'}');
  String get budgetCoverageHint => _s(
    'Somme de vos plafonds par catégorie — ce n’est pas le budget du mois.',
    'The sum of your category caps — not the month’s budget.',
  );
  String budgetUnwatched(String amount) => _s(
    '$amount dépensés hors budget catégorie',
    '$amount spent outside any category budget',
  );

  // Pacing
  String get budgetPaceLabel => _s('Rythme', 'Pace');
  String budgetPaceExpected(int percent) =>
      _s('Rythme régulier : $percent%', 'Even pace: $percent%');
  String get budgetAheadOfPace => _s(
    'Vous dépensez plus vite que prévu',
    'You are spending faster than planned',
  );
  String get budgetOnPace => _s('Dans les temps', 'On pace');
  String budgetDaysLeft(int n) => _s(
    '$n jour${n > 1 ? 's' : ''} restant${n > 1 ? 's' : ''}',
    '$n day${n > 1 ? 's' : ''} left',
  );
  String budgetSafeDaily(String amount) =>
      _s('$amount / jour possible', '$amount / day available');
  String get budgetMonthClosed => _s('Mois clôturé', 'Month closed');

  // Repetition
  String get budgetAppliesTo => _s('S’applique à', 'Applies to');
  String get budgetKindOverall => _s('Tout le mois', 'The whole month');
  String get budgetKindCategory => _s('Une catégorie', 'One category');
  String get budgetRepeat => _s('Répéter sur', 'Repeat for');
  String budgetRepeatMonths(int n) =>
      _s('$n mois', '$n month${n > 1 ? 's' : ''}');
  // Short on purpose: this label shares a row with three others, so anything
  // longer overflows its chip.
  String get budgetRepeatOnce => _s('Ce mois', 'This month');
  String get budgetRepeatHint => _s(
    'Chaque mois reste indépendant : modifier ou dépasser un mois ne change '
        'pas l’historique des autres.',
    'Each month stays independent: editing or overspending one never changes '
        'the others.',
  );
  String get budgetRepeatingBadge => _s('Récurrent', 'Repeating');
  String get budgetDeleteSeries => _s(
    'Supprimer aussi les mois suivants',
    'Also delete the following months',
  );
  String get budgetDeleteThisMonth =>
      _s('Ce mois seulement', 'This month only');
  String budgetAppliedTo(int n) => _s(
    'Budget appliqué sur $n mois',
    'Budget applied to $n month${n > 1 ? 's' : ''}',
  );

  // ---------------------------------------------------- AI
  String get aiAssistant => _s('Assistant', 'Assistant');
  String get aiForecast => _s('Prévisions', 'Forecast');
  String get aiAssistantTitle => _s('Assistant Fynexa', 'Fynexa Assistant');
  String get aiIntro => _s(
    'Posez une question sur vos finances.\nJe lis vos données en toute sécurité.',
    'Ask a question about your finances.\nI read your data securely.',
  );
  String get clearChat => _s('Effacer la conversation', 'Clear conversation');
  String get aiThinking => _s('Analyse en cours…', 'Thinking…');
  String get aiMessageHint => _s('Message…', 'Message…');
  String get copy => _s('Copier', 'Copy');
  String get aiSuggest1 => _s(
    'Combien ai-je dépensé ce mois-ci ?',
    'How much did I spend this month?',
  );
  String get aiSuggest2 =>
      _s('Quelle est ma plus grosse dépense ?', 'What\'s my biggest expense?');
  String get aiSuggest3 =>
      _s('Puis-je épargner 100 000 FCFA ?', 'Can I save 100,000 FCFA?');
  String get aiSuggest4 =>
      _s('Comment réduire mes dépenses ?', 'How can I cut my spending?');
  String get forecastModels =>
      _s('Modèles ML sélectionnés', 'Selected ML models');
  String get horizon30 => _s('30 jours', '30 days');
  String get horizon60 => _s('60 jours', '60 days');
  String get horizon90 => _s('90 jours', '90 days');
  String get projectedIncome => _s('Revenus prévus', 'Projected income');
  String get projectedExpenses => _s('Dépenses prévues', 'Projected expenses');
  String get projectedSavings => _s('Épargne prévue', 'Projected savings');
  String get projectedBalance => _s('Solde projeté', 'Projected balance');
  String get cashflow => _s('Solde de trésorerie', 'Cash flow');
  String get real => _s('Réel', 'Actual');
  String get forecastWord => _s('Prévision', 'Forecast');
  String get alerts => _s('Alertes', 'Alerts');
  String get objectives => _s('Objectifs', 'Objectives');
  String get suggestions => _s('Suggestions', 'Suggestions');
  String get seeSuggestions => _s('Voir suggestions', 'See suggestions');
  String get aiSuggestionTitle =>
      _s('Conseil personnalisé', 'Personalised advice');

  // ---------------------------------------------------- Settings
  String get appearance => _s('Apparence', 'Appearance');
  String get theme => _s('Thème', 'Theme');
  String get themeLight => _s('Clair', 'Light');
  String get themeDark => _s('Sombre', 'Dark');
  String get themeSystem => _s('Système', 'System');
  String get preferences => _s('Préférences', 'Preferences');
  String get language => _s('Langue', 'Language');
  String get langFrench => _s('Français', 'French');
  String get langEnglish => _s('Anglais', 'English');
  String get notificationsPref => _s('Notifications', 'Notifications');
  String get notificationsPermissionDenied => _s(
    'Autorisation refusée. Activez les notifications dans les réglages du téléphone.',
    'Permission denied. Enable notifications in your phone settings.',
  );
  String get emailNotifications =>
      _s('Notifications par email', 'Email notifications');
  String get aiAssistantPref => _s('Assistant IA', 'AI Assistant');
  String get aiOnSubtitle => _s(
    'Activé · vos données pertinentes peuvent être analysées par le fournisseur IA choisi',
    'On · relevant data may be analysed by your selected AI provider',
  );
  String get aiOffSubtitle => _s(
    'Désactivé · aucune donnée n’est envoyée aux fournisseurs IA',
    'Off · no data is sent to AI providers',
  );
  String get aiDisabledTitle =>
      _s('L’assistant IA est désactivé', 'AI Assistant is off');
  String get aiDisabledBody => _s(
    'Activez-le uniquement si vous souhaitez que Fynexa utilise vos données financières pertinentes pour créer des analyses, des prévisions et des réponses personnalisées.',
    'Enable it only if you want Fynexa to use relevant financial data to create personalised insights, forecasts and answers.',
  );
  String get aiEnableAction =>
      _s('Voir et activer l’IA', 'Review and enable AI');
  String get aiConsentTitle =>
      _s('Activer l’assistant IA ?', 'Enable AI Assistant?');
  String get aiConsentIntro => _s(
    'L’IA est facultative et désactivée par défaut. Voici ce qui se passe si vous l’activez.',
    'AI is optional and off by default. Here is what happens if you enable it.',
  );
  String get aiConsentDataTitle =>
      _s('Données financières utilisées', 'Financial data used');
  String get aiConsentDataBody => _s(
    'Les informations utiles à votre demande — notamment les titres et descriptions de transactions, montants, catégories, budgets et contexte financier — peuvent être envoyées pour produire le résultat.',
    'Information relevant to your request—including transaction titles and descriptions, amounts, categories, budgets and financial context—may be sent to produce the result.',
  );
  String get aiConsentProviderTitle =>
      _s('Traitement par un fournisseur tiers', 'Processed by a third party');
  String get aiConsentProviderBody => _s(
    'Ces données sont traitées par le fournisseur IA sélectionné, Google Gemini ou AgentRouter, et peuvent être traitées en dehors de votre pays.',
    'This data is processed by your selected AI provider, Google Gemini or AgentRouter, and may be processed outside your country.',
  );
  String get aiConsentControlTitle =>
      _s('Vous gardez le contrôle', 'You stay in control');
  String get aiConsentControlBody => _s(
    'Vous pouvez désactiver l’IA à tout moment. Une fois désactivée, les nouvelles demandes IA sont bloquées et aucune nouvelle donnée n’est envoyée.',
    'You can turn AI off at any time. Once off, new AI requests are blocked and no new data is sent.',
  );
  String get aiConsentAccuracy => _s(
    'Les réponses IA peuvent contenir des erreurs et ne constituent pas un conseil financier professionnel.',
    'AI responses may contain errors and are not professional financial advice.',
  );
  String get aiConsentCheckbox => _s(
    'Je comprends et j’accepte que mes données financières pertinentes soient traitées comme décrit ci-dessus afin d’utiliser les fonctions IA.',
    'I understand and agree that my relevant financial data will be processed as described above to use AI features.',
  );
  String get aiConsentPrivacy =>
      _s('Lire la politique de confidentialité', 'Read the Privacy Policy');
  String get aiConsentNotNow => _s('Pas maintenant', 'Not now');
  String get aiConsentEnabled =>
      _s('Assistant IA activé', 'AI Assistant enabled');
  String get aiDisabledSuccess =>
      _s('Assistant IA désactivé', 'AI Assistant disabled');
  String get aiProvider => _s('Fournisseur d\'IA', 'AI Provider');
  String get aiModel => _s('Modèle', 'Model');
  String get aiModelSaved => _s('Modèle IA enregistré', 'AI model saved');
  String get aiModelGeminiDesc => _s(
    'Google Gemini — rapide, idéal pour un usage quotidien.',
    'Google Gemini — fast, great for everyday use.',
  );
  String get aiModelAgentRouterDesc => _s(
    'AgentRouter (Claude Opus) — réponses plus poussées. À utiliser si Gemini a atteint son quota.',
    'AgentRouter (Claude Opus) — deeper answers. Use if Gemini hits its quota.',
  );
  String get management => _s('Gestion', 'Management');
  String get security => _s('Sécurité', 'Security');
  String biometricUnlock(String method) =>
      _s('Déverrouillage par ${method.toLowerCase()}', '$method unlock');
  String get biometricOnEach => _s(
    'Demandé à chaque ouverture de l\'application',
    'Required each time you open the app',
  );
  String biometricProtect(String method) =>
      _s('Protégez l\'accès avec $method', 'Protect access with $method');
  String get screenshotProtection =>
      _s('Protection des captures d\'écran', 'Screenshot protection');
  String get screenshotBlocked => _s(
    'Captures et enregistrements bloqués',
    'Screenshots and recording blocked',
  );
  String get changePassword => _s('Changer le mot de passe', 'Change password');
  String get account => _s('Compte', 'Account');
  String get logout => _s('Se déconnecter', 'Log out');
  String get editProfile => _s('Modifier le profil', 'Edit profile');
  String get emailReadOnly => _s('Email (non modifiable)', 'Email (read-only)');
  String get biometricUnavailable => _s(
    'Biométrie non disponible sur cet appareil',
    'Biometrics unavailable on this device',
  );
  // Change password
  String get currentPassword => _s('Mot de passe actuel', 'Current password');
  String get newPassword => _s('Nouveau mot de passe', 'New password');
  String get confirmPassword =>
      _s('Confirmer le mot de passe', 'Confirm password');
  String get passwordUpdated =>
      _s('Mot de passe mis à jour', 'Password updated');
  String get pwMin => _s('Au moins 8 caractères', 'At least 8 characters');
  String get pwUpper => _s('Ajoutez une majuscule', 'Add an uppercase letter');
  String get pwDigit => _s('Ajoutez un chiffre', 'Add a number');
  String get pwMismatch =>
      _s('Les mots de passe diffèrent', 'Passwords don\'t match');

  // ---------------------------------------------------- Notifications
  String get markAllRead => _s('Tout lire', 'Mark all read');
  String get noNotifications => _s('Aucune notification', 'No notifications');
  String get noNotificationsBody => _s(
    'Vos alertes de budget, bilans et conseils IA apparaîtront ici.',
    'Your budget alerts, summaries and AI tips will show up here.',
  );
  String get notifDeleteAll => _s('Tout supprimer', 'Delete all');
  String get notifDeleteAllTitle =>
      _s('Supprimer toutes les notifications ?', 'Delete all notifications?');
  String notifDeleteAllBody(int n) => _s(
    '$n notification${n > 1 ? 's' : ''} seront définitivement supprimées. '
        'Cette action est irréversible.',
    '$n notification${n > 1 ? 's' : ''} will be permanently deleted. '
        'This cannot be undone.',
  );
  String get notifDeleted =>
      _s('Notification supprimée', 'Notification deleted');
  String get notifAllDeleted =>
      _s('Notifications supprimées', 'Notifications deleted');
  String get notifFilterAll => _s('Toutes', 'All');
  String get notifFilterAlerts => _s('Alertes', 'Alerts');
  String get notifFilterTips => _s('Conseils', 'Tips');
  String get notifFilterInfo => _s('Infos', 'Info');
  String get notifNoneInFilter =>
      _s('Rien dans cette catégorie', 'Nothing in this category');
  String get notifUnreadOne => _s('non lue', 'unread');
  String get notifUnreadMany => _s('non lues', 'unread');

  // ---------------------------------------------------- Reports
  String get reportWeek => _s('Semaine', 'Week');
  String get reportMonth => _s('Mois', 'Month');
  String get reportYear => _s('Année', 'Year');
  String get reportCustom => _s('Perso', 'Custom');
  String get reportPickDates => _s('Choisir les dates', 'Pick dates');
  String get reportAllCategories =>
      _s('Toutes les catégories', 'All categories');
  String get clearFilter => _s('Effacer le filtre', 'Clear filter');
  String get reportCategory => _s('Catégorie', 'Category');
  String get reportNoData =>
      _s('Aucune donnée pour cette période.', 'No data for this period.');
  String get reportTransactionsStat => _s('Transactions', 'Transactions');
  String get reportAvgExpense => _s('Dépense moyenne', 'Avg. expense');
  String get reportDailyAvg => _s('Moyenne / jour', 'Daily average');
  String get reportLargest => _s('Plus grosse dépense', 'Largest expense');
  String get reportKeyFigures => _s('Chiffres clés', 'Key figures');
  String get reportBudgetTracking => _s('Suivi des budgets', 'Budget tracking');
  String get savings => _s('Épargne', 'Savings');
  String get budgetsRespected => _s('Budgets respectés', 'Budgets kept');
  String budgetsKept(int respected, int total) => _s(
    '$respected sur $total budgets tenus',
    '$respected of $total budgets kept',
  );

  // ---------------------------------------------------- Categories
  String get noCategory => _s('Aucune catégorie', 'No categories');
  String get newCategory => _s('Nouvelle', 'New');
  String get newCategoryTitle => _s('Nouvelle catégorie', 'New category');
  String get editCategory => _s('Modifier la catégorie', 'Edit category');
  String get name => _s('Nom', 'Name');
  String get icon => _s('Icône', 'Icon');
  String get color => _s('Couleur', 'Color');
  String get isDefault => _s('Par défaut', 'Default');
  String get nameRequired => _s('Nom requis', 'Name required');

  // ------------------------------------------------ Transaction sheet
  String newIncome() => _s('Nouveau revenu', 'New income');
  String newExpense() => _s('Nouvelle dépense', 'New expense');
  String editIncome() => _s('Modifier le revenu', 'Edit income');
  String editExpense() => _s('Modifier la dépense', 'Edit expense');
  String get title => _s('Intitulé', 'Title');
  String get titleHint => _s('Ex. Courses', 'E.g. Groceries');
  String get noteOptional => _s('Note (facultatif)', 'Note (optional)');
  String get date => _s('Date', 'Date');
  String get saveFailed => _s('Impossible d\'enregistrer', 'Could not save');
  String get addAction => _s('Ajouter', 'Add');
  String get addExpenseAction => _s('Ajouter la dépense', 'Add expense');
  String get addIncomeAction => _s('Ajouter le revenu', 'Add income');
  String get saveExpenseAction => _s('Enregistrer la dépense', 'Save expense');
  String get saveIncomeAction => _s('Enregistrer le revenu', 'Save income');
  String get noteHint => _s('Ex. Détails, rappel…', 'e.g. Details, reminder…');
  String get newObjective => _s('Nouvel objectif', 'New goal');
  String get objectiveSub =>
      _s('Épargne, projet, achat…', 'Savings, project, purchase…');
  String get incomeSub =>
      _s('Salaire, freelance, cadeau…', 'Salary, freelance, gift…');
  String get expenseSub =>
      _s('Courses, loyer, transport…', 'Groceries, rent, transport…');
  String get budgetSub =>
      _s('Plafond mensuel par catégorie', 'Monthly cap per category');

  // ------------------------------------------------ Offline / sync
  String get offlineQueued => _s(
    'Hors-ligne : enregistré, sera synchronisé automatiquement',
    'Offline: saved, will sync automatically',
  );
  String offlinePending(int n) => _s(
    'Hors-ligne · $n en attente de synchronisation',
    'Offline · $n waiting to sync',
  );
  String get offlineNoPending => _s(
    'Hors-ligne · les données seront synchronisées au retour du réseau',
    'Offline · data will sync when back online',
  );
  String syncing(int n) => _s(
    '$n opération${n > 1 ? 's' : ''} en cours de synchronisation…',
    '$n item${n > 1 ? 's' : ''} syncing…',
  );

  // ------------------------------------------------ Confirm dialogs
  String get deleteQuestion => _s('Supprimer ?', 'Delete?');
  String deleteBody(String title) => _s(
    '« $title » sera définitivement supprimé.',
    '"$title" will be permanently deleted.',
  );

  // ------------------------------------------ Category deletion warning
  String deleteCategoryTitle(String name) =>
      _s('Supprimer « $name » ?', 'Delete "$name"?');
  String get deleteCategoryEmpty => _s(
    'Cette catégorie ne contient aucune donnée. Elle sera supprimée définitivement.',
    'This category holds no data. It will be permanently deleted.',
  );
  String get deleteCategoryWarning => _s(
    'Tout ce qui est enregistré sous cette catégorie sera supprimé définitivement :',
    'Everything recorded under this category will be permanently deleted:',
  );
  String deleteCategoryExpenses(int n) =>
      _s('$n dépense${n > 1 ? 's' : ''}', '$n expense${n > 1 ? 's' : ''}');
  String deleteCategoryIncomes(int n) => _s(
    '$n revenu${n > 1 ? 's' : ''}',
    '$n income entr${n > 1 ? 'ies' : 'y'}',
  );
  String deleteCategoryBudgets(int n) =>
      _s('$n budget${n > 1 ? 's' : ''}', '$n budget${n > 1 ? 's' : ''}');
  String deleteCategoryRecurring(int n) => _s(
    '$n transaction${n > 1 ? 's' : ''} récurrente${n > 1 ? 's' : ''}',
    '$n recurring transaction${n > 1 ? 's' : ''}',
  );
  String get deleteCategoryIrreversible =>
      _s('Cette action est irréversible.', 'This action cannot be undone.');
  String get deleteCategoryDefaultNote => _s(
    'Catégorie par défaut — vous pouvez la supprimer si vous ne l’utilisez pas.',
    'Default category — you can remove it if you don’t use it.',
  );
  String deleteCategoryDone(String name) =>
      _s('« $name » supprimée', '"$name" deleted');

  // ------------------------------------------------- AI empty states
  String get aiNoDataTitle => _s('Pas encore de données', 'No data yet');
  String get aiNoDataDashboard => _s(
    'Ajoutez des revenus ou des dépenses pour débloquer votre analyse IA.',
    'Add income or expenses to unlock your AI analysis.',
  );
  String get aiNoDataExpense => _s(
    'Ajoutez des dépenses pour obtenir une analyse IA personnalisée.',
    'Add expenses to unlock personalised AI insights.',
  );
  String get aiNoDataIncome => _s(
    'Ajoutez des revenus pour obtenir une analyse IA personnalisée.',
    'Add income to unlock personalised AI insights.',
  );
  String get aiNoDataBudget => _s(
    'Définissez un budget par catégorie pour recevoir des conseils IA.',
    'Set a budget per category to receive AI recommendations.',
  );

  // --------------------------------------- Terms re-acceptance prompt
  String get termsUpdateTitle => _s('Conditions mises à jour', 'Updated terms');
  String get termsUpdateBody => _s(
    'Nous avons publié nos Conditions d’utilisation et notre Politique de '
        'confidentialité. Merci de les lire et de les accepter pour continuer '
        'à utiliser Fynexa.',
    'We have published our Terms of Use and Privacy Policy. Please read and '
        'accept them to continue using Fynexa.',
  );
  String get termsUpdateRead => _s('Appuyez pour lire :', 'Tap to read:');
  String get termsUpdateAcceptLabel => _s(
    'J’ai lu et j’accepte les Conditions d’utilisation et la Politique de confidentialité.',
    'I have read and accept the Terms of Use and Privacy Policy.',
  );
  String get termsUpdateAccept =>
      _s('Accepter et continuer', 'Accept and continue');
  String get termsUpdateMustRead => _s(
    'Ouvrez les deux documents avant d’accepter.',
    'Please open both documents before accepting.',
  );

  String get developedBy =>
      _s('Développé par YATE RONALD', 'Developed by YATE RONALD');

  // ------------------------------------------------- Account deletion
  String get deleteAccount => _s('Supprimer mon compte', 'Delete my account');
  String get deleteAccountSubtitle => _s(
    'Efface définitivement votre compte et toutes vos données',
    'Permanently erases your account and all your data',
  );
  String get dangerZone => _s('Zone sensible', 'Danger zone');

  // Step 1 — what will be lost
  String get deleteAccountStep1Title =>
      _s('Supprimer votre compte ?', 'Delete your account?');
  String get deleteAccountStep1Body => _s(
    'Tout sera effacé définitivement de nos serveurs. '
        'Cette action ne peut pas être annulée et vos données ne pourront pas être récupérées.',
    'Everything will be permanently erased from our servers. This cannot be '
        'undone and your data cannot be recovered.',
  );
  String deleteAccountCount(int n, String label) => '$n $label';
  String get deleteAccountExpenses => _s('dépenses', 'expenses');
  String get deleteAccountIncomes => _s('revenus', 'income entries');
  String get deleteAccountBudgets => _s('budgets', 'budgets');
  String get deleteAccountCategories => _s('catégories', 'categories');
  String get deleteAccountInsights => _s('analyses IA', 'AI insights');
  String get deleteAccountContinue => _s('Continuer', 'Continue');

  // Step 2 — typed confirmation
  String get deleteAccountStep2Title =>
      _s('Dernière confirmation', 'Final confirmation');

  /// The word the user must type. Kept uppercase and matched case-insensitively.
  String get deleteAccountKeyword => _s('SUPPRIMER', 'DELETE');
  String get deleteAccountStep2Body => _s(
    'Pour confirmer la suppression définitive, tapez SUPPRIMER ci-dessous.',
    'To confirm permanent deletion, type DELETE below.',
  );
  String get deleteAccountTypeHint => _s('Tapez SUPPRIMER', 'Type DELETE');
  String get deleteAccountMismatch =>
      _s('Le mot ne correspond pas', 'The word does not match');
  String get deleteAccountConfirmButton =>
      _s('Supprimer définitivement', 'Delete permanently');
  String get deleteAccountDoneTitle => _s('Compte supprimé', 'Account deleted');
  String get deleteAccountDone => _s(
    'Votre compte et toutes vos données ont été définitivement supprimés '
        'de nos serveurs.',
    'Your account and all your data have been completely deleted from our '
        'servers.',
  );
  String get backToLogin => _s('Retour à la connexion', 'Back to sign in');

  // --------------------------------------------------- First-run welcome
  String welcomeTitle(String? name) => (name == null || name.isEmpty)
      ? _s('Bienvenue sur Fynexa 👋', 'Welcome to Fynexa 👋')
      : _s('Bienvenue sur Fynexa, $name 👋', 'Welcome to Fynexa, $name 👋');
  String get welcomeBody => _s(
    'Vous venez de faire le premier pas vers des finances plus sereines. '
        'Enregistrez votre première dépense aujourd’hui : en quelques jours, '
        'votre tableau de bord et votre assistant IA commenceront à révéler '
        'vos habitudes.',
    'You’ve just taken the first step toward calmer finances. Record your '
        'first expense today — within a few days your dashboard and AI '
        'assistant will start revealing your habits, and helping you save.',
  );
  String get welcomeCta =>
      _s('Ajouter ma première dépense', 'Add my first expense');
  String get welcomeLater => _s('Plus tard', 'Later');
  String get welcomePoint1 =>
      _s('Notez vos dépenses en 30 secondes', 'Log an expense in 30 seconds');
  String get welcomePoint2 =>
      _s('Fixez des budgets et suivez-les', 'Set budgets and track them');
  String get welcomePoint3 => _s(
    'Recevez des conseils IA personnalisés',
    'Get personalised AI insights',
  );

  // ------------------------------------------------------ Google sign-in
  String get signUpWithGoogle =>
      _s('S’inscrire avec Google', 'Sign up with Google');
  String get orSeparator => _s('ou', 'or');
  String get googleNoAccountTitle =>
      _s('Aucun compte trouvé', 'No account found');
  String googleNoAccountBody(String email) => _s(
    'Aucun compte n’existe pour $email. Créez-en un — vous pourrez aussi '
        'vous inscrire avec Google.',
    'There is no account for $email yet. Create one — you can sign up with '
        'Google too.',
  );
  String get googleNoAccountCta => _s('Créer un compte', 'Create an account');
  String get googleAccountExistsTitle =>
      _s('Compte déjà existant', 'Account already exists');
  String googleAccountExistsBody(String email) => _s(
    'Un compte existe déjà pour $email. Connectez-vous à la place.',
    'An account already exists for $email. Sign in instead.',
  );
  String get googleAccountExistsCta => _s('Se connecter', 'Sign in');
  String get googleHasPasswordTitle =>
      _s('Ce compte a un mot de passe', 'This account has a password');
  String googleHasPasswordBody(String email) => _s(
    'Vous avez défini un mot de passe pour $email. Pour votre sécurité, '
        'la connexion Google n’est plus disponible sur ce compte : '
        'utilisez votre e-mail et votre mot de passe.',
    'You set a password for $email. For your security, Google sign-in is no '
        'longer available on this account — use your e-mail and password.',
  );
  String get googleHasPasswordCta =>
      _s('Se connecter avec le mot de passe', 'Sign in with password');
  String get setPasswordDisablesGoogle => _s(
    'Attention : une fois un mot de passe défini, la connexion Google ne '
        'fonctionnera plus sur ce compte. Vous pourrez toujours le '
        'réinitialiser par e-mail.',
    'Note: once you set a password, Google sign-in will no longer work on this '
        'account. You can always reset it by e-mail.',
  );
  String get googleUnavailable => _s(
    'Google Sign-In n’est pas disponible sur cet appareil.',
    'Google Sign-In is not available on this device.',
  );
  String get googleSetupError => _s(
    'Configuration Google incomplète pour cette application.',
    'Google sign-in is not configured for this app build.',
  );
  String get googleEmailUnverified => _s(
    'Votre adresse Google n’est pas vérifiée.',
    'Your Google email address is not verified.',
  );

  // ------------------------------------------------- Password / Google mix
  String get setPassword => _s('Définir un mot de passe', 'Set a password');
  String get setPasswordSubtitle => _s(
    'Votre compte utilise Google. Ajoutez un mot de passe pour pouvoir '
        'aussi vous connecter par e-mail — Google continuera de fonctionner.',
    'Your account uses Google. Add a password so you can also sign in with '
        'your email — Google keeps working either way.',
  );
  String get passwordSetDone => _s(
    'Mot de passe défini. Vous pouvez vous connecter par e-mail ou avec Google.',
    'Password set. You can sign in with your email or with Google.',
  );

  // --------------------------------------------- AI forecast data gate
  String get forecastNeedsDataTitle =>
      _s('Prévisions bientôt disponibles', 'Forecast not available yet');
  String get forecastNeedsDataBody => _s(
    'Les prévisions s’appuient sur votre historique. Ajoutez quelques '
        'transactions sur au moins deux mois et l’analyse se débloquera '
        'automatiquement.',
    'Forecasts are built from your history. Add a few transactions across '
        'at least two months and the analysis unlocks automatically.',
  );
  String forecastMonthsProgress(int have, int need) =>
      _s('$have/$need mois avec des données', '$have/$need months with data');
  String forecastTxProgress(int have, int need) => _s(
    '$have/$need transactions enregistrées',
    '$have/$need transactions recorded',
  );
  String forecastLowConfidence(int months) => _s(
    'Prévision basée sur $months mois d’historique — la précision '
        'augmentera avec le temps.',
    'Forecast based on $months months of history — accuracy improves over time.',
  );

  // ------------------------------------------ Biometric enrolment prompt
  String get biometricPromptTitle =>
      _s('Protéger l’application ?', 'Protect the app?');
  String get biometricPromptBody => _s(
    'Utilisez votre empreinte digitale pour déverrouiller Fynexa. '
        'Vos données financières restent privées même si votre téléphone est déverrouillé.',
    'Use your fingerprint to unlock Fynexa. Your financial data stays private '
        'even if someone else has your unlocked phone.',
  );
  String get biometricPromptEnable => _s('Activer', 'Enable');
  String get biometricPromptLater => _s('Plus tard', 'Not now');
  String get biometricEnabled =>
      _s('Verrouillage biométrique activé', 'Biometric lock enabled');
  String get biometricFailed => _s(
    'Impossible d’activer la biométrie. Réessayez depuis les Réglages.',
    'Could not enable biometrics. Try again from Settings.',
  );

  static AppText of(BuildContext context) =>
      Localizations.of<AppText>(context, AppText) ?? const AppText('fr');
}

class AppTextDelegate extends LocalizationsDelegate<AppText> {
  const AppTextDelegate();
  @override
  bool isSupported(Locale locale) => ['fr', 'en'].contains(locale.languageCode);
  @override
  Future<AppText> load(Locale locale) async => AppText(locale.languageCode);
  @override
  bool shouldReload(AppTextDelegate old) => false;
}

extension AppTextX on BuildContext {
  AppText get t => AppText.of(this);
}
