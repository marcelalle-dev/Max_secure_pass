# Max SecurePass

*Your Passwords. Your Security.*

Gestionnaire de mots de passe Flutter, hors ligne : vos identifiants ne quittent jamais l'appareil.

## Fonctionnalités

- **Coffre chiffré** protégé par un mot de passe maître (créé au premier lancement, au moins 8 caractères).
- **Entrées** : titre, identifiant, mot de passe, site web et notes ; ajout, modification, suppression et recherche.
- **Générateur de mots de passe** : longueur de 8 à 64, minuscules, majuscules, chiffres et symboles, avec un indicateur de robustesse.
- **Presse-papiers sécurisé** : une valeur copiée est effacée automatiquement après 30 secondes.
- **Verrouillage automatique** dès que l'application passe en arrière-plan, plus un bouton de verrouillage manuel.
- **Changement du mot de passe maître**, qui rechiffre tout le coffre.
- **Android** : captures d'écran bloquées et contenu masqué dans les applications récentes (`FLAG_SECURE`).

## Sécurité

| Élément | Choix |
| --- | --- |
| Chiffrement | AES-256-GCM (chiffrement authentifié : une altération ou un mauvais mot de passe sont détectés) |
| Dérivation de clé | PBKDF2-HMAC-SHA256, 600 000 itérations (recommandation OWASP), sel aléatoire de 16 octets |
| Stockage | Un seul fichier `vault.json` chiffré dans le répertoire privé de l'application, écrit de façon atomique |

La clé et les entrées déchiffrées ne restent en mémoire que tant que le coffre est déverrouillé.
**Le mot de passe maître ne peut pas être récupéré** : en cas d'oubli, le coffre est perdu.

La dérivation PBKDF2 est implémentée dans `lib/services/pbkdf2.dart`. Cette version optimisée est
environ 4 fois plus rapide que l'implémentation générique en Dart pur. Elle est vérifiée par les
vecteurs de la RFC 7914 et par comparaison avec le package `cryptography`.

## Structure

```
lib/
  main.dart                  Application, verrouillage automatique
  models/vault_entry.dart    Modèle d'une entrée
  services/
    vault_service.dart       État du coffre (créer, déverrouiller, enregistrer…)
    vault_cipher.dart        Chiffrement AES-GCM + dérivation de clé
    pbkdf2.dart              PBKDF2-HMAC-SHA256
    vault_storage.dart       Stockage fichier (et mémoire pour les tests)
    password_generator.dart  Générateur et estimation de robustesse
    secure_clipboard.dart    Copie avec effacement automatique
  screens/                   Verrouillage, liste, édition, générateur
  widgets/strength_meter.dart
```

## Développement

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
