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
  String get genericError => _s('Une erreur est survenue', 'Something went wrong');
  String get noData => _s('Aucune donnée', 'No data');

  // ---------------------------------------------------------- Nav
  String get navHome => _s('Accueil', 'Home');
  String get navFinances => _s('Finances', 'Finances');
  String get navBudgets => _s('Budgets', 'Budgets');
  String get navAiShort => _s('IA', 'AI');
  String get titleHome => _s('Accueil', 'Home');
  String get titleFinances => _s('Finances', 'Finances');
  String get titleBudgets => _s('Budgets', 'Budgets');
  String get titleAi => _s('Assistant IA', 'AI Assistant');
  String get settings => _s('Réglages', 'Settings');
  String get reports => _s('Rapports', 'Reports');
  String get notifications => _s('Notifications', 'Notifications');
  String get categories => _s('Catégories', 'Categories');

  // ---------------------------------------------------- Onboarding
  String get onbSkip => _s('Passer', 'Skip');
  String get onbNext => _s('Suivant', 'Next');
  String get onbStart => _s('Commencer', 'Get started');
  String get onb1Title => _s('Maîtrisez vos finances', 'Master your finances');
  String get onb1Body => _s('Suivez vos revenus et dépenses en un coup d\'œil.',
      'Track your income and expenses at a glance.');
  String get onb2Title => _s('Budgets intelligents', 'Smart budgets');
  String get onb2Body => _s('Fixez des budgets et recevez des alertes en temps réel.',
      'Set budgets and get real-time alerts.');
  String get onb3Title => _s('Assistant IA', 'AI Assistant');
  String get onb3Body => _s('Posez des questions et obtenez des conseils personnalisés.',
      'Ask questions and get personalized advice.');
  String get onb4Title => _s('Sécurité bancaire', 'Bank-grade security');
  String get onb4Body => _s('Vos données sont chiffrées et protégées.',
      'Your data is encrypted and protected.');

  // ---------------------------------------------------------- Auth
  String get appTagline =>
      _s('Gérez. Épargnez. Atteignez vos objectifs.', 'Manage. Save. Reach your goals.');
  String get featSecure => _s('Sécurisé', 'Secure');
  String get featConfidential => _s('Confidentiel', 'Private');
  String get featSmart => _s('Intelligent', 'Smart');
  String get loginWelcome => _s('Bienvenue 👋', 'Welcome 👋');
  String get loginSubtitle =>
      _s('Connectez-vous à votre compte', 'Sign in to your account');
  String get loginSecure =>
      _s('Connexion sécurisée & chiffrée', 'Secure & encrypted connection');
  String get email => _s('Email', 'Email');
  String get emailAddress => _s('Adresse e-mail', 'Email address');
  String get emailHint => _s('Entrez votre adresse e-mail', 'Enter your email address');
  String get password => _s('Mot de passe', 'Password');
  String get passwordHint => _s('Entrez votre mot de passe', 'Enter your password');
  String get emailInvalid => _s('Email invalide', 'Invalid email');
  String get signIn => _s('Se connecter', 'Sign in');
  String get signInFailed => _s('Connexion impossible', 'Sign-in failed');
  String get rememberMe => _s('Se souvenir de moi', 'Remember me');
  String get forgotPassword => _s('Mot de passe oublié ?', 'Forgot password?');
  String get forgotTitle => _s('Mot de passe oublié', 'Forgot password');
  String get forgotBody => _s('Entrez votre email pour recevoir un code de réinitialisation.',
      'Enter your email to receive a reset code.');
  String get forgotSent => _s('Si ce compte existe, un code a été envoyé par email.',
      'If the account exists, a code has been sent by email.');
  String get continueWith => _s('ou continuer avec', 'or continue with');
  String get continueWithGoogle => _s('Continuer avec Google', 'Continue with Google');
  String get comingSoon => _s('Bientôt disponible', 'Coming soon');
  String get bankGrade => _s('Vos données sont protégées avec un chiffrement de niveau bancaire.',
      'Your data is protected with bank-grade encryption.');
  String get noAccount => _s('Vous n\'avez pas de compte ?', 'Don\'t have an account?');
  String get haveAccount => _s('Vous avez déjà un compte ?', 'Already have an account?');
  String get signUp => _s('S\'inscrire', 'Sign up');
  String get createAccount => _s('Créer un compte', 'Create account');
  String get createTitlePrefix => _s('Créer votre ', 'Create your ');
  String get createTitleAccent => _s('compte', 'account');
  String get registerSubtitle => _s('Rejoignez Fynexa et prenez le contrôle de vos finances.',
      'Join Fynexa and take control of your finances.');
  String get regFeat1Title => _s('Sécurisé', 'Secure');
  String get regFeat1Body => _s('Vos données sont protégées', 'Your data is protected');
  String get regFeat2Title => _s('Intelligent', 'Smart');
  String get regFeat2Body =>
      _s('Analyses et conseils personnalisés', 'Personalized insights & advice');
  String get regFeat3Title => _s('Rapide', 'Fast');
  String get regFeat3Body =>
      _s('Inscription en moins d\'une minute', 'Sign up in under a minute');
  String get stepInfo => _s('Informations', 'Details');
  String get stepVerify => _s('Vérification', 'Verification');
  String get stepReady => _s('Prêt !', 'Ready!');
  String get firstName => _s('Prénom', 'First name');
  String get firstNameHint => _s('Entrez votre prénom', 'Enter your first name');
  String get lastName => _s('Nom', 'Last name');
  String get lastNameHint => _s('Entrez votre nom', 'Enter your last name');
  String get createPasswordHint => _s('Créez un mot de passe', 'Create a password');
  String get confirmPasswordHint => _s('Confirmez votre mot de passe', 'Confirm your password');
  String get pwStrength => _s('Sécurité :', 'Strength:');
  String get pwWeak => _s('Faible', 'Weak');
  String get pwMedium => _s('Moyen', 'Medium');
  String get pwStrong => _s('Fort', 'Strong');
  String get preferredCurrency => _s('Devise préférée', 'Preferred currency');
  String get countryOfResidence => _s('Pays de résidence', 'Country of residence');
  String get selectCountry => _s('Sélectionnez votre pays', 'Select your country');
  String get acceptPrefix => _s('J\'accepte les ', 'I accept the ');
  String get termsOfUse => _s('Conditions d\'utilisation', 'Terms of Use');
  String get acceptMiddle => _s(' et la ', ' and the ');
  String get privacyPolicy => _s('Politique de confidentialité', 'Privacy Policy');
  String get mustAcceptTerms =>
      _s('Veuillez accepter les conditions.', 'Please accept the terms.');
  String get createMyAccount => _s('Créer mon compte', 'Create my account');
  String get verifyTitle => _s('Vérifiez votre email', 'Verify your email');
  String get verifyBody =>
      _s('Entrez le code à 6 chiffres envoyé à', 'Enter the 6-digit code sent to');
  String get verifyResend => _s('Renvoyer le code', 'Resend code');
  String get verify => _s('Vérifier', 'Verify');

  // ---------------------------------------------------- App lock
  String get lockTitle => _s('Application verrouillée', 'App locked');
  String get lockSubtitle => _s('Authentifiez-vous pour accéder à vos finances',
      'Authenticate to access your finances');
  String get unlock => _s('Déverrouiller', 'Unlock');
  String get unlockReason =>
      _s('Déverrouillez Fynexa pour continuer', 'Unlock Fynexa to continue');

  // ---------------------------------------------------- Dashboard
  String greeting(String name) => _s('Bonjour $name 👋', 'Hello $name 👋');
  String get dashSubtitle =>
      _s('Voici un aperçu de vos finances.', 'Here\'s an overview of your finances.');
  String get overview => _s('Vue d\'ensemble', 'Overview');
  String get income => _s('Revenus', 'Income');
  String get expenses => _s('Dépenses', 'Expenses');
  String get netSavings => _s('Épargne nette', 'Net savings');
  String get savingsRate => _s('Taux d\'épargne', 'Savings rate');
  String get budgetAlerts => _s('Alertes budgets', 'Budget alerts');
  String get spendingByCategory => _s('Dépenses par catégorie', 'Spending by category');
  String get viewDetail => _s('Voir le détail', 'View details');
  String get incomeVsExpenses => _s('Revenus vs Dépenses', 'Income vs Expenses');
  String get viewReport => _s('Voir le rapport', 'View report');
  String get aiInsights => _s('Insights IA', 'AI Insights');
  String get recentTransactions => _s('Transactions récentes', 'Recent transactions');
  String vsMonth(String month) => _s('vs $month', 'vs $month');
  String get stable => _s('stable', 'stable');

  // Insight builders
  String savedMore(int pct, String month) =>
      _s('Vous avez épargné $pct% de plus qu\'en $month.',
          'You saved $pct% more than in $month.');
  String savingsDropped(int pct, String month) =>
      _s('Votre épargne a baissé de $pct% vs $month.',
          'Your savings dropped $pct% vs $month.');
  String budgetExceeded(String cat, String amount) =>
      _s('$cat dépassé. Dépassement de $amount.', '$cat exceeded. Over by $amount.');
  String budgetNearLimit(String cat, String amount) =>
      _s('$cat presque dépassé. Il reste $amount.', '$cat almost exceeded. $amount left.');
  String savingTip(String cat, String amount) =>
      _s('Réduisez vos dépenses en $cat et économisez jusqu\'à $amount.',
          'Cut your $cat spending and save up to $amount.');

  // ---------------------------------------------------- Finances
  String get expensesTab => _s('Dépenses', 'Expenses');
  String get incomeTab => _s('Revenus', 'Income');
  String get totalExpenses => _s('Dépenses totales', 'Total expenses');
  String get totalIncome => _s('Revenus totaux', 'Total income');
  String get vsPrevPeriod => _s('vs période préc.', 'vs prev. period');
  String get distributionByCategory => _s('Répartition par catégorie', 'Breakdown by category');
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
  String spendLess(int pct) =>
      _s('Vous dépensez $pct% de moins que la période précédente.',
          'You\'re spending $pct% less than last period.');
  String spendMore(int pct) =>
      _s('Vous dépensez $pct% de plus que la période précédente.',
          'You\'re spending $pct% more than last period.');
  String incomeDown(int pct) => _s('Vos revenus ont baissé de $pct% vs la période précédente.',
      'Your income dropped $pct% vs last period.');
  String incomeUp(int pct) => _s('Vos revenus ont augmenté de $pct% vs la période précédente.',
      'Your income rose $pct% vs last period.');
  String categoryWeight(String cat, int pct, bool isIncome) => isIncome
      ? _s('$cat représente $pct% de vos revenus.', '$cat is $pct% of your income.')
      : _s('$cat représente $pct% de vos dépenses.', '$cat is $pct% of your spending.');
  String diversifyTip(String cat) =>
      _s('Diversifiez vos sources au-delà de $cat pour plus de stabilité.',
          'Diversify beyond $cat for more stability.');

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
  String get chooseCategory => _s('Choisissez une catégorie', 'Choose a category');
  String get invalidAmount => _s('Montant invalide', 'Invalid amount');
  String get statusExceeded => _s('Dépassé', 'Exceeded');
  String get statusCritical => _s('Critique', 'Critical');
  String get statusWarning => _s('Attention', 'Warning');
  String get statusOk => _s('En bonne voie', 'On track');
  String get spentWord => _s('dépensé', 'spent');
  String spentLabel(String amount) => _s('$amount dépensés', '$amount spent');
  String remainingLabel(String amount) => _s('$amount restants', '$amount left');
  String overLabel(String amount) => _s('$amount de trop', '$amount over');

  // ---------------------------------------------------- AI
  String get aiAssistant => _s('Assistant', 'Assistant');
  String get aiForecast => _s('Prévisions', 'Forecast');
  String get aiAssistantTitle => _s('Assistant Fynexa', 'Fynexa Assistant');
  String get aiIntro => _s('Posez une question sur vos finances.\nJe lis vos données en toute sécurité.',
      'Ask a question about your finances.\nI read your data securely.');
  String get clearChat => _s('Effacer la conversation', 'Clear conversation');
  String get aiThinking => _s('Analyse en cours…', 'Thinking…');
  String get aiMessageHint => _s('Message…', 'Message…');
  String get copy => _s('Copier', 'Copy');
  String get aiSuggest1 => _s('Combien ai-je dépensé ce mois-ci ?', 'How much did I spend this month?');
  String get aiSuggest2 =>
      _s('Quelle est ma plus grosse dépense ?', 'What\'s my biggest expense?');
  String get aiSuggest3 => _s('Puis-je épargner 100 000 FCFA ?', 'Can I save 100,000 FCFA?');
  String get aiSuggest4 => _s('Comment réduire mes dépenses ?', 'How can I cut my spending?');
  String get forecastModels => _s('Modèles ML sélectionnés', 'Selected ML models');
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
      'Permission denied. Enable notifications in your phone settings.');
  String get emailNotifications => _s('Notifications par email', 'Email notifications');
  String get aiAssistantPref => _s('Assistant IA', 'AI Assistant');
  String get aiProvider => _s('Fournisseur d\'IA', 'AI Provider');
  String get aiModel => _s('Modèle', 'Model');
  String get aiModelSaved =>
      _s('Modèle IA enregistré', 'AI model saved');
  String get aiModelGeminiDesc => _s(
      'Google Gemini — rapide, idéal pour un usage quotidien.',
      'Google Gemini — fast, great for everyday use.');
  String get aiModelAgentRouterDesc => _s(
      'AgentRouter (Claude Opus) — réponses plus poussées. À utiliser si Gemini a atteint son quota.',
      'AgentRouter (Claude Opus) — deeper answers. Use if Gemini hits its quota.');
  String get management => _s('Gestion', 'Management');
  String get security => _s('Sécurité', 'Security');
  String biometricUnlock(String method) =>
      _s('Déverrouillage par ${method.toLowerCase()}', '$method unlock');
  String get biometricOnEach =>
      _s('Demandé à chaque ouverture de l\'application', 'Required each time you open the app');
  String biometricProtect(String method) =>
      _s('Protégez l\'accès avec $method', 'Protect access with $method');
  String get screenshotProtection =>
      _s('Protection des captures d\'écran', 'Screenshot protection');
  String get screenshotBlocked =>
      _s('Captures et enregistrements bloqués', 'Screenshots and recording blocked');
  String get changePassword => _s('Changer le mot de passe', 'Change password');
  String get account => _s('Compte', 'Account');
  String get logout => _s('Se déconnecter', 'Log out');
  String get editProfile => _s('Modifier le profil', 'Edit profile');
  String get emailReadOnly => _s('Email (non modifiable)', 'Email (read-only)');
  String get biometricUnavailable =>
      _s('Biométrie non disponible sur cet appareil', 'Biometrics unavailable on this device');
  // Change password
  String get currentPassword => _s('Mot de passe actuel', 'Current password');
  String get newPassword => _s('Nouveau mot de passe', 'New password');
  String get confirmPassword => _s('Confirmer le mot de passe', 'Confirm password');
  String get passwordUpdated => _s('Mot de passe mis à jour', 'Password updated');
  String get pwMin => _s('Au moins 8 caractères', 'At least 8 characters');
  String get pwUpper => _s('Ajoutez une majuscule', 'Add an uppercase letter');
  String get pwDigit => _s('Ajoutez un chiffre', 'Add a number');
  String get pwMismatch => _s('Les mots de passe diffèrent', 'Passwords don\'t match');

  // ---------------------------------------------------- Notifications
  String get markAllRead => _s('Tout lire', 'Mark all read');
  String get noNotifications => _s('Aucune notification', 'No notifications');

  // ---------------------------------------------------- Reports
  String get reportWeek => _s('Semaine', 'Week');
  String get reportMonth => _s('Mois', 'Month');
  String get reportYear => _s('Année', 'Year');
  String get reportCustom => _s('Perso', 'Custom');
  String get reportPickDates => _s('Choisir les dates', 'Pick dates');
  String get reportAllCategories => _s('Toutes les catégories', 'All categories');
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
      '$respected sur $total budgets tenus', '$respected of $total budgets kept');

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
  String get newObjective => _s('Nouvel objectif', 'New goal');
  String get objectiveSub => _s('Épargne, projet, achat…', 'Savings, project, purchase…');
  String get incomeSub => _s('Salaire, freelance, cadeau…', 'Salary, freelance, gift…');
  String get expenseSub => _s('Courses, loyer, transport…', 'Groceries, rent, transport…');
  String get budgetSub => _s('Plafond mensuel par catégorie', 'Monthly cap per category');

  // ------------------------------------------------ Offline / sync
  String get offlineQueued => _s('Hors-ligne : enregistré, sera synchronisé automatiquement',
      'Offline: saved, will sync automatically');
  String offlinePending(int n) => _s('Hors-ligne · $n en attente de synchronisation',
      'Offline · $n waiting to sync');
  String get offlineNoPending => _s(
      'Hors-ligne · les données seront synchronisées au retour du réseau',
      'Offline · data will sync when back online');
  String syncing(int n) => _s('$n opération${n > 1 ? 's' : ''} en cours de synchronisation…',
      '$n item${n > 1 ? 's' : ''} syncing…');

  // ------------------------------------------------ Confirm dialogs
  String get deleteQuestion => _s('Supprimer ?', 'Delete?');
  String deleteBody(String title) =>
      _s('« $title » sera définitivement supprimé.', '"$title" will be permanently deleted.');

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
  String deleteCategoryIncomes(int n) =>
      _s('$n revenu${n > 1 ? 's' : ''}', '$n income entr${n > 1 ? 'ies' : 'y'}');
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
  String get deleteAccountTypeHint =>
      _s('Tapez SUPPRIMER', 'Type DELETE');
  String get deleteAccountMismatch =>
      _s('Le mot ne correspond pas', 'The word does not match');
  String get deleteAccountConfirmButton =>
      _s('Supprimer définitivement', 'Delete permanently');
  String get deleteAccountDoneTitle =>
      _s('Compte supprimé', 'Account deleted');
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
  String get welcomePoint3 =>
      _s('Recevez des conseils IA personnalisés', 'Get personalised AI insights');

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
  String forecastMonthsProgress(int have, int need) => _s(
        '$have/$need mois avec des données',
        '$have/$need months with data',
      );
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
