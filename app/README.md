# IronFit — application Flutter

Documentation complète (architecture, backend Spring Boot, MySQL / XAMPP, rôles, API, tests) : voir le [README à la racine du dépôt](../README.md).

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags integration
flutter run -d windows   # ou -d chrome, ou un appareil Android
```

L'application attend le backend sur `http://localhost:8080/api` (émulateur Android : `http://10.0.2.2:8080/api`) ; l'adresse se modifie dans l'app (roue dentée / Profil).

## Carte de la salle

La page « Notre salle » est accessible depuis l’accueil membre et le profil de tous les rôles.
Copier `gym-location.example.json` vers `gym-location.json` puis renseigner l’adresse et les coordonnées vérifiées de la salle. L’emplacement fourni à Cebalat Ben Ammar est utilisé par défaut. `GYM_DETAILS` peut contenir les indications d’accès (entrée, étage, parking).

Lancer avec `flutter run -d chrome --dart-define-from-file=gym-location.json` (ou remplacer `chrome` par `windows`). Pour une livraison : `flutter build web --dart-define-from-file=gym-location.json`. Un redémarrage complet est nécessaire après modification de ces valeurs.

La carte utilise flutter_map et les tuiles OpenStreetMap, avec attribution visible. Une connexion Internet est nécessaire. Les itinéraires Google Maps utilisent exactement les mêmes coordonnées que le marqueur. La localisation est facultative et demandée uniquement sur action explicite ; un départ peut aussi être recherché manuellement.

Références : https://docs.fleaflet.dev/ et https://operations.osmfoundation.org/policies/tiles/ . Avant un déploiement à grande échelle, choisir un fournisseur de tuiles adapté au trafic.

### Itinéraire vers Notre Salle

L’emplacement par défaut provient du Plus Code fourni `V5XM+H2V, Cebalat Ben Ammar`, récupéré en `8F8GV5XM+H2V` puis décodé suivant la spécification Open Location Code : centre `36.8989875, 10.182546875`. Les paramètres GYM_* restent disponibles pour une autre implantation ; les valeurs vides d’un fichier de configuration masquent la carte.

La permission de localisation est demandée uniquement après « Utiliser ma position ». Sur le Web, servir avec HTTPS ou localhost. Sans permission, rechercher une adresse puis choisir un résultat. Les positions restent en mémoire et ne sont pas enregistrées dans les préférences ou le backend. Les requêtes sont transmises aux services externes pour géocodage et calcul du trajet.

Carte : OpenStreetMap. Recherche explicite (sans autocomplétion) : Nominatim, avec sélection parmi cinq résultats. Itinéraires : routing.openstreetmap.de, profils distincts routed-car et routed-foot. Distance et durée viennent de la route calculée, sans trafic en temps réel. Google Maps assure la navigation externe avec le mode et les coordonnées sélectionnés. Aucun abonnement Google Maps ni clé API n’est nécessaire pour cette implémentation.

Les services publics ont des limites d’usage et de disponibilité. Pour un déploiement avec trafic important, utiliser un fournisseur contractuel ou une instance dédiée. Vérifier la géolocalisation, les tuiles et les accès CORS sur le domaine HTTPS final. Tests de contrat : `flutter test test/gym_route_service_test.dart`.
