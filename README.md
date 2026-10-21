# 💪 IronFit — gestion de salle de sport (Flutter + Spring Boot + MySQL)

IronFit est une plateforme de gestion de salle de sport composée :

- d'une **application Flutter** (Windows, Android, Web) aux couleurs du logo IronFit, avec trois expériences selon le rôle : **membre**, **coach** (qui est aussi membre) et **administrateur** ;
- d'une **API REST Java / Spring Boot** (architecture en couches, Spring Security + JWT) ;
- d'une base **MySQL** — en local, le MySQL de **XAMPP** (MariaDB), inspectable dans **phpMyAdmin**.

---

## Sommaire

1. [Fonctionnalités](#1-fonctionnalités)
2. [Architecture](#2-architecture)
3. [Structure du dépôt](#3-structure-du-dépôt)
4. [Logiciels requis et versions](#4-logiciels-requis-et-versions)
5. [Installation de l'application Flutter](#5-installation-de-lapplication-flutter)
6. [Java, Maven et Spring Boot](#6-java-maven-et-spring-boot)
7. [XAMPP et démarrage de MySQL](#7-xampp-et-démarrage-de-mysql)
8. [Base de données : création et configuration](#8-base-de-données--création-et-configuration)
9. [Variables d'environnement](#9-variables-denvironnement)
10. [Démarrer le backend](#10-démarrer-le-backend)
11. [Démarrer l'application Flutter](#11-démarrer-lapplication-flutter)
12. [API REST](#12-api-rest)
13. [Authentification et rôles](#13-authentification-et-rôles)
14. [Adresse du serveur selon l'appareil](#14-adresse-du-serveur-selon-lappareil)
15. [Tests et compilation](#15-tests-et-compilation)
16. [Inspecter la base dans phpMyAdmin](#16-inspecter-la-base-dans-phpmyadmin)
17. [Dépannage](#17-dépannage)
18. [Sécurité](#18-sécurité)
19. [Limites connues et évolutions](#19-limites-connues-et-évolutions)

---

## 1. Fonctionnalités

| Membre | Coach (également membre) | Administrateur |
|---|---|---|
| Inscription, connexion, mot de passe oublié, profil | Tout ce que fait un membre (abonnement, réservations, programmes perso) | Tableau de bord : membres, abonnements, revenus, alertes, remplissage des cours |
| Demande d'abonnement, validée par l'admin | **Bascule « Mon entraînement » / « Espace coach »** sans second compte | Membres et coachs : création, rôle, **activation / désactivation**, suppression |
| Réservation / annulation des cours (abonnement actif requis) | Demandes de suivi : accepter / refuser ; liste de ses clients | Validation des demandes d'abonnement, renouvellement + paiement |
| Annuaire des coachs, demande de suivi | Programmes pour ses clients (exercices, séries, charges, repos) | Suivis coaching : supervision, attribution directe, fin |
| Programmes personnels ou écrits par le coach | Séances réalisées par ses clients et **commentaires** | Tarifs, promotions, boutique, matériel, annonces, paiements |
| Journal de séances, courbe de poids, présences, paiements | Mesures et présences de ses clients ; planning et pointage de ses cours | Mesures, présences et planning de toute la salle |
| Notifications (abonnement, coaching, programme, commentaire, annonce, cours annulé) | Notifications (nouvelle demande, séance terminée…) | Notifications |

**Interface** : identité visuelle noir / ambre / blanc tirée du logo, thèmes clair et sombre (suivant le système), logo officiel en grand sur l'écran de connexion et en filigrane discret sur les autres écrans, mise en page adaptée au téléphone (barre de navigation en bas) et au grand écran (rail latéral avec le logo dès 900 px).

---

## 2. Architecture

```
┌──────────────────────────────┐   HTTP/JSON + JWT (Bearer)   ┌──────────────────────────────────┐        ┌──────────────────────┐
│  Application Flutter         │ ───────────────────────────▶ │  API Spring Boot (port 8080)     │  JDBC  │  MySQL / MariaDB     │
│  Windows · Android · Web     │                              │  controller → service → repository│ ─────▶ │  (XAMPP, port 3306)  │
│  écrans → services → Api     │ ◀─────────────────────────── │  Spring Security · JPA/Hibernate  │        │  base ironfit_db     │
└──────────────────────────────┘                              └──────────────────────────────────┘        └──────────────────────┘
```

### Backend (Spring Boot, `backend/`)

| Couche | Paquet | Rôle |
|---|---|---|
| Contrôleurs | `controller` | Routes REST, validation des requêtes (`@Valid`), `@PreAuthorize` pour l'admin / le staff, codes HTTP |
| Services | `service` (interfaces) + `service/impl` | Règles métier, contrôles de propriété (coach ↔ client), transactions, notifications |
| Dépôts | `repository` | Spring Data JPA : CRUD + requêtes JPQL (recherche, portée coach, agrégats) |
| Entités | `entity` | 18 entités JPA (`@Entity`), relations `@ManyToOne` avec `ON DELETE CASCADE / SET NULL` côté base |
| DTO | `dto` | Objets de requête (validés) et de réponse (jamais l'entité ni le hachage du mot de passe) |
| Sécurité | `security` | JWT (jjwt), filtre d'authentification, hachage bcrypt (+ lecture des anciens hachages scrypt), limitation de débit |
| Configuration | `config` | Spring Security + CORS, Jackson, propriétés `ironfit.*`, données initiales, dialecte MariaDB de XAMPP |
| Exceptions | `exception` | `ApiException` + `GlobalExceptionHandler` : réponses d'erreur JSON homogènes |

Versions : **Java 17**, **Spring Boot 3.5.16** (dernière version de la branche 3.x), Hibernate 6.6, MySQL Connector/J, jjwt 0.13, Maven 3.9 (wrapper `mvnw` inclus).

### Frontend (Flutter, `app/`)

- **Écrans** (`lib/screens/`) → **services** (`lib/services/`) → **client HTTP** (`lib/core/network/api_client.dart`, paquet `http`). Les écrans n'écrivent plus d'URL : chaque appel passe par un service (`AuthService`, `UserService`, `CoachService`, `ProgramService`, `PlanningService`, `AdminService`, `CatalogService`, `NotificationService`, `CrudService`).
- **État** : `StatefulWidget` + `ValueNotifier` (`Api.authChanged`, `Api.workspace`, `Api.unread`) — gestion d'état existante conservée.
- **Modèles** : `AppUser` (utilisateur connecté, typé) ; les listes restent en JSON (`Map`) car les écrans CRUD sont déclaratifs (`models/module.dart`).
- **Thème** : `lib/core/theme/app_theme.dart` (palettes claire / sombre, composants) et `brand.dart` (logo, filigrane, transitions).
- **Configuration** : `lib/core/config/app_config.dart` (adresse de l'API par plateforme, délais, ressources).

---

## 3. Structure du dépôt

```
IronFit_Flutter/
├─ 1-lancer-serveur.bat            Lance le backend (backend/start.bat)
├─ 2-lancer-app-flutter.bat        Lance l'app (Windows, ou Chrome si Visual Studio est absent)
├─ backend/                        API Spring Boot (Maven)
│  ├─ pom.xml
│  ├─ mvnw, mvnw.cmd, .mvn/        Maven Wrapper (Maven 3.9.16 téléchargé au premier lancement)
│  ├─ .env.example                 Modèle de configuration locale (copier en .env)
│  ├─ start.bat                    mvnw spring-boot:run
│  ├─ tools/sqlite-to-mysql.js     Migration unique : ancienne base SQLite → script SQL MySQL
│  ├─ data/                        (non versionné) clé JWT générée, ancienne base SQLite conservée
│  └─ src/
│     ├─ main/java/com/ironfit/
│     │  ├─ IronFitApplication.java
│     │  ├─ controller/            Auth, Member, Subscription, Coaching, Program, Workout, Class,
│     │  │                         Notification, Stats, Catalog, MemberRecord
│     │  ├─ service/ + impl/       Interfaces et implémentations métier, AccessService (règles d'accès)
│     │  ├─ repository/            Dépôts Spring Data JPA + OffsetLimit (pagination)
│     │  ├─ entity/                User, Plan, Promo, ClassSession, Booking, Payment, Equipment, Product,
│     │  │                         Announcement, Measure, Checkin, SubscriptionRequest, PasswordReset,
│     │  │                         CoachClient, Program, Exercise, Workout, Notification (+ Role)
│     │  ├─ dto/                   Requêtes / réponses par domaine
│     │  ├─ security/              JwtService, JwtAuthFilter, PasswordHasher, RateLimiter, CurrentUser…
│     │  ├─ config/                SecurityConfig, JacksonConfig, AppProperties, DataInitializer, XamppMariaDbDialect
│     │  └─ exception/             ApiException, ErrorResponse, GlobalExceptionHandler
│     ├─ main/resources/application.properties
│     └─ test/                     31 tests d'intégration (MockMvc + H2 en mode MySQL)
└─ app/                            Application Flutter
   ├─ pubspec.yaml
   ├─ assets/images/               ironfit_logo.png (officiel), ironfit_logo_transparent.png (filigrane)
   ├─ lib/
   │  ├─ main.dart
   │  ├─ core/config/app_config.dart
   │  ├─ core/network/             api_client.dart (Api), token_store.dart (stockage sécurisé du JWT)
   │  ├─ core/theme/               app_theme.dart, brand.dart
   │  ├─ models/                   app_user.dart, module.dart (modules CRUD déclaratifs)
   │  ├─ services/                 auth, user, coach, program, planning, admin, catalog, notification
   │  ├─ widgets/                  common_widgets.dart (cartes, indicateurs, graphiques…), form_dialog.dart
   │  └─ screens/                  auth, home_shell, member, coaches, program, coach, admin, planning,
   │                               crud, notifications
   ├─ test/                        Tests unitaires, widgets et intégration avec le backend
   └─ android/ windows/ web/       Plateformes
```

---

## 4. Logiciels requis et versions

| Logiciel | Version | Vérifié avec | Pour |
|---|---|---|---|
| **JDK** | 17 ou plus | Temurin 17.0.19 | Backend |
| **Maven** | facultatif (wrapper inclus) | 3.9.16 | Backend |
| **XAMPP** (MySQL / MariaDB) | 8.x | MariaDB 10.4.32 | Base de données + phpMyAdmin |
| **Flutter** | 3.35 ou plus (Dart 3.9+) | 3.47.7 / Dart 3.13.5 | Application |
| Visual Studio 2022+ « Développement Desktop en C++ » | — | — | `flutter run -d windows` |
| Mode développeur Windows | — | — | Plugins Flutter sous Windows |
| Android Studio + SDK | — | — | Émulateur / téléphone Android |
| Chrome ou Edge | — | Chrome 155 | Version Web |
| Node.js 22.13+ | facultatif | 24.15 | Uniquement pour migrer une ancienne base SQLite (`tools/`) |

Vérifier : `java -version`, `flutter doctor`, panneau de contrôle XAMPP.

---

## 5. Installation de l'application Flutter

```bash
cd app
flutter pub get      # paquets : http, shared_preferences, flutter_secure_storage, flutter_localizations
flutter analyze
```

Le logo est empaqueté comme ressource (`pubspec.yaml` → `flutter: assets:`), il fonctionne donc sur toutes les plateformes.

---

## 6. Java, Maven et Spring Boot

1. Installer un **JDK 17** (par exemple [Eclipse Temurin](https://adoptium.net)) et vérifier `java -version`.
2. Aucune installation de Maven n'est nécessaire : `backend/mvnw.cmd` (Windows) ou `backend/mvnw` télécharge la bonne version au premier lancement.
   - Dans **PowerShell**, préfixer par `.\` : `.\mvnw.cmd spring-boot:run` (dans l'invite `cmd` : `mvnw.cmd spring-boot:run`).
   - Toujours indiquer un objectif Maven (`spring-boot:run`, `test`, `package`…) : `.\mvnw.cmd` seul affiche « No goals have been specified ».
3. Dépendances (téléchargées automatiquement) : Spring Web, Spring Data JPA, Validation, Spring Security, MySQL Connector/J, jjwt, BouncyCastle (lecture des anciens mots de passe scrypt), Lombok ; tests : Spring Boot Test, Spring Security Test, H2.

```bash
cd backend
.\mvnw.cmd -q -DskipTests package    # compile et produit target/ironfit-backend-3.0.0.jar
```

---

## 7. XAMPP et démarrage de MySQL

1. Installer [XAMPP](https://www.apachefriends.org).
2. Ouvrir le **XAMPP Control Panel** et cliquer sur **Start** devant **MySQL** (et **Apache**, nécessaire pour phpMyAdmin).
3. MySQL écoute sur le port **3306**, utilisateur `root` **sans mot de passe** (configuration par défaut de XAMPP).

> Le « MySQL » de XAMPP est en réalité **MariaDB 10.4**, compatible MySQL. Le backend utilise par défaut un dialecte Hibernate adapté (`XamppMariaDbDialect`).

**Conflit de port fréquent** : si un autre MySQL est installé comme service Windows (ex. `MySQL97`), il occupe déjà le port 3306 et MySQL de XAMPP ne démarre pas. Deux solutions :

- **A — Arrêter l'autre service** (recommandé si vous n'en avez pas besoin) : `services.msc` → *MySQL97* → **Arrêter** (et *Type de démarrage : Manuel*), ou en administrateur : `net stop MySQL97`.
- **B — Changer le port de XAMPP** en 3307 : dans `C:\xampp\mysql\bin\my.ini`, remplacer `port=3306` par `port=3307` (sections `[client]` et `[mysqld]`) ; dans `C:\xampp\phpMyAdmin\config.inc.php`, ajouter `$cfg['Servers'][$i]['port'] = '3307';` ; puis dans `backend/.env` : `DB_URL=jdbc:mysql://localhost:3307/ironfit_db?createDatabaseIfNotExist=true&useUnicode=true&characterEncoding=UTF-8&connectionTimeZone=UTC`.

Le backend Spring Boot **ne s'exécute pas dans XAMPP** : XAMPP fournit uniquement MySQL ; Spring Boot est une application Java lancée séparément.

---

## 8. Base de données : création et configuration

- **Création automatique** : au premier démarrage, le backend crée la base `ironfit_db` (`createDatabaseIfNotExist=true`) puis toutes les tables (`spring.jpa.hibernate.ddl-auto=update`).
- **Données initiales** : si la table `users` est vide, le compte `admin` est créé (mot de passe `ADMIN_PASSWORD`) et, si `SEED_DEMO=true`, des données de démonstration.
- **Création manuelle** (facultatif) dans phpMyAdmin → *Nouvelle base de données* → `ironfit_db`, interclassement `utf8mb4_general_ci`.

### Tables (schéma généré par JPA)

| Table | Contenu | Relations |
|---|---|---|
| `users` | Comptes : rôle (`admin`/`coach`/`athlete`), `active`, `token_version`, `password_hash`, abonnement | `plan_id → plans` (SET NULL) |
| `plans`, `promos`, `products`, `equipment` | Tarifs, offres, boutique, matériel | |
| `requests` | Demandes d'abonnement | `member_id → users`, `plan_id → plans` (CASCADE) |
| `payments`, `measures`, `checkins` | Paiements, mesures, présences | `member_id → users` (CASCADE) |
| `classes`, `bookings` | Cours hebdomadaires (`week_day` 0 = lundi, `start_time`), réservations (unique membre/cours) | `coach_id → users` (SET NULL) ; `bookings → users, classes` (CASCADE) |
| `coach_clients` | Relation coach ↔ client (`pending`, `active`, `declined`, `ended`), unique par couple | `coach_id, client_id → users` (CASCADE) |
| `programs`, `exercises` | Programmes (coach NULL = personnel) et exercices | `client_id → users` (CASCADE), `coach_id → users` (SET NULL), `program_id → programs` (CASCADE) |
| `workouts` | Séances réalisées + commentaire du coach | `user_id → users` (CASCADE), `program_id → programs` (SET NULL) |
| `notifications`, `announcements`, `resets` | Notifications, annonces (`author_id`), codes de réinitialisation | → `users` |

Quelques colonnes portent un nom différent du champ JSON car le mot est réservé en SQL : `exercises.load_text` (« load »), `exercises.day_label` (« day »), `promos.valid_until` (« until »), `classes.week_day` / `start_time` (« day » / « time »).

### Migration depuis l'ancienne base SQLite (version Node.js)

Les données de l'ancienne version (`backend/data/gym.db`) ont été **migrées dans `ironfit_db`** lors de la mise en place (7 comptes, cours, réservations, paiements, suivis, notifications). Les anciens mots de passe restent valables : ils sont vérifiés (scrypt) puis convertis en bcrypt à la première connexion. Pour refaire une migration :

```bash
# 1. Créer le schéma : lancer une fois le backend sur la base cible (SEED_DEMO=false), puis l'arrêter
# 2. Générer le script (Node.js 22.13+, base SQLite ouverte en lecture seule)
cd backend
node tools/sqlite-to-mysql.js data/gym.db > ironfit-import.sql
# 3. Importer (le script VIDE d'abord les tables IronFit) — ou phpMyAdmin → Importer
C:\xampp\mysql\bin\mysql.exe -u root ironfit_db < ironfit-import.sql
```

Sauvegarde : phpMyAdmin → `ironfit_db` → **Exporter**, ou `C:\xampp\mysql\bin\mysqldump.exe -u root ironfit_db > sauvegarde.sql`.

---

## 9. Variables d'environnement

Le backend lit `backend/.env` s'il existe (modèle : [`backend/.env.example`](backend/.env.example)) ; les variables d'environnement du système sont prioritaires. **Aucun secret n'est versionné** et l'application Flutter n'en contient aucun.

| Variable | Défaut | Rôle |
|---|---|---|
| `DB_URL` | `jdbc:mysql://localhost:3306/ironfit_db?createDatabaseIfNotExist=true&…` | Connexion JDBC |
| `DB_USERNAME` / `DB_PASSWORD` | `root` / *(vide)* | Identifiants MySQL |
| `DB_DIALECT` | `com.ironfit.config.XamppMariaDbDialect` | `org.hibernate.dialect.MySQLDialect` pour un vrai MySQL 8/9 |
| `DDL_AUTO` | `update` | `validate` en production (schéma géré à part) |
| `PORT` / `HOST` | `8080` / `0.0.0.0` | Écoute HTTP (`0.0.0.0` = accessible depuis le réseau local) |
| `IRONFIT_JWT_SECRET` | *(généré dans `data/jwt.secret`)* | Clé HMAC des jetons, 32 caractères min. |
| `TOKEN_DAYS` | `7` | Durée de session |
| `CORS_ORIGINS` | `*` | Origines autorisées (Flutter Web) |
| `RATE_LIMIT` | `10` | Tentatives d'authentification / minute / IP / route |
| `ADMIN_PASSWORD` | `admin123` | Compte `admin` créé sur base vide |
| `SEED_DEMO` | `true` | Données de démonstration sur base vide |
| `SHOW_RESET_CODE` | `true` | Code « mot de passe oublié » renvoyé à l'app (démo) |

---

## 10. Démarrer le backend

Prérequis : MySQL démarré dans XAMPP.

```bash
cd backend
.\mvnw.cmd spring-boot:run          # Windows (ou double-clic sur 1-lancer-serveur.bat)
./mvnw spring-boot:run              # macOS / Linux
# ou : java -jar target/ironfit-backend-3.0.0.jar
```

Le serveur répond sur `http://localhost:8080/api`. Vérification :

```bash
curl -X POST http://localhost:8080/api/login -H "Content-Type: application/json" -d "{\"login\":\"admin\",\"password\":\"admin123\"}"
```

Comptes disponibles : ceux de votre ancienne base (migrés), ou, sur une base neuve avec `SEED_DEMO=true` : `admin` / `admin123`, `sami` / `1234` (coach), `leila` / `1234` (**coach et membre abonnée**), `youssef` / `1234`, `amira` / `1234`.

---

## 11. Démarrer l'application Flutter

```bash
cd app
flutter run -d windows        # Visual Studio requis (ou 2-lancer-app-flutter.bat : bascule sur Chrome sinon)
flutter run -d chrome         # Web
flutter run -d emulator-5554  # Émulateur Android
```

L'adresse du serveur se règle dans l'app : roue dentée sur l'écran de connexion, ou **Profil → Adresse du serveur** (voir §14).

---

## 12. API REST

Préfixe `/api`, JSON en `snake_case`. Toutes les routes exigent `Authorization: Bearer <jeton>` sauf **public**. Créations : **201 Created** + `{"id": …}` ; actions : **200** + `{"ok": true}`. Pagination `?limit=` (1–500) & `?offset=` sur les listes, recherche `?q=`.

Erreurs (format unique) :

```json
{ "error": "Valeur invalide : Jour", "status": 400, "timestamp": "2026-10-21T22:27:39Z", "fields": { "day": "Valeur invalide : Jour" } }
```

Codes : 400 (validation / JSON), 401 (non connecté, session expirée ou compte désactivé), 403 (rôle ou propriété), 404, 405, 409 (doublon, conflit), 413, 429 (trop de tentatives), 500.

| Domaine | Routes | Accès |
|---|---|---|
| Authentification | `POST /signup` · `POST /login` · `POST /forgot` · `POST /reset` | public (limité en débit) |
| Compte | `GET /me` · `PUT /profile` · `POST /password` (renvoie un nouveau jeton) | connecté |
| Membres | `GET /members?q=&role=&active=` | admin (tous) · coach (**ses clients actifs**) |
| | `GET /members/{id}` | admin, son coach, soi |
| | `POST /members` · `PUT /members/{id}` · `DELETE /members/{id}` · `POST /members/{id}/status` · `POST /members/{id}/renew` | admin |
| Annuaire | `GET /coaches` | connecté |
| Abonnements | `GET /requests` (membre : les siennes ; admin : en attente) · `POST /requests` · `POST /requests/{id}/approve\|reject` (admin) · `/cancel` (auteur) | |
| Coaching | `GET /coaching/mine` · `GET /coaching/clients` (coach) · `GET /coaching?status=` (admin) · `POST /coaching/request` (membre) · `POST /coaching/assign` (admin) · `POST /coaching/{id}/accept\|decline` (coach concerné) · `/end` (coach, client ou admin) | |
| Programmes | `GET /programs?scope=personal\|coaching\|all&client_id=` · `GET/PUT/DELETE /programs/{id}` · `POST /programs` · `POST /programs/{id}/exercises` · `PUT/DELETE /exercises/{id}` | client, coach auteur (relation active), admin (lecture) |
| Séances | `GET /workouts?user_id=&program_id=` · `POST /workouts` · `DELETE /workouts/{id}` · `POST /workouts/{id}/feedback` | soi ; coach : séances de **ses** programmes |
| Planning | `GET /classes` · `POST/PUT/DELETE /classes[/{id}]` (admin ; coach : ses cours) · `POST /book` (membre) · `GET /classes/{id}/participants` · `POST /classes/{id}/present` (admin, coach du cours) | |
| Catalogue | `GET /plans\|promos\|products\|announcements` (connecté) ; écriture : admin (annonces : admin + coach pour les siennes) ; `/equipment` : admin + coach | |
| Données membre | `GET /payments\|measures\|checkins?member_id=&scope=clients` ; écriture paiements : admin ; mesures : admin, soi, son coach ; présences : admin, son coach | |
| Notifications | `GET /notifications` · `POST /notifications/{id}/read` · `POST /notifications/read-all` | connecté |
| Statistiques | `GET /stats` | admin (global) · coach (ses clients et cours) |

Exemples :

```bash
TOKEN=$(curl -s -X POST localhost:8080/api/login -H "Content-Type: application/json" \
  -d '{"login":"sami","password":"1234"}' | node -pe "JSON.parse(require('fs').readFileSync(0)).token")

curl -s localhost:8080/api/coaching/clients -H "Authorization: Bearer $TOKEN"
curl -s -X POST localhost:8080/api/programs -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"Gainage","goal":"Tonus","client_id":4}'
curl -s "localhost:8080/api/members?q=karray&limit=20" -H "Authorization: Bearer $TOKEN"
```

---

## 13. Authentification et rôles

1. `POST /api/login` (identifiant **ou** e-mail) → `{ token, user }`. Mots de passe hachés en **bcrypt** ; les comptes migrés (scrypt) sont convertis à la connexion ; temps de réponse identique que l'identifiant existe ou non.
2. **JWT HS256** : sujet = id du compte, claim `tv` = version des jetons, expiration `TOKEN_DAYS`.
3. À chaque requête, `JwtAuthFilter` vérifie la signature, l'expiration, puis **en base** : compte existant, **actif**, même `token_version`. Changer / réinitialiser son mot de passe ou être désactivé incrémente cette version → toutes les sessions existantes sont coupées.
4. Autorités : `ROLE_ADMIN`, `ROLE_COACH`, `ROLE_MEMBER` (athlètes **et** coachs). `@PreAuthorize` protège les routes admin / staff ; les services contrôlent la propriété (coach de ce client, auteur du programme, propriétaire de la mesure…). Masquer un bouton dans l'app ne suffit jamais : le serveur refuse.
5. Côté Flutter, le jeton est conservé par `flutter_secure_storage` (Keystore Android, DPAPI Windows, WebCrypto) ; un 401 déconnecte automatiquement.

**Double rôle coach / membre** : un seul compte. *Mon entraînement* utilise `programs?scope=personal`, ses propres mesures et séances ; *Espace coach* utilise `scope=coaching`, `measures?scope=clients` et `/members` (ses clients). Un coach n'accède aux données d'un membre **que si la relation est active**.

| Action | Membre | Coach | Admin |
|---|:-:|:-:|:-:|
| S'abonner, réserver | ✅ | ✅ (pas ses propres cours) | — |
| Programmes personnels, journal, ses mesures | ✅ | ✅ | lecture |
| Données d'un autre membre | — | ses clients actifs | ✅ |
| Programmes / commentaires pour un client | — | ses clients actifs | — |
| Cours : créer, modifier, pointer | — | ses cours | ✅ |
| Annonces | lecture | les siennes | ✅ |
| Matériel | — | ✅ | ✅ |
| Tarifs, promos, boutique, paiements, comptes | — | — | ✅ |
| Statistiques | — | son périmètre | global |

---

## 14. Adresse du serveur selon l'appareil

| Appareil | Adresse dans l'app |
|---|---|
| Windows (desktop) / navigateur sur le PC | `http://localhost:8080/api` (défaut) |
| Émulateur Android | `http://10.0.2.2:8080/api` (défaut sur Android) |
| Téléphone réel (même Wi-Fi) | `http://IP-DU-PC:8080/api` (`ipconfig` pour l'IP) |

Pour un téléphone réel : le backend écoute déjà sur toutes les interfaces (`HOST=0.0.0.0`) ; autoriser **Java** (ou le port 8080) dans le pare-feu Windows. Android autorise le HTTP local (`usesCleartextTraffic` dans le manifeste) ; en production, utiliser HTTPS et retirer cet attribut.

---

## 15. Tests et compilation

```bash
# Backend : 31 tests d'intégration (MockMvc, base H2 en mode MySQL — XAMPP non requis)
cd backend
.\mvnw.cmd test

# Application : analyse + 18 tests unitaires / widgets
cd app
flutter analyze
flutter test --exclude-tags integration

# Intégration Flutter ↔ Spring Boot ↔ MySQL (3 tests, modifient des données → base dédiée) — invite cmd
cd backend
set "DB_URL=jdbc:mysql://localhost:3306/ironfit_e2e?createDatabaseIfNotExist=true&connectionTimeZone=UTC"
set "DDL_AUTO=create-drop"
mvnw.cmd spring-boot:run
# dans un autre terminal
cd app
flutter test test/backend_integration_test.dart        # IRONFIT_API_URL pour une autre adresse

# Compilation
cd app
flutter build web             # app/build/web
flutter build windows         # Visual Studio requis
flutter build apk --release   # SDK Android requis
cd ../backend
.\mvnw.cmd package            # backend/target/ironfit-backend-3.0.0.jar
```

Couverture : authentification, jetons falsifiés, révocation, désactivation, réinitialisation, limitation de débit, erreurs HTTP, droits par rôle, isolation coach ↔ clients, double rôle, cycle programme → séance → commentaire → notifications, validation des cours / mesures / séances, annonces, abonnements, statistiques, connexion d'un compte migré (scrypt → bcrypt) ; côté Flutter : client API, migration de l'adresse et du jeton, navigation par rôle (téléphone et grand écran), logo et formulaires.

---

## 16. Inspecter la base dans phpMyAdmin

1. XAMPP Control Panel → **Start** Apache et MySQL.
2. Ouvrir **http://localhost/phpmyadmin**.
3. Dans la colonne de gauche, cliquer sur **`ironfit_db`**.
4. Choisir une table (ex. `users`) → onglet **Structure** (colonnes, index) ou **Parcourir** (enregistrements). Les relations : onglet **Structure** → **Vue relationnelle** (clés étrangères avec `ON DELETE`) ; vue d'ensemble : `ironfit_db` → **Concepteur**.
5. Vérifier qu'une action de l'app est enregistrée : par exemple réserver un cours dans Flutter puis **Parcourir** la table `bookings`, ou créer un programme et regarder `programs` / `exercises`. Requête utile (onglet **SQL**) :

```sql
SELECT u.name, c.title, c.week_day, c.start_time
FROM bookings b JOIN users u ON u.id = b.user_id JOIN classes c ON c.id = b.class_id;
```

Les colonnes booléennes (`active`, `seen`) sont de type `bit(1)` et s'affichent `1` / `0` dans phpMyAdmin.

---

## 17. Dépannage

| Symptôme | Solution |
|---|---|
| `Communications link failure` / `Connection refused` au démarrage | MySQL n'est pas démarré dans XAMPP, ou mauvais port dans `DB_URL`. |
| `Access denied for user 'root'@'localhost'` | Un autre serveur MySQL occupe le port 3306 (ex. service `MySQL97`) : voir §7, ou renseigner `DB_PASSWORD`. |
| MySQL de XAMPP ne démarre pas (« Port 3306 in use ») | Arrêter le service MySQL concurrent ou passer XAMPP en 3307 (§7). |
| `Plugin caching_sha2_password could not be loaded` (client XAMPP) | Vous vous connectez à un MySQL 8/9 avec le client MariaDB de XAMPP : même cause (port 3306 occupé par un autre MySQL). |
| « Serveur injoignable » dans l'app | Backend non lancé, ou mauvaise adresse (§14). L'ancienne adresse `:3000` est remplacée automatiquement. |
| Téléphone : pas de réponse | Même Wi-Fi, IP du PC, pare-feu autorisant Java / port 8080. |
| `Unable to find suitable Visual Studio toolchain` | Installer Visual Studio « Développement Desktop en C++ », ou `flutter run -d chrome`. |
| `Building with plugins requires symlink support` | Activer le Mode développeur Windows (`start ms-settings:developers`). |
| `Port 8080 was already in use` | Arrêter l'autre processus ou `PORT=8081` (et adapter l'adresse dans l'app). |
| Déconnecté après un changement de mot de passe | Normal : les anciens jetons sont révoqués. |
| Caractères accentués illisibles dans la console Windows | Affichage de la console uniquement ; les données sont en `utf8mb4` (vérifier dans phpMyAdmin). |

---

## 18. Sécurité

- **Secrets** : `backend/.env`, `backend/data/` (clé JWT générée, ancienne base) et les exports SQL sont exclus de Git. En production : `IRONFIT_JWT_SECRET` fort, `ADMIN_PASSWORD` fort, `SHOW_RESET_CODE=false`, `SEED_DEMO=false`.
- **Base** : créer un utilisateur MySQL dédié (droits limités à `ironfit_db`) plutôt que `root`, avec un mot de passe ; `DDL_AUTO=validate` en production.
- **HTTPS** : placer l'API derrière un reverse proxy TLS, restreindre `CORS_ORIGINS` à l'origine de la version Web, retirer `usesCleartextTraffic` du manifeste Android.
- **Journalisation** : aucune donnée sensible (ni mot de passe, ni jeton, ni code de réinitialisation) ; les erreurs 500 sont journalisées côté serveur et renvoyées sans détail technique.
- **Historique Git** : d'anciens commits contiennent l'ancienne base SQLite et une clé (régénérée depuis) ; purger l'historique (`git filter-repo --path backend/data --invert-paths` + push forcé) si le dépôt est partagé.

---

## 19. Limites connues et évolutions

- **Vérifié** : compilation et 31 tests du backend, démarrage sur MariaDB 10.4 (XAMPP), migration des données SQLite, analyse Flutter, 18 tests Flutter, 3 tests d'intégration Flutter ↔ Spring Boot ↔ MariaDB, compilation Web et parcours réel dans Chrome (connexion, coach / membre, administration, thèmes clair et sombre, grand écran). **Non vérifié** dans cet environnement : compilations Windows (Visual Studio absent) et Android (SDK absent), connexion à un serveur MySQL 8/9 (identifiants du service local inconnus).
- Schéma géré par `ddl-auto=update` : pratique en local mais pas de migrations versionnées. Flyway n'a pas été ajouté car la version Community récente ne prend plus en charge MariaDB 10.4 (XAMPP) ; à introduire avec un serveur MySQL 8+.
- Spring Boot 3.5 est la dernière branche 3.x ; une migration vers Spring Boot 4 (Jackson 3, Spring Security 7) est à prévoir.
- Pas d'envoi d'e-mail (mot de passe oublié en mode démo) ni de notifications push ; pas de paiement en ligne.
- Planning hebdomadaire récurrent (pas de cours datés) ; limitation de débit en mémoire (une seule instance du serveur).
- Listes affichées à partir du JSON (modèles typés pour l'utilisateur connecté uniquement).
- Interface en français uniquement.
