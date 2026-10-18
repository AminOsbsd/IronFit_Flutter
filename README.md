# 💪 IronFit — gestion de salle de sport (Flutter + Node.js/SQLite)

IronFit est une application de gestion de salle de sport composée :

- d'une **application Flutter** (Windows, Android, Web) qui offre trois expériences selon le rôle : **membre**, **coach** (qui est aussi membre) et **administrateur** ;
- d'une **API REST Node.js** sans dépendance npm, adossée à une base **SQLite** intégrée à Node.js (`node:sqlite`).

---

## Sommaire

1. [Objectifs et fonctionnalités](#1-objectifs-et-fonctionnalités)
2. [Architecture et technologies](#2-architecture-et-technologies)
3. [Structure du dépôt](#3-structure-du-dépôt)
4. [Application Flutter](#4-application-flutter)
5. [Serveur (API)](#5-serveur-api)
6. [Base de données](#6-base-de-données)
7. [Rôles et permissions](#7-rôles-et-permissions)
8. [Authentification et autorisation](#8-authentification-et-autorisation)
9. [Prérequis](#9-prérequis)
10. [Installation](#10-installation)
11. [Configuration (variables d'environnement)](#11-configuration-variables-denvironnement)
12. [Base de données : initialisation et migrations](#12-base-de-données--initialisation-et-migrations)
13. [Lancer le serveur](#13-lancer-le-serveur)
14. [Lancer l'application Flutter](#14-lancer-lapplication-flutter)
15. [Compiler l'application](#15-compiler-lapplication)
16. [Référence de l'API](#16-référence-de-lapi)
17. [Tests et vérification](#17-tests-et-vérification)
18. [Dépannage](#18-dépannage)
19. [Sécurité et déploiement](#19-sécurité-et-déploiement)
20. [Limites connues et pistes d'amélioration](#20-limites-connues-et-pistes-damélioration)

---

## 1. Objectifs et fonctionnalités

**Objectif** : gérer une salle de sport (abonnements, cours collectifs, matériel, boutique) et le suivi sportif des membres par leurs coachs, avec une interface d'administration dédiée.

| Membre | Coach (également membre) | Administrateur |
|---|---|---|
| Inscription, connexion, mot de passe oublié, profil | Tout ce que fait un membre (abonnement, réservations, programmes perso) | Tableau de bord : revenus, alertes, remplissage des cours, activité |
| Demande d'abonnement (validée par l'admin) | **Bascule « Mon entraînement » / « Espace coach »** sans changer de compte | Gestion des membres et coachs : création, rôle, **activation / désactivation** |
| Réservation / annulation des cours (abonnement actif requis) | Accepter / refuser les demandes de suivi, voir ses clients | Validation des demandes d'abonnement, renouvellement + paiement |
| Annuaire des coachs, demande de suivi | Écrire des programmes (exercices, séries, charges) pour ses clients | Supervision des relations coach ↔ client, attribution directe d'un coach |
| Programmes (personnels ou écrits par le coach) | Suivre les séances réalisées par ses clients et les **commenter** | Tarifs, promotions, boutique & stock, matériel, annonces, paiements |
| Journal de séances (durée, difficulté, notes) | Mesures et présences de ses clients | Mesures et présences de tous les membres |
| Courbe de poids / masse grasse, présences, paiements | Planning de ses cours, liste des participants, pointage | Planning complet, pointage de tous les cours |
| Notifications (abonnement, coaching, programme, commentaire, annonce, cours annulé) | Notifications (nouvelle demande, séance terminée par un client…) | Notifications |

---

## 2. Architecture et technologies

```
┌──────────────────────────────┐      HTTP/JSON (Bearer)      ┌──────────────────────────────┐
│  Application Flutter         │  ─────────────────────────▶  │  API Node.js (server.js)     │
│  Windows · Android · Web     │                              │  routeur maison, sans npm    │
│  Material 3, fr              │  ◀─────────────────────────  │  scrypt · HMAC-SHA256        │
│  jeton : stockage sécurisé   │                              │  SQLite (node:sqlite, WAL)   │
└──────────────────────────────┘                              └──────────────┬───────────────┘
                                                                             │
                                                                   backend/data/gym.db
```

| Couche | Technologie | Version vérifiée |
|---|---|---|
| Frontend | Flutter / Dart | Flutter 3.47.7, Dart 3.13.5 (minimum : Flutter 3.35 / Dart 3.9) |
| Paquets Flutter | `http`, `shared_preferences`, `flutter_secure_storage`, `flutter_localizations` | voir `app/pubspec.lock` |
| Backend | Node.js (modules intégrés uniquement : `http`, `crypto`, `node:sqlite`, `node:test`) | Node 24.15.0 (minimum : 22.13) |
| Base | SQLite (mode WAL, clés étrangères actives) | intégrée à Node |

---

## 3. Structure du dépôt

```
IronFit_Flutter/
├─ 1-lancer-serveur.bat          Lance l'API (Windows)
├─ 2-lancer-app-flutter.bat      Lance l'app Flutter Windows (pub get + run)
├─ backend/
│  ├─ server.js                  Point d'entrée : config, base, démarrage HTTP (--reset : base neuve)
│  ├─ .env.example               Modèle de configuration (copier en .env)
│  ├─ package.json               Scripts npm : start, reset-db, test
│  ├─ src/
│  │  ├─ config.js               Lecture des variables d'environnement
│  │  ├─ db.js                   Ouverture SQLite, migrations versionnées, données de démo
│  │  ├─ security.js             scrypt, jetons signés, limitation de débit
│  │  ├─ util.js                 Erreurs HTTP, validation, rôles
│  │  ├─ app.js                  Routeur, session, CORS, en-têtes, fichiers statiques
│  │  └─ routes/
│  │     ├─ auth.js              Inscription, connexion, mot de passe, profil
│  │     ├─ users.js             Membres/coachs (admin), clients (coach), annuaire des coachs
│  │     ├─ subscriptions.js     Demandes d'abonnement, renouvellement
│  │     ├─ coaching.js          Relations coach ↔ client
│  │     ├─ programs.js          Programmes, exercices, séances réalisées, commentaires
│  │     ├─ classes.js           Planning, réservations, participants, pointage
│  │     ├─ notifications.js     Notifications personnelles
│  │     ├─ stats.js             Tableaux de bord admin / coach
│  │     └─ crud.js              CRUD générique avec règles d'accès par entité
│  ├─ test/api.test.js           Tests d'intégration de l'API (node:test)
│  ├─ public/index.html          Page d'accueil du serveur
│  └─ data/                      (non versionné) gym.db + secret générés au premier lancement
└─ app/
   ├─ pubspec.yaml
   ├─ lib/
   │  ├─ main.dart               Thème, localisation, routage connexion / accueil
   │  ├─ services/
   │  │  ├─ api_service.dart     Client REST, session, rôles, espace coach, notifications
   │  │  └─ token_store.dart     Stockage sécurisé du jeton
   │  ├─ models/module.dart      Définition déclarative des modules CRUD (champs, rôles, règles)
   │  ├─ widgets/
   │  │  ├─ common_widgets.dart  États vide/erreur, KPI, graphiques, cloche, confirmations
   │  │  └─ form_dialog.dart     Boîte de saisie générique
   │  └─ screens/
   │     ├─ auth_screen.dart          Connexion, inscription, mot de passe oublié
   │     ├─ home_shell.dart           Navigation par rôle, bascule d'espace coach, Administration/Gestion, Profil
   │     ├─ member_screens.dart       Accueil membre, Explorer, Mon espace, progression, présences
   │     ├─ coaches_screen.dart       Annuaire des coachs, mes coachs
   │     ├─ program_screens.dart      Programmes, exercices, séances réalisées
   │     ├─ coach_screens.dart        Accueil coach, clients, suivi d'un client
   │     ├─ admin_screens.dart        Tableau de bord admin, demandes, suivis coaching
   │     ├─ planning_screen.dart      Planning hebdomadaire, réservations, participants, pointage
   │     ├─ crud_screen.dart          Écran CRUD générique (pagination, recherche serveur)
   │     └─ notifications_screen.dart
   ├─ test/                      Tests unitaires, widgets et intégration avec le vrai serveur
   ├─ android/ windows/ web/     Plateformes cibles
   └─ setup.bat                  pub get + run Windows
```

---

## 4. Application Flutter

- **État** : volontairement simple — `StatefulWidget` + services statiques. `Api` (dans `api_service.dart`) porte la session, et trois `ValueNotifier` pilotent l'interface : `authChanged` (connexion/déconnexion → `MaterialApp`), `workspace` (espace du coach) et `unread` (pastille de notifications).
- **Navigation** (`home_shell.dart`) :
  - Membre : Accueil · Planning · Explorer · Mon espace · Profil
  - Coach, « Mon entraînement » : identique au membre
  - Coach, « Espace coach » : Accueil · Planning · Clients · Gestion · Profil
  - Admin : Accueil · Planning · **Administration** · Profil
  - La bascule du coach est un sélecteur au-dessus de la barre de navigation ; le choix est mémorisé.
- **Modules CRUD** : `models/module.dart` décrit chaque entité (champs, types, rôles qui lisent/écrivent, règle par ligne `canEditRow`, paramètres serveur `query`, actions de menu). `CrudPage` fournit liste paginée (50 par page), recherche côté serveur, formulaire validé, suppression avec confirmation.
- **Règle de dépendance** : `services` et `models` n'importent jamais d'écran ; les `widgets` n'importent pas d'écran (la cloche reçoit la page à ouvrir en paramètre).
- **Robustesse** : chaque écran gère chargement / erreur avec « Réessayer » / état vide ; délai réseau de 15 s ; un 401 déconnecte automatiquement ; messages d'erreur du serveur affichés tels quels, sans détail technique.
- **Adresse du serveur** : roue dentée sur l'écran de connexion, ou Profil → Adresse du serveur. Valeurs par défaut : `http://127.0.0.1:3000` (Windows), `http://10.0.2.2:3000` (émulateur Android), `http://<hôte de la page>:3000` (Web).

---

## 5. Serveur (API)

- `server.js` lit `.env` (facultatif), ouvre la base, applique les migrations, crée les données initiales si la base est vide, puis démarre le serveur HTTP. `start()` est exporté pour les tests (port 0 = port libre).
- `src/app.js` : chaque module de `src/routes/` renvoie une liste `{ method, path, handler, public?, limit? }`. Les chemins `:id` sont des entiers ; `:x(a|b)` restreint les valeurs. Une route non publique exige un jeton valide ; `limit` active la limitation de débit.
- **Règles d'accès côté serveur** : toutes les vérifications de rôle et de propriété sont faites dans les routes (`need(...)`, `S.canSeeMember`, `S.coaches`, règles `read`/`write` de `crud.js`). L'interface ne fait que masquer ce que le serveur refuserait.
- **Validation** : types (`num`, `int`, `pct`, `day`, `time`, `date`, `id`, `text`) et champs obligatoires via `pick()` ; bornes métier (places 1–500, poids 20–400 kg, durée 1–600 min, difficulté 1–10, pas de séance dans le futur…).
- **Erreurs** : JSON `{ "error": "message" }` avec 400 / 401 / 403 / 404 / 405 / 409 / 413 / 429 ; les 500 sont journalisées côté serveur sans être détaillées au client.

---

## 6. Base de données

SQLite, fichier `backend/data/gym.db` (mode WAL, `foreign_keys=ON`). Schéma actuel : **version 2** (`PRAGMA user_version`).

| Table | Rôle | Relations principales |
|---|---|---|
| `users` | Comptes : `role` ∈ `admin`/`coach`/`athlete`, `active`, `tv` (version de jeton), abonnement (`plan_id`, `sub_end`), `specialty` | `plan_id → plans` |
| `plans` | Tarifs (prix, durée : « 1 mois », « 15 jours », « 1 entrée »…) | |
| `requests` | Demandes d'abonnement (`pending`/`approved`/`rejected`/`cancelled`) | `member_id → users`, `plan_id → plans` |
| `payments` | Paiements | `member_id → users` |
| `classes` | Cours hebdomadaires (jour 0 = lundi, heure, places) | `coach_id → users` |
| `bookings` | Réservations (clé primaire `user_id, class_id`) | `→ users`, `→ classes` |
| `checkins` | Présences (date + intitulé du cours) | `member_id → users` |
| `measures` | Mesures (poids, masse grasse) | `member_id → users` |
| `coach_clients` | Relation coach ↔ client : `pending`/`active`/`declined`/`ended`, unique par couple, coach ≠ client | `coach_id, client_id → users` |
| `programs` | Programme : `coach_id` NULL = personnel, sinon écrit par ce coach | `client_id, coach_id → users` |
| `exercises` | Lignes d'un programme (bloc/jour, séries, répétitions, charge, repos) | `program_id → programs` |
| `workouts` | Séances réalisées (durée, difficulté, notes, `coach_comment`) | `user_id → users`, `program_id → programs` |
| `notifications` | Notifications personnelles (`seen`) | `user_id → users` |
| `announcements` | Annonces (`author_id`) | `author_id → users` |
| `promos`, `products`, `equipment` | Offres, boutique & stock, matériel | |
| `resets` | Codes de réinitialisation (hachés, 15 min, 5 essais) | `user_id → users` |

Suppression d'un utilisateur : ses données personnelles sont supprimées en cascade ; les cours qu'il animait passent sans coach ; les programmes qu'il avait écrits deviennent des programmes personnels de leurs clients.

---

## 7. Rôles et permissions

Un **coach est aussi un membre** : un seul compte, deux espaces. Les données sont séparées par la portée des requêtes :

- *Mon entraînement* → `programs?scope=personal`, `measures` (les siennes), `workouts` (les siennes) ;
- *Espace coach* → `programs?scope=coaching`, `measures?scope=clients`, `members` (ses clients actifs).

Un coach n'accède aux données d'un membre **que si la relation est `active`** (demande acceptée par le coach ou attribution par l'admin). Dès que la relation se termine, l'accès est coupé, y compris aux programmes qu'il avait écrits.

| Action | Membre | Coach | Admin |
|---|:-:|:-:|:-:|
| S'abonner (demande), réserver un cours | ✅ | ✅ (pas ses propres cours) | — |
| Programmes personnels, journal de séances, ses mesures | ✅ | ✅ | lecture |
| Demander / arrêter un suivi coaching | ✅ | ✅ (avec un autre coach) | attribuer / terminer |
| Voir les données d'un membre (mesures, présences, séances) | soi | ses clients actifs | tous |
| Écrire un programme pour quelqu'un, commenter ses séances | — | ses clients actifs | — |
| Créer / modifier des cours | — | ses cours (coach imposé = lui) | tous |
| Participants et pointage d'un cours | — | ses cours | tous |
| Annonces | lecture | créer, modifier **les siennes** | toutes |
| Matériel | — | ✅ | ✅ |
| Tarifs, promos, boutique, paiements (écriture) | — | — | ✅ |
| Paiements (lecture) | les siens | les siens | tous |
| Membres et coachs : créer, rôle, désactiver, supprimer | — | — | ✅ |
| Statistiques | — | périmètre de ses clients et cours | globales |

---

## 8. Authentification et autorisation

1. `POST /api/login` (identifiant **ou** e-mail + mot de passe) → `{ token, user }`.
   - Mots de passe hachés avec **scrypt** + sel aléatoire ; comparaison à temps constant ; un hachage factice est calculé si l'identifiant n'existe pas (pas d'énumération par le temps de réponse).
   - Compte désactivé : `403 Compte désactivé`.
2. Le **jeton** = `base64url({id, tv, exp})` + signature **HMAC-SHA256** (clé `IRONFIT_SECRET` ou `data/secret`), valable `TOKEN_DAYS` jours.
3. L'app stocke le jeton avec `flutter_secure_storage` (Keystore Android, DPAPI Windows, WebCrypto sur le Web). Si le stockage sécurisé est indisponible, le jeton reste **en mémoire** (jamais en clair sur disque). Un ancien jeton stocké en clair par la v1 est migré puis effacé.
4. Chaque requête envoie `Authorization: Bearer <jeton>`. Le serveur vérifie signature, expiration, existence du compte, `active = 1` et `tv` identique à celui du compte.
5. **Révocation** : changer ou réinitialiser son mot de passe, ou être désactivé par l'admin, incrémente `tv` → tous les jetons existants deviennent invalides (le changement de mot de passe renvoie un nouveau jeton pour la session courante).
6. **Limitation de débit** : `RATE_LIMIT` tentatives/minute par IP et par route sur connexion, inscription, mot de passe oublié/réinitialisation, changement de mot de passe.
7. L'inscription publique crée toujours un **membre** ; seul l'admin attribue le rôle coach.

---

## 9. Prérequis

| Logiciel | Version | Pour |
|---|---|---|
| Node.js | **22.13 ou plus** (LTS recommandée) | Serveur et tests du serveur |
| Flutter SDK | **3.35 ou plus** (Dart 3.9+) | Application |
| Visual Studio 2022 + charge « Développement Desktop en C++ » | — | `flutter run -d windows` |
| Mode développeur Windows (Paramètres → Pour les développeurs) | — | Liens symboliques des plugins Flutter (sinon : *Building with plugins requires symlink support*) |
| Android Studio + SDK Android | — | Émulateur / téléphone Android |
| Google Chrome ou Edge | — | `flutter run -d chrome` / version Web |

Vérifier l'environnement : `node --version` et `flutter doctor`.

---

## 10. Installation

```bash
git clone <url-du-dépôt> IronFit_Flutter
cd IronFit_Flutter

# Serveur : aucune dépendance npm à installer
cd backend
cp .env.example .env        # facultatif en développement (Windows : copy .env.example .env)

# Application
cd ../app
flutter pub get
```

---

## 11. Configuration (variables d'environnement)

Toutes les variables sont facultatives en développement. Fichier `backend/.env` (modèle : [`backend/.env.example`](backend/.env.example)), ou variables d'environnement du système (prioritaires).

| Variable | Défaut | Description |
|---|---|---|
| `NODE_ENV` | `development` | `production` désactive démo et code de réinitialisation affiché, et exige `ADMIN_PASSWORD` sur base vide |
| `PORT` / `HOST` | `3000` / `0.0.0.0` | Adresse d'écoute (`0.0.0.0` = accessible depuis un téléphone du réseau local) |
| `DATA_DIR` | `backend/data` | Dossier de `gym.db` et du secret généré |
| `IRONFIT_SECRET` | *(fichier `data/secret`)* | Clé de signature des jetons, 32 caractères min. |
| `TOKEN_DAYS` | `7` | Durée de session |
| `ADMIN_PASSWORD` | `admin123` hors production | Mot de passe du compte `admin` créé sur base vide |
| `SEED_DEMO` | `true` hors production | Données de démonstration sur base vide |
| `SHOW_RESET_CODE` | `true` hors production | Renvoie le code « mot de passe oublié » à l'app (démo) |
| `CORS_ORIGIN` | `*` | Origine autorisée (Flutter Web) |
| `RATE_LIMIT` | `10` | Tentatives/minute par IP et par route d'authentification |

Générer un secret : `node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`

L'application Flutter ne contient **aucun secret** : seule l'adresse du serveur est configurable (dans l'app).

---

## 12. Base de données : initialisation et migrations

- **Premier lancement** : `gym.db` est créée, les migrations appliquées, puis le compte `admin` (+ données de démo si `SEED_DEMO`) est créé.
- **Migrations** : tableau `MIGRATIONS` de `backend/src/db.js`, appliquées dans l'ordre dans une transaction ; `PRAGMA user_version` mémorise la dernière. Une base v1 (ancienne version de l'app) est migrée automatiquement en v2 au démarrage, sans perte. Pour faire évoluer le schéma : **ajouter** une entrée à la fin du tableau (ne jamais modifier une migration existante).
- **Repartir d'une base neuve** (supprime `gym.db`) : `npm run reset-db` dans `backend/`.
- **Sauvegarde** : arrêter le serveur puis copier `backend/data/gym.db` (ou utiliser `sqlite3 gym.db ".backup sauvegarde.db"` à chaud).

Comptes de démonstration (base neuve, hors production) :

| Identifiant | Mot de passe | Rôle |
|---|---|---|
| `admin` | `admin123` (ou `ADMIN_PASSWORD`) | Administrateur |
| `sami` | `1234` | Coach — suit Youssef et Leila ; demande en attente d'Amira |
| `leila` | `1234` | **Coach et membre abonnée**, cliente de Sami (cas du double rôle) |
| `youssef` | `1234` | Membre — programme de Sami, séance commentée |
| `amira` | `1234` | Membre — abonnement qui expire bientôt |

> Les comptes de démo ont des mots de passe à 4 caractères créés directement en base ; les comptes créés via l'app exigent 6 caractères minimum.

---

## 13. Lancer le serveur

```bash
cd backend
npm start                 # ou : node server.js   (Windows : double-clic sur 1-lancer-serveur.bat)
```

La console affiche les adresses à utiliser (PC et téléphone). Vérification rapide :

```bash
curl -X POST http://localhost:3000/api/login -H "Content-Type: application/json" -d "{\"login\":\"admin\",\"password\":\"admin123\"}"
```

---

## 14. Lancer l'application Flutter

```bash
cd app
flutter pub get
flutter run -d windows    # ou double-clic sur 2-lancer-app-flutter.bat
flutter run -d chrome     # version Web (serveur sur le même hôte, port 3000)
flutter run -d emulator-5554   # émulateur Android (serveur : http://10.0.2.2:3000)
```

Téléphone réel : même Wi-Fi que le PC, autoriser Node.js dans le pare-feu Windows, puis saisir `http://IP-DU-PC:3000` dans l'app (roue dentée).

---

## 15. Compiler l'application

```bash
cd app
flutter build web           # → app/build/web  (servir en HTTPS en production)
flutter build windows       # → app/build/windows/x64/runner/Release   (Visual Studio requis)
flutter build apk --release # → app/build/app/outputs/flutter-apk/app-release.apk (SDK Android requis)
```

Android : `INTERNET` et `usesCleartextTraffic` sont déclarés dans `android/app/src/main/AndroidManifest.xml` pour joindre un serveur HTTP local. L'APK release est signé avec la clé de debug (`android/app/build.gradle.kts`) : configurer une vraie clé de signature avant publication.

---

## 16. Référence de l'API

Préfixe `/api`. Corps et réponses en JSON. Toutes les routes exigent `Authorization: Bearer <jeton>` sauf mention **public**. Pagination `?limit=` (1–500) et `?offset=` sur `/members`, `/programs?scope=all`, `/workouts`, `/notifications` et le CRUD générique.

### Authentification et profil
| Méthode | Route | Accès | Description |
|---|---|---|---|
| POST | `/signup` | public | `{name, login, email, password}` → `{token, user}` (rôle membre) |
| POST | `/login` | public | `{login, password}` (identifiant ou e-mail) → `{token, user}` |
| POST | `/forgot` | public | `{email}` → `{ok, devCode?}` (même réponse si l'e-mail est inconnu) |
| POST | `/reset` | public | `{email, code, password}` |
| GET | `/me` | tous | Utilisateur courant |
| PUT | `/profile` | tous | `{name, email, phone, specialty?}` (spécialité : coach) |
| POST | `/password` | tous | `{old, new}` → `{ok, token}` (révoque les autres sessions) |

### Utilisateurs
| Méthode | Route | Accès | Description |
|---|---|---|---|
| GET | `/members?q=&role=&active=` | admin, coach | Admin : membres et coachs ; coach : **ses clients actifs** |
| GET | `/members/:id` | admin, coach du membre, soi | Détail |
| POST · PUT · DELETE | `/members`, `/members/:id` | admin | `{name, login, email, password?, phone, role, plan_id, sub_end, specialty}` |
| POST | `/members/:id/status` | admin | `{active: true|false}` (désactiver révoque les sessions) |
| POST | `/members/:id/renew` | admin | `{plan_id, method}` : prolonge + enregistre le paiement |
| GET | `/coaches` | tous | Annuaire : `id, name, specialty, classes, clients` |

### Abonnements
| Méthode | Route | Accès | Description |
|---|---|---|---|
| GET | `/requests` | tous | Membre : les siennes ; admin : en attente |
| POST | `/requests` | membre, coach | `{plan_id}` (une seule demande en attente) |
| POST | `/requests/:id/approve` · `/reject` | admin | `approve` : `{method}` → abonnement prolongé + paiement + notification |
| POST | `/requests/:id/cancel` | auteur | |

### Coaching
| Méthode | Route | Accès | Description |
|---|---|---|---|
| GET | `/coaching/mine` | membre, coach | Mes coachs (toutes relations) |
| GET | `/coaching/clients` | coach | Demandes en attente + clients actifs |
| GET | `/coaching?status=` | admin | Toutes les relations |
| POST | `/coaching/request` | membre, coach | `{coach_id}` |
| POST | `/coaching/assign` | admin | `{coach_id, client_id}` → relation active |
| POST | `/coaching/:id/accept` · `/decline` | coach concerné | |
| POST | `/coaching/:id/end` | coach, client ou admin | |

### Programmes et séances réalisées
| Méthode | Route | Accès | Description |
|---|---|---|---|
| GET | `/programs?scope=personal` | membre, coach | Programmes reçus ou personnels |
| GET | `/programs?scope=coaching&client_id=` | coach | Programmes écrits pour ses clients actifs |
| GET | `/programs?scope=all` | admin | Tous |
| GET | `/programs/:id` | client, auteur (relation active), admin | + `items`, `workouts`, `can_edit`, `can_log`, `can_comment` |
| POST | `/programs` | membre (pour soi), coach (pour un client actif) | `{title, goal, notes, client_id?}` |
| PUT · DELETE | `/programs/:id` | propriétaire (perso) ou auteur coach | `{title, goal, notes, active}` |
| POST | `/programs/:id/exercises` | idem | `{name, day, sets, reps, load, rest, notes, position?}` |
| PUT · DELETE | `/exercises/:id` | idem | |
| GET | `/workouts?user_id=&program_id=` | soi, admin ; coach : séances sur **ses** programmes | |
| POST | `/workouts` | membre, coach | `{program_id?, done_on?, duration, rpe, notes}` |
| DELETE | `/workouts/:id` | auteur | |
| POST | `/workouts/:id/feedback` | coach auteur du programme | `{comment}` → notification au client |

### Planning, notifications, statistiques
| Méthode | Route | Accès | Description |
|---|---|---|---|
| GET | `/classes` | tous | Cours + `coach_name`, `taken`, `mine` |
| POST | `/book` | membre, coach | `{class_id}` : réserve ou annule (bascule) ; abonnement actif requis |
| GET | `/classes/:id/participants` | admin, coach du cours | |
| POST | `/classes/:id/present` | admin, coach du cours | `{member_id}` (inscrit, le jour du cours) |
| GET | `/notifications` | tous | `{unread, items}` |
| POST | `/notifications/:id/read` · `/notifications/read-all` | tous | |
| GET | `/stats` | admin, coach | Vue globale (admin) ou limitée (coach) |

### CRUD générique
`GET` / `POST /api/<entité>` et `PUT` / `DELETE /api/<entité>/:id`, avec `?q=` (recherche texte) :

| Entité | Lecture | Écriture |
|---|---|---|
| `plans`, `promos`, `products` | tous | admin |
| `equipment` | admin, coach | admin, coach |
| `classes` | tous | admin ; coach pour ses cours |
| `announcements` | tous | admin ; coach pour les siennes (création → notification aux membres) |
| `payments` | soi ; admin tout | admin |
| `measures` | soi ; `?member_id=` ; coach `?scope=clients` ; admin tout | admin, soi, coach du membre |
| `checkins` | idem | admin, coach du membre |

Exemple :

```bash
TOKEN=$(curl -s -X POST localhost:3000/api/login -H "Content-Type: application/json" \
  -d '{"login":"sami","password":"1234"}' | node -pe "JSON.parse(require('fs').readFileSync(0)).token")
curl -s localhost:3000/api/coaching/clients -H "Authorization: Bearer $TOKEN"
curl -s -X POST localhost:3000/api/programs -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"Gainage","client_id":4}'
```

---

## 17. Tests et vérification

```bash
# Serveur : 30 tests d'intégration (base temporaire, port libre)
cd backend && npm test

# Application : analyse statique + tests unitaires, widgets et intégration
cd app
flutter analyze
flutter test                                    # tous les tests
flutter test test/backend_integration_test.dart # app ↔ vrai serveur Node (ignoré si Node absent)
```

Couverture des tests :

- **Serveur** (`backend/test/api.test.js`) : connexion, jeton falsifié, inscription (rôle imposé), révocation après changement de mot de passe, réinitialisation, désactivation, limitation de débit, 404/405/JSON invalide ; droits membre/coach/admin ; isolation coach ↔ clients (mesures, membres, séances) ; cycle demande → acceptation → fin de suivi ; rétrogradation d'un coach ; double rôle (réservation, abonnement, séparation des programmes) ; cycle programme → séance → commentaire → notifications ; validation des cours, propriété des cours et annonces, notifications d'annulation ; demande d'abonnement → validation ; statistiques ; migration v1 → v2.
- **Application** : client API (en-tête Bearer, restauration de session, migration du jeton en clair, erreurs, 401 → déconnexion, serveur injoignable), navigation par rôle (membre, admin, bascule coach), règles d'interface des modules, formulaires d'inscription.
- **Intégration** (`app/test/backend_integration_test.dart`) : le client `Api` de l'app contre le vrai serveur — refus 403, parcours complet coach ↔ client, déconnexion forcée après désactivation.

---

## 18. Dépannage

| Symptôme | Cause / solution |
|---|---|
| « Serveur injoignable » | Le serveur n'est pas lancé, ou mauvaise adresse : roue dentée sur l'écran de connexion. Émulateur Android : `http://10.0.2.2:3000`. Téléphone : `http://IP-DU-PC:3000` + Node autorisé dans le pare-feu. |
| « Le serveur ne connaît pas cette fonction » | Un ancien serveur tourne encore : fermez-le (Ctrl+C) puis relancez `1-lancer-serveur.bat`. |
| `Node.js 22.13 ou plus récent est requis` | Mettre à jour Node.js (LTS). |
| `Impossible d'écouter sur le port 3000` | Port occupé : arrêter l'autre processus ou définir `PORT=3001` (et adapter l'adresse dans l'app). |
| `Building with plugins requires symlink support` | Activer le Mode développeur Windows (`start ms-settings:developers`). |
| `Unable to find suitable Visual Studio toolchain` | Installer Visual Studio 2022 avec « Développement Desktop en C++ », ou lancer la version Web (`flutter run -d chrome`). |
| Déconnecté après un changement de mot de passe sur un autre appareil | Normal : les anciens jetons sont révoqués. |
| Web : reconnexion demandée à chaque lancement | Le stockage sécurisé Web exige HTTPS ou `localhost` ; ailleurs le jeton est gardé en mémoire seulement. |
| `Base vide : définissez ADMIN_PASSWORD` | En production, fournir `ADMIN_PASSWORD` au premier lancement. |
| Un coach ne voit pas un membre | La relation doit être **active** : le membre doit l'avoir demandé et le coach accepté, ou l'admin l'a attribué (Administration → Suivis coaching). |

---

## 19. Sécurité et déploiement

- **Secrets** : `backend/data/` (base + secret) et `.env` sont exclus de Git. Fournir `IRONFIT_SECRET` et `ADMIN_PASSWORD` en production ; changer le mot de passe admin après installation.
- **Historique Git** : les versions précédentes du dépôt contenaient `backend/data/secret` et une base de données. Le secret a été régénéré localement, mais ces fichiers restent dans l'historique : purger l'historique (`git filter-repo --path backend/data --invert-paths`, puis push forcé) si le dépôt est partagé, et considérer les données de cette base comme exposées.
- **HTTPS** : en production, placer l'API derrière un reverse proxy TLS (Caddy, Nginx…), mettre `HOST=127.0.0.1`, restreindre `CORS_ORIGIN` à l'origine de la version Web et retirer `usesCleartextTraffic` du manifeste Android.
- **Production** : `NODE_ENV=production` (désactive données de démo et code affiché) ; brancher un envoi d'e-mail dans `/api/forgot` (`src/routes/auth.js`) avant d'ouvrir la réinitialisation.
- **Sauvegardes** : copier régulièrement `gym.db` (base unique, un seul processus serveur).
- **Journalisation** : les erreurs 500 sont journalisées avec la route, sans corps de requête ni mot de passe ; les codes de réinitialisation ne sont affichés en console qu'en mode démo.

---

## 20. Limites connues et pistes d'amélioration

- **Vérifié dans l'environnement de développement** : analyse Flutter sans avertissement, tous les tests serveur/app/intégration, compilation **Web** et parcours réel dans Chrome (membre-coach, coach, admin). **Non vérifié ici** : compilation Windows (Visual Studio absent) et Android (SDK absent).
- Pas d'envoi d'e-mail ni de notifications push : les notifications sont lues à l'ouverture des écrans d'accueil.
- Le planning est hebdomadaire et récurrent (pas de cours datés ni de fermetures exceptionnelles) ; une présence est liée à la date et à l'intitulé du cours.
- Paiement en ligne non géré (paiement à l'accueil, validé par l'admin).
- Un seul compte administrateur créé automatiquement ; pas d'écran de création d'autres administrateurs.
- Pas de journal d'audit des actions d'administration, ni de module de réclamations.
- Ordre des exercices : ordre d'insertion (pas de glisser-déposer).
- Limitation de débit en mémoire et base SQLite : prévu pour **une seule instance** du serveur.
- Interface en français uniquement.
- Pistes : cours datés avec historique, e-mail (réinitialisation, rappels d'expiration), notifications push (FCM), export CSV des paiements, journal d'audit, gestion multi-administrateurs, réordonnancement des exercices, internationalisation.
