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

  // ---------- Erreurs réseau ----------
  String get cannotReachServer => isFr
      ? 'Impossible de contacter le serveur. Vérifiez votre connexion.'
      : 'Cannot reach the server. Please check your connection.';
  String get somethingWrong =>
      isFr ? 'Une erreur est survenue. Réessayez.' : 'Something went wrong. Please try again.';
  String get invalidCredentials =>
      isFr ? 'Email ou mot de passe invalide' : 'Invalid email or password';
  String get emailAlreadyRegistered =>
      isFr ? 'Cet email est déjà utilisé' : 'Email already registered';
  String get loginFailed => isFr ? 'Connexion impossible' : 'Login failed';
  String get registerFailed => isFr ? 'Inscription impossible' : 'Registration failed';
  String get continueWithGoogle => isFr ? 'Continuer avec Google' : 'Continue with Google';
  String get googleNotConfigured => isFr
      ? 'Google Sign-In pas encore configuré pour cette app'
      : 'Google Sign-In not configured for this app yet';

  // ---------- Panneau de marque (branding) ----------
  String get authTagline =>
      isFr ? 'Découvrez Yaoundé plus intelligemment. Voyagez mieux. 🇨🇲'
           : 'Discover Yaoundé smarter. Travel better. 🇨🇲';
  String get registerTitle => isFr ? 'Rejoignez l\'aventure' : 'Join the adventure';
  String get registerSubtitle => isFr
      ? 'Créez votre compte et explorez Yaoundé autrement ✨'
      : 'Create your account and explore Yaoundé differently ✨';
  String get featurePlaces => isFr ? '26+ lieux à Yaoundé' : '26+ places in Yaoundé';
  String get featureRecos => isFr ? 'Recos personnalisées' : 'Personalized recos';
  String get featureTrips => isFr ? 'Sorties partagées' : 'Shared trips';

  // ---------- Création d'une sortie (create_itinerary_screen.dart) ----------
  String get newItineraryTitle => isFr ? 'Nouvelle sortie' : 'New itinerary';
  String get atLeastOneDestination =>
      isFr ? 'Ajoutez au moins une destination' : 'Add at least one destination';
  String get tripTitleLabel => isFr ? 'Titre de la sortie' : 'Trip title';
  String get giveItATitle => isFr ? 'Donnez-lui un titre' : 'Give it a title';
  String get descriptionOptional =>
      isFr ? 'Description (optionnel)' : 'Description (optional)';
  String get startDate => isFr ? 'Date de début' : 'Start date';
  String get endDate => isFr ? 'Date de fin' : 'End date';
  String get shareWithLabel =>
      isFr ? 'Partager avec (emails, séparés par des virgules)' : 'Share with (emails, comma separated)';
  String get shareWithHelper =>
      isFr ? 'Vos amis et votre famille verront cette sortie' : 'Friends & family will see this trip';
  String get stopsLabel => isFr ? 'Étapes' : 'Stops';
  String get addStop => isFr ? 'Ajouter une étape' : 'Add stop';
  String dayLabel(int n) => isFr ? 'Jour $n' : 'Day $n';
  String get notesOptional => isFr ? 'Notes (optionnel)' : 'Notes (optional)';
  String get createItinerary => isFr ? "Créer l'itinéraire" : 'Create itinerary';
  String get pastDateNotAllowed => isFr
      ? 'Impossible de choisir une date déjà passée'
      : 'Cannot pick a date that has already passed';

  // ---------- Social (amis, partage) ----------
  String get friends => isFr ? 'Amis' : 'Friends';
  String get friendsSubtitle => isFr
      ? 'Suivez vos amis pour voir leurs sorties publiques'
      : 'Follow friends to see their public trips';
  String get searchFriendsHint =>
      isFr ? 'Rechercher par nom ou email…' : 'Search by name or email…';
  String get follow => isFr ? 'Suivre' : 'Follow';
  String get unfollow => isFr ? 'Ne plus suivre' : 'Unfollow';
  String get following => isFr ? 'Abonnements' : 'Following';
  String get followers => isFr ? 'Abonnés' : 'Followers';
  String get noSearchResults =>
      isFr ? 'Aucun utilisateur trouvé.' : 'No users found.';
  String get notFollowingAnyone => isFr
      ? 'Vous ne suivez personne pour l\'instant.\nRecherchez des amis ci-dessus.'
      : 'You\'re not following anyone yet.\nSearch for friends above.';
  String get noFollowersYet =>
      isFr ? 'Personne ne vous suit encore.' : 'No followers yet.';
  String get friendsFeed => isFr ? 'Sorties des amis' : 'Friends\' trips';
  String get friendsFeedEmpty => isFr
      ? 'Aucune sortie publique de vos amis pour l\'instant.\nSuivez plus de monde ou attendez qu\'ils partagent une sortie !'
      : 'No public trips from friends yet.\nFollow more people or wait for them to share a trip!';
  String get makePublic => isFr ? 'Rendre publique' : 'Make public';
  String get makePublicHelper => isFr
      ? 'Visible par vos abonnés dans "Sorties des amis"'
      : 'Visible to your followers in "Friends\' trips"';
  String get makePrivate => isFr ? 'Rendre privée' : 'Make private';
  String get publicTripBadge => isFr ? 'Publique' : 'Public';
  String get visibilityUpdateFailed => isFr
      ? 'Impossible de changer la visibilité'
      : 'Could not change visibility';
  String get budgetLabel => isFr ? 'Budget prévu (optionnel)' : 'Planned budget (optional)';
  String get budgetHelper => isFr
      ? 'Comparé automatiquement au coût estimé de vos arrêts'
      : 'Automatically compared against your stops\' estimated cost';
  String get budgetSummaryTitle => isFr ? 'Budget' : 'Budget';
  String get budgetNoPriceData =>
      isFr ? 'Coût non estimable pour cette sortie' : 'Cost cannot be estimated for this trip';
  String budgetEstimated(String amount) =>
      isFr ? 'Coût estimé : $amount' : 'Estimated cost: $amount';
  String budgetPlanned(String amount) => isFr ? 'Budget prévu : $amount' : 'Planned budget: $amount';
  String get budgetWithinBudget => isFr ? 'Dans le budget' : 'Within budget';
  String get budgetNearBudget => isFr ? 'Proche du budget' : 'Near budget';
  String get budgetOverBudget => isFr ? 'Dépasse le budget' : 'Over budget';
  String get optimizeRoute => isFr ? 'Optimiser le trajet' : 'Optimize route';
  String get routeOptimized => isFr
      ? 'Ordre des arrêts optimisé pour réduire les trajets'
      : 'Stop order optimized to reduce travel';
  String get share => isFr ? 'Partager' : 'Share';
  String shareItineraryText(String title, int stops, String url) => isFr
      ? 'Découvre mon itinéraire "$title" sur GlobeTrotter Yaoundé ($stops étape(s)) ! $url'
      : 'Check out my itinerary "$title" on GlobeTrotter Yaoundé ($stops stop(s))! $url';
  String shareDestinationText(String name, String quartier, String url) => isFr
      ? 'Va voir $name ($quartier) sur GlobeTrotter Yaoundé ! $url'
      : 'Check out $name ($quartier) on GlobeTrotter Yaoundé! $url';

  // ---------- Messagerie ----------
  String get messages => isFr ? 'Messages' : 'Messages';
  String get inboxEmpty => isFr
      ? 'Aucune conversation pour l\'instant.\nEnvoyez un message à un ami !'
      : 'No conversations yet.\nSend a friend a message!';
  String get typeMessage => isFr ? 'Écrire un message…' : 'Type a message…';
  String get messageFailed =>
      isFr ? 'Échec de l\'envoi du message' : 'Failed to send message';
  String get startConversation =>
      isFr ? 'Démarrer une conversation' : 'Start a conversation';
  String get canOnlyMessageFriends => isFr
      ? 'Vous devez suivre cette personne (ou être suivi par elle) pour lui écrire.'
      : 'You need to follow this person (or be followed by them) to message them.';
  String get discoverPeople => isFr ? 'Découvrir' : 'Discover';
  String get discoverEmpty => isFr
      ? 'Personne d\'autre à découvrir pour l\'instant.\nRevenez plus tard !'
      : 'No one else to discover right now.\nCheck back later!';

  // ---------- Commentaires / likes ----------
  String get comments => isFr ? 'Commentaires' : 'Comments';
  String get noComments =>
      isFr ? 'Aucun commentaire. Soyez le premier !' : 'No comments yet. Be the first!';
  String get addComment => isFr ? 'Ajouter un commentaire…' : 'Add a comment…';
  String get deleteComment => isFr ? 'Supprimer' : 'Delete';
  String likesCount(int n) => isFr
      ? (n == 0 ? 'Aucun like' : n == 1 ? '1 like' : '$n likes')
      : (n == 0 ? 'No likes' : n == 1 ? '1 like' : '$n likes');
  String commentsCount(int n) => isFr
      ? (n == 0 ? 'Aucun commentaire' : n == 1 ? '1 commentaire' : '$n commentaires')
      : (n == 0 ? 'No comments' : n == 1 ? '1 comment' : '$n comments');
}
