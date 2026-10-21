# Google Play — fiche et déclarations

Tout ce qu'il faut saisir dans la Play Console pour Max SecurePass
(`dev.marcelalle.maxsecurepass`, version 1.0.0, versionCode 1).

## 1. Politique de confidentialité

- Page : `docs/politique-de-confidentialite.html`, générée depuis `lib/legal/privacy.dart`
  (`dart run tool/generate_privacy_page.dart`). L'application affiche le même texte dans
  « À propos ».
- Publication avec GitHub Pages (le dépôt est public) : sur GitHub, **Settings → Pages →
  Build and deployment → Deploy from a branch**, choisir la branche qui contient `docs/`
  (`main` une fois les changements fusionnés) et le dossier **`/docs`**.
- Adresse à indiquer dans la Play Console (disponible quelques minutes après l'activation) :
  `https://marcelalle-dev.github.io/Max_secure_pass/politique-de-confidentialite.html`
- Ouvrez cette adresse dans un navigateur pour vérifier qu'elle répond avant de la saisir.

## 2. Fiche du Play Store

**Nom de l'application** (30 caractères max) :

```
Max SecurePass
```

**Description courte** (80 caractères max) :

```
Coffre-fort de mots de passe chiffré, hors ligne, sans compte ni publicité.
```

**Description complète** (4 000 caractères max) :

```
Max SecurePass garde tous vos mots de passe dans un coffre chiffré, sur votre téléphone uniquement. Pas de compte, pas de cloud, pas de publicité : l'application n'a même pas l'autorisation d'accéder à Internet.

UN SEUL MOT DE PASSE À RETENIR
Créez votre coffre avec un mot de passe maître, puis enregistrez vos identifiants : site ou application, identifiant, mot de passe, adresse web et notes. Retrouvez-les en un instant grâce à la recherche et au classement par lettre.

DES MOTS DE PASSE SOLIDES EN UN GESTE
Le générateur crée des mots de passe aléatoires de 8 à 64 caractères (minuscules, majuscules, chiffres, symboles). Une jauge indique la robustesse de chaque mot de passe.

DÉVERROUILLAGE PAR EMPREINTE OU CODE
Ouvrez votre coffre avec votre empreinte ou le code de votre téléphone. La clé est protégée par le système de sécurité d'Android (Keystore) ; votre mot de passe maître reste toujours utilisable.

MOT DE PASSE OUBLIÉ ? PAS DE PANIQUE
Trois questions personnelles, associées au code de votre téléphone, vous permettent de choisir un nouveau mot de passe maître sans perdre vos identifiants. Vos réponses ne sont jamais enregistrées et les tentatives sont limitées.

UNE SÉCURITÉ SÉRIEUSE
• Chiffrement AES-256-GCM de tout le coffre
• Clé dérivée du mot de passe maître avec PBKDF2-HMAC-SHA256 (600 000 itérations)
• Verrouillage automatique dès que vous quittez l'application
• Captures d'écran bloquées et contenu masqué dans les applications récentes
• Presse-papiers vidé automatiquement 30 secondes après une copie
• Sauvegarde automatique d'Android désactivée : vos données ne quittent pas le téléphone

VOS DONNÉES VOUS APPARTIENNENT
Max SecurePass ne collecte, ne transmet et ne partage aucune donnée. Aucun compte à créer, aucune statistique, aucun pistage.

Important : sans sauvegarde dans le cloud, désinstaller l'application ou perdre votre téléphone efface définitivement le coffre.

Interface en français, thèmes clair et sombre.
```

**Catégorie** : Outils. **Adresse e-mail de contact** : marcelalledev@gmail.com.

## 3. Visuels

| Élément | Fichier | Exigence Google Play |
|---|---|---|
| Icône | `store/visuels/icone-512.png` | 512 × 512, PNG |
| Bannière (feature graphic) | `store/visuels/banniere-1024x500.png` | 1024 × 500, sans transparence |
| Captures téléphone | `store/captures/1_…` à `6_…` | 1080 × 1920 (9:16), 2 à 8 images |

L'application bloque les captures d'écran (`FLAG_SECURE`) : ces images sont des rendus de
l'application réelle, avec des données d'exemple.

## 4. Réponses aux formulaires de la Play Console

### Sécurité des données (Data safety)

| Question | Réponse |
|---|---|
| Votre application collecte-t-elle ou partage-t-elle des types de données utilisateur obligatoires ? | **Non** |
| (conséquence) | La fiche affichera « Aucune donnée collectée » et « Aucune donnée partagée avec des tiers » |

Justification : aucune autorisation `INTERNET`, aucun SDK tiers, aucun compte. Les données
restent chiffrées sur l'appareil, ce qui ne compte pas comme une collecte au sens de Google Play.

### Accès à l'application (App access)

**Toutes les fonctionnalités sont disponibles sans accès particulier.** Il n'y a pas de compte :
l'examinateur crée lui-même un coffre au premier lancement.

### Publicités

**Non**, l'application ne contient pas de publicités.

### Classification du contenu (questionnaire IARC)

- Catégorie : **Utilitaire, productivité, communication ou autre**.
- Violence, sexualité, langage grossier, substances, jeux d'argent : **Non** à toutes les questions.
- Interactions entre utilisateurs, partage de position, achats numériques : **Non**.
- Résultat attendu : **Tout public / PEGI 3**.

### Public cible et contenu

- Tranche d'âge : **18 ans et plus** (ou 13 ans et plus). Évitez les tranches de moins de 13 ans :
  elles soumettent l'application au programme Familles, inadapté à un gestionnaire de mots de passe.
- L'application n'attire pas spécialement les enfants : **Non**.

### Autres déclarations

| Déclaration | Réponse |
|---|---|
| Application gouvernementale | Non |
| Fonctionnalités financières | Aucune |
| Santé | Non |
| Application d'actualités | Non |
| ID publicitaire (Advertising ID) | Non utilisé |
| Autorisations sensibles | Aucune déclaration requise : `USE_BIOMETRIC` / `USE_FINGERPRINT` ne demandent pas de formulaire |

## 5. Rappels

- **Signature d'application Google Play** : à la création de l'application, gardez l'option par
  défaut (clé gérée par Google). Votre `.jks` est la clé d'importation.
- **Comptes développeur personnels récents** : un test fermé avec au moins 12 testeurs pendant
  14 jours est exigé avant la mise en production.
- Les APK de test envoyés pendant le développement sont signés en debug : désinstallez-les avant
  d'installer la version Play (le coffre de test sera effacé).
