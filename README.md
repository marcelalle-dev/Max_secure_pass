# Max SecurePass

*Your Passwords. Your Security.*

Gestionnaire de mots de passe Flutter, hors ligne : vos identifiants ne quittent jamais l'appareil.

## Fonctionnalités

- **Conditions d'utilisation** à accepter au premier lancement (case à cocher), puis à chaque
  nouvelle version (`termsVersion` dans `lib/legal/terms.dart`).
- **Page « À propos »** : version, fonctionnement de la sécurité, conditions et licences des
  logiciels libres. Accessible depuis le menu et l'écran de verrouillage.
- **Mot de passe oublié** : récupération grâce à trois questions personnelles fixes et au code du
  téléphone, sans perte de données (voir « Récupération » ci-dessous).
- **Coffre chiffré** protégé par un mot de passe maître (créé au premier lancement, au moins 8 caractères).
- **Entrées** : titre, identifiant, mot de passe, site web et notes ; ajout, modification, suppression et recherche.
- **Générateur de mots de passe** : longueur de 8 à 64, minuscules, majuscules, chiffres et symboles, avec un indicateur de robustesse.
- **Presse-papiers sécurisé** : une valeur copiée est effacée automatiquement après 30 secondes.
- **Verrouillage automatique** dès que l'application passe en arrière-plan, plus un bouton de verrouillage manuel.
- **Déverrouillage par empreinte ou code du téléphone** (Android), activable depuis le menu ou
  proposé juste après la création du coffre. Le mot de passe maître reste toujours utilisable.
- **Changement du mot de passe maître**, qui rechiffre tout le coffre.
- **Android** : captures d'écran bloquées et contenu masqué dans les applications récentes (`FLAG_SECURE`).

## Sécurité

| Élément | Choix |
| --- | --- |
| Chiffrement | AES-256-GCM (chiffrement authentifié : une altération ou un mauvais mot de passe sont détectés) |
| Dérivation de clé | PBKDF2-HMAC-SHA256, 600 000 itérations (recommandation OWASP), sel aléatoire de 16 octets |
| Stockage | Un seul fichier `vault.json` chiffré dans le répertoire privé de l'application, écrit de façon atomique |
| Empreinte ou code | La clé du coffre est conservée par `flutter_secure_storage`, chiffrée par une clé AES du Keystore Android créée avec `setUserAuthenticationRequired(true)` : le système ne la rend utilisable qu'après l'empreinte ou le code, à chaque lecture |

La clé et les entrées déchiffrées ne restent en mémoire que tant que le coffre est déverrouillé.
**Le mot de passe maître ne peut pas être récupéré** : en cas d'oubli, le coffre est perdu.

L'application ne demande pas l'autorisation Internet : en version release, elle ne peut rien
envoyer sur le réseau. La sauvegarde automatique d'Android et le transfert vers un autre appareil
sont désactivés (`allowBackup="false"`, `res/xml/data_extraction_rules.xml`).

Si la clé enregistrée ne correspond plus au coffre (par exemple après un changement du
verrouillage d'écran), le déverrouillage par le téléphone est désactivé et le mot de passe maître
est demandé. Une annulation ou un échec passager (trop d'essais) ne le désactive pas.

La dérivation PBKDF2 est implémentée dans `lib/services/pbkdf2.dart`. Cette version optimisée est
environ 4 fois plus rapide que l'implémentation générique en Dart pur. Elle est vérifiée par les
vecteurs de la RFC 7914 et par comparaison avec le package `cryptography`.

## Récupération du mot de passe maître

Le coffre est chiffré par une **clé de coffre** aléatoire (256 bits), elle-même verrouillée deux
fois :

```
                  ┌─ verrou 1 : mot de passe maître (PBKDF2-HMAC-SHA256, 600 000 itérations)
clé du coffre ────┤
                  └─ verrou 2 : 3 réponses (PBKDF2, 200 000 itérations, un sel par réponse)
                               + secret du Keystore Android (code ou empreinte exigé)
```

- **Réponses jamais enregistrées** : les trois dérivations sont combinées par HKDF-SHA256 en une
  seule clé. On ne peut pas vérifier une réponse isolément, et le message d'erreur est générique.
- **Aucune attaque hors ligne** : le secret matériel ne quitte pas le Keystore. Le fichier du coffre
  seul ne permet pas de tester des réponses.
- **Limitation** : 3 essais libres, puis 30 s, 1 min, 5 min, 15 min et 1 h. La tentative est comptée
  avant la vérification et stockée chiffrée par le Keystore.
- **Anti-rejeu** : l'autorisation obtenue ne sert qu'une fois, expire au bout de 5 minutes et est
  annulée dès que l'application passe en arrière-plan. Chaque verrou est lié à son coffre (AES-GCM,
  données associées).
- **Réinitialisation** : seul le verrou 1 est refait ; les données, les réponses et le déverrouillage
  par empreinte restent valables.
- **Migration** : un coffre à l'ancien format (v1) est converti à la première ouverture avec le mot de
  passe maître, puis la configuration des questions est imposée.
- Si le verrouillage d'écran du téléphone est supprimé, le Keystore détruit son secret : la
  récupération est désactivée et sera redemandée à la prochaine ouverture.

## Identité visuelle

L'interface reprend le logo (bouclier bleu et clé en forme de « M ») :

| Rôle | Couleur |
| --- | --- |
| Bleu signal : actions, moitié gauche du bouclier | `#0262F4` |
| Bleu profond : moitié droite du bouclier | `#023EB8` |
| Marine : texte, fond du thème sombre | `#080E28` |
| Glacier : fond du thème clair | `#EEF3FD` |

- Polices : **Sora** pour l'interface, **JetBrains Mono** pour les mots de passe (chiffres en bleu,
  symboles en orange, pour distinguer l/1/I et O/0). Les deux sont sous licence OFL et incluses
  dans `assets/fonts/`.
- L'écran de verrouillage reprend le logo en grand : un en-tête en forme de bouclier bicolore,
  avec la clé au centre.
- Les identifiants sont groupés par initiale, chacun avec un petit bouclier.
- Thèmes clair et sombre, icône Android adaptative et écran de démarrage aux couleurs du logo.

## Structure

```
lib/
  main.dart                  Application, verrouillage automatique
  legal/terms.dart           Texte et version des conditions d'utilisation
  models/vault_entry.dart    Modèle d'une entrée
  services/
    vault_service.dart       État du coffre (créer, déverrouiller, enregistrer…)
    vault_cipher.dart        Chiffrement AES-GCM + dérivation de clé
    pbkdf2.dart              PBKDF2-HMAC-SHA256
    vault_storage.dart       Stockage fichier (et mémoire pour les tests)
    password_generator.dart  Générateur et estimation de robustesse
    secure_clipboard.dart    Copie avec effacement automatique
    device_unlock.dart       Déverrouillage par empreinte ou code (Keystore)
    terms_service.dart       Acceptation des conditions d'utilisation
    vault_file.dart          Format du coffre (verrous, données)
    recovery_*.dart          Questions, secret du Keystore, limitation des tentatives
  theme/app_theme.dart       Couleurs, typographie et composants
  screens/                   Verrouillage, liste, édition, générateur
  widgets/                   Logo, bouclier, jauge de robustesse, affichage des mots de passe
```

## Développement

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Publication sur Google Play

La version release est signée avec la **clé d'importation** décrite dans `android/key.properties`
(exclu de Git ; modèle : `android/key.properties.example`). Sans ce fichier, `flutter build
appbundle --release` s'arrête volontairement : Google Play refuse les bundles signés en debug.

Avec la signature d'application Google Play, Google conserve la **clé de signature de
l'application** ; vous ne détenez que la clé d'importation. En cas de perte, celle-ci peut être
réinitialisée par le support Google Play.

### 1. Créer la clé d'importation (une seule fois, Windows PowerShell)

```powershell
# Dossier HORS du projet
New-Item -ItemType Directory -Force "$env:USERPROFILE\cles"

# keytool est fourni avec Android Studio
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore "$env:USERPROFILE\cles\maxsecurepass-upload.jks" `
  -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 -alias upload
```

Le mot de passe demandé sert pour `storePassword` **et** `keyPassword` (format PKCS12).
Sauvegardez le fichier `.jks` et son mot de passe dans un endroit sûr, distinct du PC.

### 2. Configurer la signature

```powershell
Copy-Item android\key.properties.example android\key.properties
notepad android\key.properties
```

Renseignez `storeFile` avec des barres obliques, par exemple
`C:/Users/VotreNom/cles/maxsecurepass-upload.jks`.

### 3. Générer et vérifier le bundle

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release

Test-Path build\app\outputs\bundle\release\app-release.aab
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -printcert `
  -jarfile build\app\outputs\bundle\release\app-release.aab
```

La dernière commande doit afficher **votre** certificat, et non « Android Debug ».

### 4. Versions suivantes

Augmentez `version` dans `pubspec.yaml` avant chaque envoi : le numéro après `+` (versionCode)
doit toujours croître, par exemple `1.0.0+1` puis `1.0.1+2`.
