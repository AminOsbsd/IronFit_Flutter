import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:ironfit/core/config/gym_location.dart';
import 'package:ironfit/services/gym_route_service.dart';

void main() {
  test('supplied Plus Code is the default venue', () {
    final gym = GymLocation.configured!;
    expect(gym.latitude, 36.8989875);
    expect(gym.longitude, 10.182546875);
  });
  for (final mode in TravelMode.values) {
    test(
      'route uses the correct transport profile and GeoJSON coordinate order: $mode',
      () async {
        final service = GymRouteService(
          client: MockClient((request) async {
            expect(
              request.url.path,
              contains(
                mode == TravelMode.walking ? 'routed-foot' : 'routed-car',
              ),
            );
            expect(
              request.url.path,
              contains('10.0,36.0;10.182546875,36.8989875'),
            );
            return http.Response(
              jsonEncode({
                'code': 'Ok',
                'routes': [
                  {
                    'distance': 2500,
                    'duration': 900,
                    'geometry': {
                      'coordinates': [
                        [10, 36],
                        [10.182546875, 36.8989875],
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );
        final route = await service.route(
          const LatLng(36, 10),
          const LatLng(36.8989875, 10.182546875),
          mode,
        );
        expect(route.points.last.latitude, 36.8989875);
        expect(route.distance, '2.5 km');
        expect(route.duration, '15 min');
        service.dispose();
      },
    );
  }
  test('missing routes fail rather than showing fabricated distance', () async {
    final service = GymRouteService(
      client: MockClient(
        (_) async => http.Response('{"code":"NoRoute","routes":[]}', 200),
      ),
    );
    await expectLater(
      service.route(const LatLng(0, 0), const LatLng(1, 1), TravelMode.walking),
      throwsException,
    );
    service.dispose();
  });
  test('address search returns selectable alternatives', () async {
    final service = GymRouteService(
      client: MockClient(
        (_) async => http.Response(
          '[{"display_name":"Tunis","lat":"36.8","lon":"10.1"}]',
          200,
        ),
      ),
    );
    final results = await service.search('Tunis');
    expect(results.single.name, 'Tunis');
    expect(results.single.point.longitude, 10.1);
    service.dispose();
  });
}
