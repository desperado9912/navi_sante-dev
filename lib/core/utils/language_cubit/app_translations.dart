import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'language_cubit.dart';

/// Central translation dictionary and localization helper for NaviSanté.
///
/// Implements GetX [Translations] for seamless `.tr` usage, while also
/// exposing context-aware reactive lookups and static helpers.
class AppTranslations extends Translations {
  static const Map<String, String> _en = {
    // ── Navigation Bar & App Bar ────────────────────────────
    'Discover': 'Discover',
    'Hospitals': 'Hospitals',
    'Find Sanctuary': 'Find Sanctuary',
    'Hospitals & Clinics': 'Hospitals & Clinics',
    'Medications': 'Medications',
    'Pharmacy & Medications': 'Pharmacy & Medications',
    'Profile': 'Profile',

    // ── Profile Screen & Settings ───────────────────────────
    'Settings': 'Settings',
    'Account Details': 'Account Details',
    'Saved Facilities': 'Saved Facilities',
    'Saved facilities': 'Saved Facilities',
    'Favourite Products': 'Favourite Products',
    'Notifications': 'Notifications',
    'Language': 'Language',
    'Navigation App': 'Navigation App',
    'Help & Support': 'Help & Support',
    'Help & support': 'Help & Support',
    'About NaviSanté': 'About NaviSanté',
    'Share NaviSanté': 'Share NaviSanté',
    'Love the app? Rate us': 'Love the app? Rate us',
    'Log Out': 'Log Out',
    'Select language': 'Select language',
    'Select navigation app': 'Select navigation app',
    'Preferred Navigation App': 'Preferred Navigation App',
    'Choose which app NaviSanté uses for directions and live navigation.':
        'Choose which app NaviSanté uses for directions and live navigation.',
    'Are you sure you want to log out of your account?':
        'Are you sure you want to log out of your account?',
    'Cancel': 'Cancel',
    'Delete': 'Delete',
    'Delete Account': 'Delete Account',
    'Are you sure you want to delete your account? This action cannot be undone.':
        'Are you sure you want to delete your account? This action cannot be undone.',
    'Manage your account information': 'Manage your account information',
    'View your saved healthcare facilities':
        'View your saved healthcare facilities',
    'View your bookmarked medications': 'View your bookmarked medications',
    'Choose your preferred navigation app':
        'Choose your preferred navigation app',
    'Get in touch with our team': 'Get in touch with our team',
    'Learn more about the platform': 'Learn more about the platform',
    'No saved facilities': 'No saved facilities',
    'No saved facilities yet': 'No saved facilities yet',
    'Save facilities to find them quickly later.':
        'Save facilities to find them quickly later.',
    'Tap the bookmark icon on any hospital to save your favorite facilities here.':
        'Tap the bookmark icon on any hospital to save your favorite facilities here.',
    'No favourite products': 'No favourite products',
    'No favourite products yet': 'No favourite products yet',
    'No favourite medications yet': 'No favourite medications yet',
    'Medications you favourite will appear here.':
        'Medications you favourite will appear here.',
    'Tap the heart icon on any medication to save your favorite products here.':
        'Tap the heart icon on any medication to save your favorite products here.',
    'Tap the heart icon on any medication to save it here.':
        'Tap the heart icon on any medication to save it here.',
    'Account Information': 'Account Information',
    'Personal Info': 'Personal Info',
    'Full Name': 'Full Name',
    'Email': 'Email',
    'Email Verified': 'Email Verified',
    'Phone': 'Phone',
    'Security': 'Security',
    'Change Password': 'Change Password',
    'Save Changes': 'Save Changes',
    'English': 'English',
    'Français': 'Français',
    'Current password': 'Current password',
    'New password': 'New password',
    'Confirm new password': 'Confirm new password',
    'Password updated successfully.': 'Password updated successfully.',
    'Account updated successfully.': 'Account updated successfully.',

    // ── Hospitals & Facilities ──────────────────────────────
    'Find health facilities around you': 'Find health facilities around you',
    'hospitals, clinics or pharmacies': 'hospitals, clinics or pharmacies',
    'Recent History': 'Recent History',
    'Top Rated Nearby': 'Top Rated Nearby',
    'Search Results': 'Search Results',
    'No results found': 'No results found',
    'No facilities available': 'No facilities available',
    'Health Condition': 'Health Condition',
    'Select City': 'Select City',
    'Price Rating': 'Price Rating',
    'Free': 'Free',
    'Affordable': 'Affordable',
    'Premium': 'Premium',
    'Search hospitals, clinics...': 'Search hospitals, clinics...',
    'Search': 'Search',
    'All': 'All',
    'Hospital': 'Hospital',
    'Clinic': 'Clinic',
    'Pharmacy': 'Pharmacy',
    'Health Center': 'Health Center',
    'Open Now': 'Open Now',
    'Closed': 'Closed',
    'Open 24/7': 'Open 24/7',
    'Emergency': 'Emergency',
    'Bookmarked': 'Bookmarked',
    'GET DIRECTIONS': 'GET DIRECTIONS',
    'VIEW FULL DETAILS': 'VIEW FULL DETAILS',
    'CALL': 'CALL',
    'Directions': 'Directions',
    'Call': 'Call',
    'Details': 'Details',
    'Overview': 'Overview',
    'Services & Specialties': 'Services & Specialties',
    'Opening Hours': 'Opening Hours',
    'Contact & Location': 'Contact & Location',
    'Insurance Accepted': 'Insurance Accepted',
    'Address': 'Address',
    'Phone Number': 'Phone Number',
    'Emergency Services': 'Emergency Services',
    'No facilities found': 'No facilities found',
    'Try adjusting your search or filters':
        'Try adjusting your search or filters',
    'km away': 'km away',
    'm away': 'm away',
    'Select Type': 'Select Type',
    'Unable to open the phone app.': 'Unable to open the phone app.',
    'Unable to open directions in navigation app.':
        'Unable to open directions in navigation app.',
    'Saved to bookmarks': 'Saved to bookmarks',
    'Removed from bookmarks': 'Removed from bookmarks',

    // ── Pharmacy & Medications ──────────────────────────────
    'Search medication, brand or symptoms...':
        'Search medication, brand or symptoms...',
    'In Stock': 'In Stock',
    'Out of Stock': 'Out of Stock',
    'Prescription': 'Prescription',
    'OTC': 'OTC',
    'Prescription Required': 'Prescription Required',
    'Over the counter': 'Over the counter',
    'Dosage': 'Dosage',
    'Available at': 'Available at',
    'Price': 'Price',
    'Pain Relief': 'Pain Relief',
    'Antibiotics': 'Antibiotics',
    'Vitamins & Supplements': 'Vitamins & Supplements',
    'First Aid': 'First Aid',
    'Cardiovascular': 'Cardiovascular',
    'Respiratory': 'Respiratory',
    'Digestive Health': 'Digestive Health',
    'Skin Care': 'Skin Care',
    'Allergy': 'Allergy',
    'No medications found': 'No medications found',
    'Try checking for typos or searching with different keywords.':
        'Try checking for typos or searching with different keywords.',
    'Always consult a healthcare professional or pharmacist before taking medication.':
        'Always consult a healthcare professional or pharmacist before taking medication.',
    'Retry': 'Retry',
    "Try searching 'Malaria' or 'Ibuprofen'":
        "Try searching 'Malaria' or 'Ibuprofen'",
    'Quick Filters:': 'Quick Filters:',
    'Clear': 'Clear',
    'Certain medications require medical supervision. Please always consult a healthcare professional before use.':
        'Certain medications require medical supervision. Please always consult a healthcare professional before use.',
    'Common medications': 'Common medications',
    'Treats: ': 'Treats: ',
    'more': 'more',
    "Requires a doctor's prescription (Rx). Do not use without medical supervision.":
        "Requires a doctor's prescription (Rx). Do not use without medical supervision.",
    'Available over the counter (OTC). Follow the recommended dosage, and ask a pharmacist if unsure.':
        'Available over the counter (OTC). Follow the recommended dosage, and ask a pharmacist if unsure.',
    'Price varies': 'Price varies',
    'Unable to load medications.': 'Unable to load medications.',
    'Malaria': 'Malaria',
    'Painkiller': 'Painkiller',
    'Antimalarial': 'Antimalarial',
    'Fever': 'Fever',
    'Headache': 'Headache',
    'Cold & Flu': 'Cold & Flu',
    'Try a different name, brand, or symptom — e.g. "headache" or "malaria".':
        'Try a different name, brand, or symptom — e.g. "headache" or "malaria".',

    // ── Home & Map ──────────────────────────────────────────
    'Search hospitals, pharmacies...': 'Search hospitals, pharmacies...',
    'Search hospitals, pharmacies, clinics':
        'Search hospitals, pharmacies, clinics',
    'Search for clinics, pharmacies, doctors...':
        'Search for clinics, pharmacies, doctors...',
    'Recent searches': 'Recent searches',
    'Clear all': 'Clear all',
    'Map Legend': 'Map Legend',
    'Recenter map': 'Recenter map',
    'Map Info': 'Map Info',
    'Map Information': 'Map Information',
    'Tile Provider': 'Tile Provider',
    'Zoom In': 'Zoom In',
    'Zoom Out': 'Zoom Out',
    'map info': 'map info',
    'Map data is licensed under the Open Database License (ODbL).':
        'Map data is licensed under the Open Database License (ODbL).',
    '© OpenStreetMap and other contributors':
        '© OpenStreetMap and other contributors',
    'Close': 'Close',

    // ── AI Chat ─────────────────────────────────────────────
    'Ask NaviAI anything about health, medications, or nearby facilities...':
        'Ask NaviAI anything about health, medications, or nearby facilities...',
    'Chat history': 'Chat history',
    'New chat': 'New chat',
    'Delete chat?': 'Delete chat?',
    'Online': 'Online',
    'Type a message...': 'Type a message...',
    'Just now': 'Just now',
    'Health Assistant': 'Health Assistant',

    // ── Auth & Onboarding ───────────────────────────────────
    'Managing your health has never been easier.':
        'Managing your health has never been easier.',
    'With fast search assisted by a robust AI, quickly find medical facilities according to your medical needs.':
        'With fast search assisted by a robust AI, quickly find medical facilities according to your medical needs.',
    'Health map': 'Health map',
    'Find hospitals, clinics and pharmacies nearby.':
        'Find hospitals, clinics and pharmacies nearby.',
    'AI Chat': 'AI Chat',
    'Ask health questions and get reliable answers.':
        'Ask health questions and get reliable answers.',
    'Medication': 'Medication',
    'Search for a medications and compare prices.':
        'Search for a medications and compare prices.',
    'Get Started': 'Get Started',
    'Welcome Back': 'Welcome Back',
    'Health navigation made easy': 'Health navigation made easy',
    'Enter Email Address': 'Enter Email Address',
    'Enter Password': 'Enter Password',
    'Forgot password?': 'Forgot password?',
    'Sign In': 'Sign In',
    'Sign Up': 'Sign Up',
    'Create Account': 'Create Account',
    'Already have an account?': 'Already have an account?',
    'Don’t have an account?': 'Don’t have an account?',
    'Log In': 'Log In',

    // ── Error Messages & Feedback ───────────────────────────
    'Incorrect email or password.': 'Incorrect email or password.',
    'Please verify your email before logging in.':
        'Please verify your email before logging in.',
    'An account with this email may already exist.':
        'An account with this email may already exist.',
    'Password must be at least 8 characters.':
        'Password must be at least 8 characters.',
    'Please enter a valid email address.':
        'Please enter a valid email address.',
    'Too many attempts. Please wait a moment and try again.':
        'Too many attempts. Please wait a moment and try again.',
    'Something went wrong. Please try again.':
        'Something went wrong. Please try again.',
    'Current password is incorrect.': 'Current password is incorrect.',
    'New password must be different from your current password.':
        'New password must be different from your current password.',
    'Your session has expired. Please log in again.':
        'Your session has expired. Please log in again.',
    'Unable to connect. Please check your internet connection and try again.':
        'Unable to connect. Please check your internet connection and try again.',
    'Failed to update password. Please try again.':
        'Failed to update password. Please try again.',
    'Unable to delete account. Please try again or contact support.':
        'Unable to delete account. Please try again or contact support.',
    'No internet connection': 'No internet connection',
    'Internet connection restored': 'Internet connection restored',
    'Back online': 'Back online',
    'Could not open the link.': 'Could not open the link.',
    'Success': 'Success',
    'Error': 'Error',
    'Warning': 'Warning',
    'Information': 'Information',
    'OK': 'OK',
  };

  static const Map<String, String> _fr = {
    // ── Navigation Bar & App Bar ────────────────────────────
    'Discover': 'Découvrir',
    'Hospitals': 'Hôpitaux',
    'Find Sanctuary': 'Trouver un refuge',
    'Hospitals & Clinics': 'Hôpitaux & Cliniques',
    'Medications': 'Médicaments',
    'Pharmacy & Medications': 'Pharmacie & Médicaments',
    'Profile': 'Profil',

    // ── Profile Screen & Settings ───────────────────────────
    'Settings': 'Paramètres',
    'Account Details': 'Détails du compte',
    'Saved Facilities': 'Établissements enregistrés',
    'Saved facilities': 'Établissements enregistrés',
    'Favourite Products': 'Produits favoris',
    'Notifications': 'Notifications',
    'Language': 'Langue',
    'Navigation App': 'Application de navigation',
    'Help & Support': 'Aide et support',
    'Help & support': 'Aide et support',
    'About NaviSanté': 'À propos de NaviSanté',
    'Share NaviSanté': 'Partager NaviSanté',
    'Love the app? Rate us': 'Vous aimez l’application ? Notez-nous',
    'Log Out': 'Se déconnecter',
    'Select language': 'Choisir la langue',
    'Select navigation app': 'Sélectionner l’application de navigation',
    'Preferred Navigation App': 'Application de navigation préférée',
    'Choose which app NaviSanté uses for directions and live navigation.':
        'Choisissez l’application utilisée par NaviSanté pour la navigation.',
    'Are you sure you want to log out of your account?':
        'Êtes-vous sûr de vouloir vous déconnecter de votre compte ?',
    'Cancel': 'Annuler',
    'Delete': 'Supprimer',
    'Delete Account': 'Supprimer le compte',
    'Are you sure you want to delete your account? This action cannot be undone.':
        'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.',
    'Manage your account information': 'Gérer les informations de votre compte',
    'View your saved healthcare facilities':
        'Consulter vos établissements de santé enregistrés',
    'View your bookmarked medications': 'Consulter vos médicaments favoris',
    'Choose your preferred navigation app':
        'Choisissez votre application de navigation préférée',
    'Get in touch with our team': 'Contactez notre équipe',
    'Learn more about the platform': 'En savoir plus sur la plateforme',
    'No saved facilities': 'Aucun établissement enregistré',
    'No saved facilities yet': 'Aucun établissement enregistré pour le moment',
    'Save facilities to find them quickly later.':
        'Enregistrez des établissements pour les retrouver rapidement plus tard.',
    'Tap the bookmark icon on any hospital to save your favorite facilities here.':
        'Appuyez sur l’icône de favori d’un hôpital pour l’enregistrer ici.',
    'No favourite products': 'Aucun produit favori',
    'No favourite products yet': 'Aucun produit favori pour le moment',
    'No favourite medications yet': 'Aucun médicament favori pour le moment',
    'Medications you favourite will appear here.':
        'Les médicaments que vous ajoutez aux favoris apparaîtront ici.',
    'Tap the heart icon on any medication to save your favorite products here.':
        'Appuyez sur le cœur d’un médicament pour l’ajouter aux favoris.',
    'Tap the heart icon on any medication to save it here.':
        'Appuyez sur le cœur d’un médicament pour l’enregistrer ici.',
    'Account Information': 'Informations du compte',
    'Personal Info': 'Infos personnelles',
    'Full Name': 'Nom complet',
    'Email': 'E-mail',
    'Email Verified': 'E-mail vérifié',
    'Phone': 'Téléphone',
    'Security': 'Sécurité',
    'Change Password': 'Changer le mot de passe',
    'Save Changes': 'Enregistrer les modifications',
    'English': 'English',
    'Français': 'Français',
    'Current password': 'Mot de passe actuel',
    'New password': 'Nouveau mot de passe',
    'Confirm new password': 'Confirmer le nouveau mot de passe',
    'Password updated successfully.':
        'Mot de passe mis à jour avec succès.',
    'Account updated successfully.':
        'Compte mis à jour avec succès.',

    // ── Hospitals & Facilities ──────────────────────────────
    'Find health facilities around you':
        'Trouvez des établissements de santé autour de vous',
    'hospitals, clinics or pharmacies': 'hôpitaux, cliniques ou pharmacies',
    'Recent History': 'Historique récent',
    'Top Rated Nearby': 'Les mieux notés à proximité',
    'Search Results': 'Résultats de recherche',
    'No results found': 'Aucun résultat trouvé',
    'No facilities available': 'Aucun établissement disponible',
    'Health Condition': 'État de santé',
    'Select City': 'Sélectionner la ville',
    'Price Rating': 'Niveau de prix',
    'Free': 'Gratuit',
    'Affordable': 'Abordable',
    'Premium': 'Haut de gamme',
    'Search hospitals, clinics...': 'Rechercher hôpitaux, cliniques...',
    'Search': 'Rechercher',
    'All': 'Tous',
    'Hospital': 'Hôpital',
    'Clinic': 'Clinique',
    'Pharmacy': 'Pharmacie',
    'Health Center': 'Centre de santé',
    'Open Now': 'Ouvert',
    'Closed': 'Fermé',
    'Open 24/7': 'Ouvert 24h/24',
    'Emergency': 'Urgences',
    'Bookmarked': 'Favoris',
    'GET DIRECTIONS': 'ITINÉRAIRE',
    'VIEW FULL DETAILS': 'VOIR TOUS LES DÉTAILS',
    'CALL': 'APPELER',
    'Directions': 'Itinéraire',
    'Call': 'Appeler',
    'Details': 'Détails',
    'Overview': 'Aperçu',
    'Services & Specialties': 'Services & Spécialités',
    'Opening Hours': 'Horaires d’ouverture',
    'Contact & Location': 'Contact & Emplacement',
    'Insurance Accepted': 'Assurances acceptées',
    'Address': 'Adresse',
    'Phone Number': 'Numéro de téléphone',
    'Emergency Services': 'Services d’urgence',
    'No facilities found': 'Aucun établissement trouvé',
    'Try adjusting your search or filters':
        'Essayez d’ajuster votre recherche ou vos filtres',
    'km away': 'km de distance',
    'm away': 'm de distance',
    'Select Type': 'Sélectionner un type',
    'Unable to open the phone app.':
        'Impossible d’ouvrir l’application téléphone.',
    'Unable to open directions in navigation app.':
        'Impossible d’ouvrir l’itinéraire dans l’application de navigation.',
    'Saved to bookmarks': 'Ajouté aux favoris',
    'Removed from bookmarks': 'Retiré des favoris',

    // ── Pharmacy & Medications ──────────────────────────────
    'Search medication, brand or symptoms...':
        'Rechercher un médicament, marque ou symptôme...',
    'In Stock': 'En stock',
    'Out of Stock': 'Rupture de stock',
    'Prescription': 'Sur ordonnance',
    'OTC': 'En vente libre',
    'Prescription Required': 'Sur ordonnance requise',
    'Over the counter': 'En vente libre',
    'Dosage': 'Posologie',
    'Available at': 'Disponible à',
    'Price': 'Prix',
    'Pain Relief': 'Soulagement de la douleur',
    'Antibiotics': 'Antibiotiques',
    'Vitamins & Supplements': 'Vitamines & Suppléments',
    'First Aid': 'Premiers secours',
    'Cardiovascular': 'Cardiovasculaire',
    'Respiratory': 'Respiratoire',
    'Digestive Health': 'Santé digestive',
    'Skin Care': 'Soins de la peau',
    'Allergy': 'Allergies',
    'No medications found': 'Aucun médicament trouvé',
    'Try checking for typos or searching with different keywords.':
        'Vérifiez l’orthographe ou essayez avec d’autres mots-clés.',
    'Always consult a healthcare professional or pharmacist before taking medication.':
        'Consultez toujours un professionnel de santé ou un pharmacien avant de prendre des médicaments.',
    'Retry': 'Réessayer',
    "Try searching 'Malaria' or 'Ibuprofen'":
        "Essayez 'Paludisme' ou 'Ibuprofène'",
    'Quick Filters:': 'Filtres rapides :',
    'Clear': 'Effacer',
    'Certain medications require medical supervision. Please always consult a healthcare professional before use.':
        'Certains médicaments nécessitent une surveillance médicale. Veuillez toujours consulter un professionnel de la santé avant utilisation.',
    'Common medications': 'Médicaments courants',
    'Treats: ': 'Traite : ',
    'more': 'de plus',
    "Requires a doctor's prescription (Rx). Do not use without medical supervision.":
        "Nécessite une ordonnance médicale (Rx). Ne pas utiliser sans surveillance médicale.",
    'Available over the counter (OTC). Follow the recommended dosage, and ask a pharmacist if unsure.':
        'Disponible en vente libre (OTC). Respectez la posologie recommandée et demandez conseil à un pharmacien en cas de doute.',
    'Price varies': 'Prix variable',
    'Unable to load medications.': 'Impossible de charger les médicaments.',
    'Malaria': 'Paludisme',
    'Painkiller': 'Antidouleur',
    'Antimalarial': 'Antipaludéen',
    'Fever': 'Fièvre',
    'Headache': 'Maux de tête',
    'Cold & Flu': 'Rhume & Grippe',
    'Try a different name, brand, or symptom — e.g. "headache" or "malaria".':
        'Essayez un autre nom, une marque ou un symptôme — par ex. "maux de tête" ou "paludisme".',

    // ── Home & Map ──────────────────────────────────────────
    'Search hospitals, pharmacies...': 'Rechercher hôpitaux, pharmacies...',
    'Search hospitals, pharmacies, clinics':
        'Rechercher hôpitaux, pharmacies, cliniques',
    'Search for clinics, pharmacies, doctors...':
        'Rechercher cliniques, pharmacies, médecins...',
    'Recent searches': 'Recherches récentes',
    'Clear all': 'Tout effacer',
    'Map Legend': 'Légende de la carte',
    'Recenter map': 'Recentrer la carte',
    'Map Info': 'Infos carte',
    'Map Information': 'Informations sur la carte',
    'Tile Provider': 'Fournisseur de tuiles',
    'Zoom In': 'Zoom avant',
    'Zoom Out': 'Zoom arrière',
    'map info': 'Infos carte',
    'Map data is licensed under the Open Database License (ODbL).':
        'Les données de la carte sont sous licence Open Database (ODbL).',
    '© OpenStreetMap and other contributors':
        '© OpenStreetMap et autres contributeurs',
    'Close': 'Fermer',

    // ── AI Chat ─────────────────────────────────────────────
    'Ask NaviAI anything about health, medications, or nearby facilities...':
        'Posez toute question à NaviAI sur la santé, les médicaments ou les établissements...',
    'Chat history': 'Historique des discussions',
    'New chat': 'Nouvelle discussion',
    'Delete chat?': 'Supprimer la discussion ?',
    'Online': 'En ligne',
    'Type a message...': 'Écrivez un message...',
    'Just now': 'À l’instant',
    'Health Assistant': 'Assistant de santé',

    // ── Auth & Onboarding ───────────────────────────────────
    'Managing your health has never been easier.':
        'Gérer votre santé n’a jamais été aussi simple.',
    'With fast search assisted by a robust AI, quickly find medical facilities according to your medical needs.':
        'Grâce à une recherche rapide assistée par une IA performante, trouvez rapidement des établissements médicaux selon vos besoins.',
    'Health map': 'Carte de santé',
    'Find hospitals, clinics and pharmacies nearby.':
        'Trouvez des hôpitaux, cliniques et pharmacies à proximité.',
    'AI Chat': 'Discussion IA',
    'Ask health questions and get reliable answers.':
        'Posez des questions de santé et obtenez des réponses fiables.',
    'Medication': 'Médicaments',
    'Search for a medications and compare prices.':
        'Recherchez des médicaments et comparez les prix.',
    'Get Started': 'Commencer',
    'Welcome Back': 'Bon Retour',
    'Health navigation made easy': 'Navigation santé facilitée',
    'Enter Email Address': 'Adresse e-mail',
    'Enter Password': 'Mot de passe',
    'Forgot password?': 'Mot de passe oublié ?',
    'Sign In': 'Se connecter',
    'Sign Up': 'S’inscrire',
    'Create Account': 'Créer un compte',
    'Already have an account?': 'Vous avez déjà un compte ?',
    'Don’t have an account?': 'Vous n’avez pas de compte ?',
    'Log In': 'Connexion',

    // ── Error Messages & Feedback ───────────────────────────
    'Incorrect email or password.': 'E-mail ou mot de passe incorrect.',
    'Please verify your email before logging in.':
        'Veuillez vérifier votre e-mail avant de vous connecter.',
    'An account with this email may already exist.':
        'Un compte avec cet e-mail existe peut-être déjà.',
    'Password must be at least 8 characters.':
        'Le mot de passe doit comporter au moins 8 caractères.',
    'Please enter a valid email address.':
        'Veuillez saisir une adresse e-mail valide.',
    'Too many attempts. Please wait a moment and try again.':
        'Trop de tentatives. Veuillez patienter un instant et réessayer.',
    'Something went wrong. Please try again.':
        'Une erreur s’est produite. Veuillez réessayer.',
    'Current password is incorrect.': 'Le mot de passe actuel est incorrect.',
    'New password must be different from your current password.':
        'Le nouveau mot de passe doit être différent de l’actuel.',
    'Your session has expired. Please log in again.':
        'Votre session a expiré. Veuillez vous reconnecter.',
    'Unable to connect. Please check your internet connection and try again.':
        'Connexion impossible. Veuillez vérifier votre connexion Internet et réessayer.',
    'Failed to update password. Please try again.':
        'Échec de la mise à jour du mot de passe. Veuillez réessayer.',
    'Unable to delete account. Please try again or contact support.':
        'Impossible de supprimer le compte. Veuillez réessayer ou contacter le support.',
    'No internet connection': 'Aucune connexion Internet',
    'Internet connection restored': 'Connexion Internet rétablie',
    'Back online': 'De nouveau en ligne',
    'Could not open the link.': 'Impossible d’ouvrir le lien.',
    'Success': 'Succès',
    'Error': 'Erreur',
    'Warning': 'Avertissement',
    'Information': 'Information',
    'OK': 'OK',
  };

  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': _en,
        'en': _en,
        'fr_FR': _fr,
        'fr': _fr,
      };

  /// Translates [key] according to the active language.
  /// If [context] is provided, uses the ambient [LanguageCubit].
  /// Otherwise, falls back to [LanguageCubit.currentLanguageCode] or [Get.locale].
  static String tr(String key, [BuildContext? context]) {
    String langCode = 'en';

    if (context != null) {
      try {
        langCode = context.read<LanguageCubit>().state.code;
      } catch (_) {
        langCode = LanguageCubit.currentLanguageCode;
      }
    } else {
      langCode = LanguageCubit.currentLanguageCode;
    }

    if (langCode == 'fr') {
      return _fr[key] ?? key;
    }
    return _en[key] ?? key;
  }

  /// Checks if the active language is French.
  static bool isFrench([BuildContext? context]) {
    if (context != null) {
      try {
        return context.read<LanguageCubit>().state.isFrench;
      } catch (_) {}
    }
    return LanguageCubit.currentLanguageCode == 'fr';
  }
}

/// Extension on [BuildContext] for easy, reactive translations.
extension NaviTranslationContext on BuildContext {
  /// Translates [key] using ambient [LanguageCubit].
  /// Automatically triggers rebuild when language changes if used in build().
  String tr(String key) {
    try {
      final state = watch<LanguageCubit>().state;
      if (state.isFrench) {
        return AppTranslations._fr[key] ?? key;
      }
      return AppTranslations._en[key] ?? key;
    } catch (_) {
      return AppTranslations.tr(key, this);
    }
  }

  /// Returns true if current language is French.
  bool get isFrench {
    try {
      return watch<LanguageCubit>().state.isFrench;
    } catch (_) {
      return AppTranslations.isFrench(this);
    }
  }

  /// Helper returning [fr] if French, else [en].
  String t(String en, String fr) => isFrench ? fr : en;
}

/// Extension on [String] for convenient string translation.
extension NaviStringTranslate on String {
  /// Translates the string based on active locale.
  String trApp([BuildContext? context]) => AppTranslations.tr(this, context);
}

/// Global inline helper function
String t(BuildContext context, String en, String fr) =>
    context.isFrench ? fr : en;

/// Global translate function
String tr(String key, [BuildContext? context]) =>
    AppTranslations.tr(key, context);
