# IronFit — application Flutter

Documentation complète (architecture, backend Spring Boot, MySQL / XAMPP, rôles, API, tests) : voir le [README à la racine du dépôt](../README.md).

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags integration
flutter run -d windows   # ou -d chrome, ou un appareil Android
```

L'application attend le backend sur `http://localhost:8080/api` (émulateur Android : `http://10.0.2.2:8080/api`) ; l'adresse se modifie dans l'app (roue dentée / Profil).
