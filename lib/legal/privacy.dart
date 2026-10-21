/// Politique de confidentialité de Max SecurePass.
///
/// Source unique : l'application l'affiche (page « À propos ») et
/// `tool/generate_privacy_page.dart` en produit la page web publiée pour
/// Google Play (`docs/politique-de-confidentialite.html`). Après toute
/// modification, relancer ce script ; un test vérifie que la page est à jour.
///
/// Ce fichier n'importe pas Flutter : le script le lit avec `dart run`.
library;

import 'legal_text.dart';

export 'legal_text.dart';

const contactEmail = 'marcelalledev@gmail.com';

/// Date de dernière mise à jour.
final privacyDate = DateTime(2026, 10, 21);

const privacySummary =
    'Max SecurePass ne collecte, ne transmet et ne partage aucune donnée. Vos identifiants '
    'restent chiffrés sur votre téléphone ; l\'application n\'a même pas l\'autorisation '
    'd\'accéder à Internet.';

const privacySections = [
  LegalSection(
    'Qui sommes-nous',
    'Max SecurePass est une application Android de gestion de mots de passe. Pour toute '
        'question sur cette politique ou sur vos données, écrivez à $contactEmail.',
  ),
  LegalSection(
    'Données enregistrées sur votre téléphone',
    'Les identifiants que vous saisissez (titres, noms d\'utilisateur, mots de passe, adresses '
        'de sites et notes) sont enregistrés uniquement dans l\'espace privé de l\'application, '
        'sur votre téléphone, chiffrés avec AES-256-GCM. La clé de chiffrement est protégée par '
        'votre mot de passe maître, que l\'application n\'enregistre jamais. L\'application '
        'conserve aussi, sur le téléphone, la date d\'acceptation des conditions d\'utilisation '
        'et le nombre de tentatives de récupération du mot de passe.',
  ),
  LegalSection(
    'Questions de récupération',
    'Vos réponses aux trois questions personnelles ne sont enregistrées nulle part, ni en clair '
        'ni chiffrées. Elles servent uniquement, au moment où vous les saisissez, à calculer une '
        'clé qui protège une copie de la clé du coffre.',
  ),
  LegalSection(
    'Données que nous ne collectons pas',
    'Nous ne recevons aucune donnée : l\'application ne déclare pas l\'autorisation Android '
        'd\'accès à Internet et ne peut donc rien envoyer. Il n\'y a ni compte utilisateur, ni '
        'publicité, ni statistiques d\'utilisation, ni rapport de plantage, ni service tiers '
        'intégré. Aucune donnée n\'est vendue ni partagée.',
  ),
  LegalSection(
    'Empreinte digitale et code du téléphone',
    'Si vous activez le déverrouillage par empreinte ou par code, la vérification est réalisée '
        'entièrement par Android. L\'application n\'a jamais accès à votre empreinte ni à votre '
        'code : elle reçoit seulement l\'accord du système pour utiliser une clé conservée dans '
        'le Keystore du téléphone. Les autorisations USE_BIOMETRIC et USE_FINGERPRINT servent '
        'uniquement à cela.',
  ),
  LegalSection(
    'Sauvegarde et suppression',
    'La sauvegarde automatique d\'Android et le transfert vers un autre appareil sont '
        'désactivés : vos données ne sont copiées ni dans le cloud ni ailleurs. Vous pouvez les '
        'supprimer à tout moment en effaçant les données de l\'application ou en la '
        'désinstallant ; cette suppression est définitive.',
  ),
  LegalSection(
    'Vos droits',
    'Comme nous ne détenons aucune donnée vous concernant, nous ne pouvons ni y accéder, ni les '
        'corriger, ni les supprimer à votre place : vous en gardez la maîtrise complète sur '
        'votre téléphone. Pour toute question, contactez-nous à $contactEmail.',
  ),
  LegalSection(
    'Enfants',
    'L\'application ne s\'adresse pas spécifiquement aux enfants et ne collecte aucune donnée, '
        'y compris celles des enfants.',
  ),
  LegalSection(
    'Modifications',
    'Si cette politique change, la nouvelle version sera publiée sur cette page et dans '
        'l\'application, avec sa date de mise à jour.',
  ),
];
