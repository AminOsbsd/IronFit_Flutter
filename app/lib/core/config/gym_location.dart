/// Venue from supplied Plus Code 8F8GV5XM+H2V (cell center).
/// Optional build-time overrides are validated; invalid values disable the map.
class GymLocation {
  final String name, address, details;
  final double latitude, longitude;
  const GymLocation({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.details = '',
  });

  static GymLocation? parse({
    required String latitude,
    required String longitude,
    required String address,
    String name = 'IronFit',
    String details = '',
  }) {
    final lat = double.tryParse(latitude.trim());
    final lng = double.tryParse(longitude.trim());
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        address.trim().isEmpty) {
      return null;
    }
    return GymLocation(
      name: name.trim().isEmpty ? 'IronFit' : name.trim(),
      address: address.trim(),
      latitude: lat,
      longitude: lng,
      details: details.trim(),
    );
  }

  static GymLocation? get configured => parse(
    latitude: const String.fromEnvironment(
      'GYM_LATITUDE',
      defaultValue: '36.8989875',
    ),
    longitude: const String.fromEnvironment(
      'GYM_LONGITUDE',
      defaultValue: '10.182546875',
    ),
    address: const String.fromEnvironment(
      'GYM_ADDRESS',
      defaultValue: 'V5XM+H2V, Cebalat Ben Ammar, Tunisie',
    ),
    name: const String.fromEnvironment('GYM_NAME', defaultValue: 'IronFit'),
    details: const String.fromEnvironment('GYM_DETAILS'),
  );

  Uri get directions => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
  });
}
