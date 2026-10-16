# 💪 IronFit – Application Flutter + serveur SQLite

```
IronFit_Flutter/
├─ backend/   Serveur Node.js + base SQLite (aucune dépendance npm)
├─ app/       Application Flutter (Windows / Android)
├─ 1-lancer-serveur.bat
└─ 2-lancer-app-flutter.bat
```

## Prérequis (Windows)
1. **Node.js LTS 22.13+** : https://nodejs.org
2. **Flutter SDK** : https://docs.flutter.dev/get-started/install/windows
   - Pour `flutter run -d windows` : Visual Studio avec la charge « Développement Desktop en C++ »
   - Activer le **Mode développeur** Windows (Paramètres → Pour les développeurs), requis par les plugins Flutter
   - Pour un téléphone/émulateur Android : Android Studio + SDK (`flutter doctor` vous guide)

## Lancer
1. Double-clic sur **`1-lancer-serveur.bat`** (laisser la fenêtre ouverte).
2. Double-clic sur **`2-lancer-app-flutter.bat`** : crée les dossiers windows/android au premier lancement, installe les paquets, lance l'app.
   (ou à la main : `cd app` → `flutter create --platforms=windows,android .` → `flutter pub get` → `flutter run -d windows`)

Adresse du serveur : roue dentée sur l'écran de connexion ou Profil → Adresse du serveur.
- Windows : `http://localhost:3000` (défaut) · Émulateur Android : `http://10.0.2.2:3000` (défaut sur Android)
- Téléphone réel : `http://IP-DU-PC:3000` (IP affichée par le serveur, même Wi-Fi, autoriser Node dans le pare-feu)

## Comptes de démo
admin / admin123 · sami / 1234 (coach) · youssef / 1234 (athlète)

## Modules (11 CRUD)
Athlètes · Coachs · Séances & réservations · Abonnements & tarifs · Promotions · Paiements ·
Matériel · Boutique & stock · Annonces · Suivi physique · Présences
+ Connexion, inscription, mot de passe oublié (code 6 chiffres), changement de mot de passe, tableau de bord par rôle.

Droits : **admin** = tout ; **coach** = séances, matériel, annonces, suivi, présences, lecture des athlètes ;
**athlète** = lecture + réservations + ses propres paiements/mesures/présences.


## Parcours par rôle (v2)
**Athlète** — 5 onglets : Accueil (carte membre, statut d'abonnement, prochaines séances, annonces) ·
Planning (agenda par jour, réserver/annuler) · Explorer (tarifs avec « Choisir », offres, boutique, annonces) ·
Mon espace (progression avec courbe de poids, présences, paiements) · Profil (modifier ses infos, mot de passe).
Flux : inscription → « Choisir » un tarif → demande envoyée → l'admin valide (paiement reçu) → abonnement activé → réservations possibles.
Sans abonnement actif, la réservation est refusée.

**Coach** — Accueil (indicateurs, alertes, ses séances du jour) · Planning (participants de chaque séance, pointage de présence le jour J) · Gestion (séances, matériel, annonces, suivi, présences, athlètes en lecture).

**Admin** — Accueil : alertes (demandes à valider, abonnements qui expirent, stock bas, matériel en maintenance),
revenus par mois, remplissage des séances, abonnements à renouveler (bouton Renouveler = prolonge + enregistre le paiement) ·
Gestion : les 11 modules CRUD + Demandes d'abonnement.

## Ajouter un module
- Serveur : ajouter une table dans `server.js` + une ligne dans `ENT` (colonnes, rôles d'écriture, colonne « propriétaire » optionnelle).
- App : ajouter un bloc `Module(...)` dans `app/lib/modules.dart` (champs + titre + sous-titre). Le CRUD complet apparaît tout seul.

## Production
- `set SHOW_RESET_CODE=false` avant `node server.js` et brancher un envoi d'e-mail dans `/api/forgot`.
- Sauvegarde : copier `backend/data/gym.db`. Changer le mot de passe admin.

## Architecture du code Flutter (`app/lib/`)
```
lib/
├─ main.dart                     Point d'entrée, thème, routage selon connexion
├─ models/
│  └─ module.dart                Module, Field (définition d'un CRUD), Refs (listes déroulantes), liste des 11 modules
├─ services/
│  └─ api_service.dart           Api : tous les appels réseau vers le serveur (login, CRUD, token, session)
├─ widgets/
│  └─ common_widgets.dart        Empty, kpiCard, sectionTitle, BarsPainter, LinePainter : composants réutilisés
└─ screens/
   ├─ auth_screen.dart           Connexion, inscription, mot de passe oublié
   ├─ home_shell.dart            Barre de navigation, Gestion (grille des modules), Profil
   ├─ crud_screen.dart           Écran CRUD générique (liste + formulaire) utilisé par les 11 modules
   ├─ planning_screen.dart       Planning par jour, réservations, participants, pointage
   ├─ athlete_screens.dart       Écrans spécifiques à l'athlète (accueil, explorer, mon espace)
   └─ staff_screens.dart         Écrans spécifiques à l'admin/coach (tableau de bord, demandes)
```
Un modèle ou service n'importe jamais un écran ; seuls les écrans importent modèles, services et widgets. C'est la base attendue dans un rapport de projet (séparation données / logique réseau / présentation).
