import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum TravelMode { driving, walking }

class StartingPlace {
  final String name;
  final LatLng point;
  const StartingPlace(this.name, this.point);
}

class GymRoute {
  final List<LatLng> points;
  final double meters, seconds;
  const GymRoute(this.points, this.meters, this.seconds);
  String get distance => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
  String get duration {
    final minutes = (seconds / 60).ceil();
    return minutes < 60
        ? '${minutes < 1 ? 1 : minutes} min'
        : '${minutes ~/ 60} h ${minutes % 60} min';
  }
}

/// Coordinates stay in memory. Public OSM services receive only explicit searches/routes.
class GymRouteService {
  final http.Client client;
  GymRouteService({http.Client? client}) : client = client ?? http.Client();
  void dispose() => client.close();

  Future<List<StartingPlace>> search(String query) async {
    final response = await client
        .get(
          Uri.https('nominatim.openstreetmap.org', '/search', {
            'q': query,
            'format': 'jsonv2',
            'limit': '5',
            'accept-language': 'fr',
          }),
          headers: kIsWeb
              ? null
              : {'User-Agent': 'IronFit/3.0 (gym visitor directions)'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('Recherche indisponible. Réessayez plus tard.');
    return (jsonDecode(response.body) as List)
        .map(
          (p) => StartingPlace(
            p['display_name'] as String,
            LatLng(
              double.parse(p['lat'] as String),
              double.parse(p['lon'] as String),
            ),
          ),
        )
        .toList();
  }

  Future<GymRoute> route(LatLng from, LatLng to, TravelMode mode) async {
    final profile = mode == TravelMode.walking ? 'foot' : 'car';
    final response = await client
        .get(
          Uri.https(
            'routing.openstreetmap.de',
            '/routed-$profile/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
            {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw Exception('Service d’itinéraire indisponible.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw Exception('Aucun itinéraire disponible pour ce trajet.');
    }
    final r = data['routes'][0];
    final points = (r['geometry']['coordinates'] as List)
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
    if (points.length < 2) throw Exception('Itinéraire incomplet.');
    return GymRoute(
      points,
      (r['distance'] as num).toDouble(),
      (r['duration'] as num).toDouble(),
    );
  }
}
