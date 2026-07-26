/// Traductions légères pour toute l'interface (FR / EN).
/// Les DONNÉES du backend (noms de lieux, descriptions) restent en français
/// car ce sont de vrais contenus, pas des textes d'interface.
class AppStrings {
  final String code; // 'fr' | 'en'
  const AppStrings(this.code);
  bool get isFr => code == 'fr';

  // ---------- Navigation ----------
  String get navExplore => isFr ? 'Explorer' : 'Explore';
  String get navForYou => isFr ? 'Pour vous' : 'For you';
  String get navTrips => isFr ? 'Sorties' : 'Trips';
  String get navProfile => isFr ? 'Profil' : 'Profile';

  // ---------- Explore ----------
  String get searchHint =>
      isFr ? 'Rechercher un lieu, un quartier…' : 'Search a place, a district…';
  String get noResults =>
      isFr ? 'Aucun lieu trouvé.' : 'No places found.';
  String get all => isFr ? 'Tout' : 'All';

  // ---------- Dashboard header ----------
  String greeting(String name) =>
      isFr ? 'Bonjour, $name 👋' : 'Hello, $name 👋';
  String get dashSubtitle =>
      isFr ? 'Où sortons-nous aujourd\'hui ?' : 'Where are we going today?';
  String get statPlaces => isFr ? 'Lieux' : 'Places';
  String get statCategories => isFr ? 'Catégories' : 'Categories';
  String get statTrips => isFr ? 'Vos sorties' : 'Your trips';

  // ---------- Recommendations ----------
  String madeFor(String name) =>
      isFr ? 'Fait pour vous, $name ✈️' : 'Made for you, $name ✈️';
  String get recoSubtitle => isFr
      ? 'Selon vos centres d\'intérêt, vos sorties passées et les lieux préférés des Yaoundéens.'
      : 'Based on your interests, past trips, and Yaoundé\'s most loved places.';
  String get noRecos =>
      isFr ? 'Aucune recommandation pour l\'instant.' : 'No recommendations yet.';

  // ---------- Trips ----------
  String get tripsEmpty => isFr
      ? 'Aucune sortie planifiée.\nAppuyez sur "New trip" pour organiser votre première visite de Yaoundé !'
      : 'No trips yet.\nTap "New trip" to plan your first Yaoundé outing!';
  String get newTrip => isFr ? 'Nouvelle sortie' : 'New trip';
  String get delete => isFr ? 'Supprimer' : 'Delete';
  String stops(int n) => isFr ? '$n étape(s)' : '$n stop(s)';
  String sharedWith(int n) => isFr ? 'partagé avec $n' : 'shared with $n';

  // ---------- Profile / Settings ----------
  String get interests => isFr ? 'Centres d\'intérêt' : 'Interests';
  String get settings => isFr ? 'Paramètres' : 'Settings';
  String get appearance => isFr ? 'Apparence' : 'Appearance';
  String get themeSystem => isFr ? 'Système' : 'System';
  String get themeLight => isFr ? 'Clair' : 'Light';
  String get themeDark => isFr ? 'Sombre' : 'Dark';
  String get language => isFr ? 'Langue' : 'Language';
  String get logout => isFr ? 'Se déconnecter' : 'Log out';
  String get retry => isFr ? 'Réessayer' : 'Retry';
  String get serverError => isFr
      ? 'Impossible de contacter le serveur.'
      : 'Cannot reach the server.';

  // ---------- Auth ----------
  String get welcomeBack => isFr ? 'Bon retour ! 👋' : 'Welcome back! 👋';
  String get loginSubtitle =>
      isFr ? 'Connectez-vous pour retrouver vos sorties' : 'Log in to find your trips again';
  String get email => isFr ? 'Email' : 'Email';
  String get password => isFr ? 'Mot de passe' : 'Password';
  String get passwordMin6 => isFr ? 'Mot de passe (6 min)' : 'Password (6 min)';
  String get login => isFr ? 'Se connecter' : 'Log in';
  String get or => isFr ? 'ou' : 'or';
  String get createAccountFree =>
      isFr ? 'Créer un compte gratuitement' : 'Create a free account';
  String get createAccount => isFr ? 'Créer un compte' : 'Create account';
  String get fullName => isFr ? 'Nom complet' : 'Full name';
  String get interestsQuestion =>
      isFr ? 'Qu\'est-ce qui vous intéresse à Yaoundé ?' : 'What interests you in Yaoundé?';
  String get interestsHint => isFr
      ? 'Vos choix alimentent vos recommandations personnalisées'
      : 'Your picks power your personalized recommendations';
  String get createMyAccount => isFr ? 'Créer mon compte' : 'Create my account';
  String get invalidEmail => isFr ? 'Entrez un email valide' : 'Enter a valid email';
  String get min6chars => isFr ? '6 caractères minimum' : 'Minimum 6 characters';
  String get enterName => isFr ? 'Entrez votre nom' : 'Enter your name';
}
