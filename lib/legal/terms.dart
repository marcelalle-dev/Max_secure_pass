/// Conditions d'utilisation de Max SecurePass.
///
/// Incrémenter [termsVersion] à chaque modification de fond : les
/// utilisateurs devront accepter la nouvelle version au démarrage suivant.
library;

import 'package:flutter/material.dart' show IconData, Icons;

import 'legal_text.dart';

export 'legal_text.dart';

const termsVersion = 2;

/// Date d'entrée en vigueur de [termsVersion].
final termsDate = DateTime(2026, 10, 21);

typedef TermsSection = LegalSection;

/// Les points essentiels, résumés en tête de l'écran d'acceptation.
const termsHighlights = <(IconData, String, String)>[
  (
    Icons.phone_android_rounded,
    'Vos données restent sur ce téléphone',
    'Rien n\'est envoyé sur Internet : l\'application n\'a pas l\'autorisation d\'y accéder.',
  ),
  (
    Icons.key_rounded,
    'Mot de passe oublié : récupération sur ce téléphone',
    'Avec vos trois réponses personnelles et le code du téléphone. Sans eux, le coffre ne '
        'peut plus être ouvert.',
  ),
  (
    Icons.cloud_off_rounded,
    'Pas de sauvegarde automatique',
    'Désinstaller l\'application ou perdre le téléphone efface définitivement le coffre.',
  ),
];

const termsSections = [
  TermsSection(
    'Objet',
    'Max SecurePass est une application de gestion de mots de passe. Elle permet d\'enregistrer '
        'des identifiants (titres, noms d\'utilisateur, mots de passe, adresses de sites et notes) '
        'dans un coffre chiffré, et de générer des mots de passe. Les présentes conditions '
        'encadrent son utilisation. En les acceptant, vous vous engagez à les respecter.',
  ),
  TermsSection(
    'Vos données',
    'Le coffre est enregistré uniquement dans l\'espace privé de l\'application, sur ce '
        'téléphone. Il est chiffré avec AES-256-GCM ; la clé est dérivée de votre mot de passe '
        'maître (PBKDF2-HMAC-SHA256, 600 000 itérations). L\'application ne collecte, ne '
        'transmet et ne partage aucune donnée : elle ne dispose pas de l\'autorisation d\'accès '
        'à Internet, ne contient ni publicité ni outil de mesure d\'audience, et ne crée aucun '
        'compte. La sauvegarde automatique d\'Android est désactivée pour l\'application.',
  ),
  TermsSection(
    'Mot de passe maître',
    'Vous choisissez votre mot de passe maître et vous êtes seul à le connaître : il n\'est '
        'enregistré nulle part et ne peut pas être retrouvé. En cas d\'oubli, il ne peut être '
        'remplacé que grâce aux questions de récupération décrites ci-dessous. Choisissez un '
        'mot de passe robuste, que vous n\'utilisez nulle part ailleurs.',
  ),
  TermsSection(
    'Questions de récupération',
    'Lors de la création du coffre, vous répondez à trois questions personnelles fixes. Vos '
        'réponses ne sont enregistrées nulle part, ni en clair ni chiffrées : elles servent, '
        'avec un secret conservé par le système de sécurité du téléphone (Keystore Android), à '
        'protéger une copie de la clé du coffre. En cas d\'oubli du mot de passe maître, ces '
        'trois réponses et le code ou l\'empreinte du téléphone permettent d\'en choisir un '
        'nouveau, sans perte de données, sur ce téléphone uniquement. Les tentatives sont '
        'limitées et espacées par un délai croissant. Toute personne connaissant vos réponses '
        'et ayant accès à votre téléphone déverrouillé pourrait remplacer votre mot de passe '
        'maître : choisissez des réponses que vos proches ou les réseaux sociaux ne révèlent '
        'pas, et ne les communiquez à personne. Si le verrouillage d\'écran du téléphone est '
        'supprimé ou réinitialisé, la récupération cesse de fonctionner et doit être '
        'reconfigurée après ouverture du coffre avec le mot de passe maître.',
  ),
  TermsSection(
    'Déverrouillage par empreinte ou code',
    'Si vous l\'activez, la clé du coffre est confiée au système de sécurité de votre '
        'téléphone (Keystore Android), qui ne la rend utilisable qu\'après votre empreinte ou '
        'le code du téléphone. Toute personne connaissant ce code ou dont l\'empreinte est '
        'enregistrée sur le téléphone pourra alors ouvrir le coffre. Vous pouvez désactiver '
        'cette option à tout moment ; le mot de passe maître reste toujours utilisable.',
  ),
  TermsSection(
    'Conservation et perte des données',
    'L\'application ne propose ni synchronisation ni sauvegarde. La désinstallation de '
        'l\'application, l\'effacement de ses données, la réinitialisation, la perte ou la '
        'panne du téléphone entraînent la perte définitive du coffre. Il vous appartient de '
        'conserver par vos propres moyens une copie des informations indispensables.',
  ),
  TermsSection(
    'Utilisation responsable',
    'Vous vous engagez à utiliser l\'application pour gérer vos propres identifiants, ou '
        'ceux que vous êtes autorisé à détenir, dans le respect des lois applicables. '
        'Gardez votre téléphone à jour et protégé par un verrouillage d\'écran.',
  ),
  TermsSection(
    'Garantie et responsabilité',
    'L\'application est fournie « en l\'état », sans garantie d\'aucune sorte, notamment '
        'quant à l\'absence d\'erreurs ou à son adéquation à un usage particulier. Dans les '
        'limites permises par la loi, l\'éditeur ne pourra être tenu responsable des '
        'dommages résultant de son utilisation, en particulier de la perte de données ou de '
        'l\'oubli du mot de passe maître.',
  ),
  TermsSection(
    'Logiciels libres',
    'L\'application intègre des composants libres, dont les polices Sora et JetBrains Mono '
        '(licence SIL Open Font License 1.1). La liste complète et le texte des licences sont '
        'consultables depuis la page « À propos ».',
  ),
  TermsSection(
    'Modification des conditions',
    'Ces conditions peuvent évoluer. En cas de modification, la nouvelle version vous sera '
        'présentée au démarrage de l\'application et devra être acceptée pour continuer à '
        'l\'utiliser.',
  ),
];
