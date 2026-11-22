import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gym_route_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/gym_location.dart';
import '../core/theme/app_theme.dart';

class GymLocationPage extends StatefulWidget {
  const GymLocationPage({super.key});
  @override
  State<GymLocationPage> createState() => _GymLocationPageState();
}

class _GymLocationPageState extends State<GymLocationPage> {
  final _controller = MapController();
  final _location = GymLocation.configured;
  final _routes = GymRouteService();
  final _address = TextEditingController();
  StartingPlace? _start;
  GymRoute? _route;
  TravelMode _mode = TravelMode.driving;
  bool _locating = false, _searching = false, _routing = false;
  String? _error;
  List<StartingPlace> _results = [];
  int _request = 0;
  DateTime? _lastSearch;
  bool _tileError = false;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw Exception(
            'Activez la localisation de votre appareil ou saisissez une adresse.',
          );
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception(
            'Localisation refusée. Autorisez-la dans les réglages ou saisissez votre départ.',
          );
        }
      }
      // On web this call prompts only from this explicit button action, including Safari.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      _select(
        StartingPlace(
          'Ma position (précision ±${position.accuracy.round()} m)',
          LatLng(position.latitude, position.longitude),
        ),
      );
    } on PermissionDeniedException {
      if (mounted) {
        setState(
          () => _error =
              'Localisation refusée. Saisissez une adresse ou autorisez la localisation dans les réglages du navigateur.',
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error =
              'Localisation trop longue. Réessayez ou saisissez une adresse.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = kIsWeb
              ? 'Position indisponible. Vérifiez les permissions et utilisez HTTPS (ou localhost), ou saisissez votre départ.'
              : '$e'.replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final query = _address.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Saisissez une adresse et une ville.');
      return;
    }
    if (_lastSearch != null &&
        DateTime.now().difference(_lastSearch!) < const Duration(seconds: 1)) {
      return;
    }
    _lastSearch = DateTime.now();
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await _routes.search(query);
      if (mounted) {
        setState(() {
          _results = results;
          if (results.isEmpty) {
            _error = 'Aucune adresse trouvée. Précisez la ville et le pays.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Recherche indisponible. Réessayez ou utilisez votre position.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(StartingPlace place) {
    setState(() {
      _start = place;
      _results = [];
    });
    _calculate();
  }

  Future<void> _calculate() async {
    final gym = _location;
    final start = _start;
    if (gym == null || start == null) return;
    final request = ++_request;
    setState(() {
      _routing = true;
      _route = null;
      _error = null;
    });
    try {
      final route = await _routes.route(
        start.point,
        LatLng(gym.latitude, gym.longitude),
        _mode,
      );
      if (!mounted || request != _request) return;
      setState(() => _route = route);
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            start.point,
            LatLng(gym.latitude, gym.longitude),
            ...route.points,
          ]),
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'Itinéraire indisponible. Réessayez ou ouvrez Google Maps.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _routing = false);
    }
  }

  Uri _navigation(GymLocation gym) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${gym.latitude},${gym.longitude}',
        'travelmode': _mode == TravelMode.walking ? 'walking' : 'driving',
        'dir_action': 'navigate',
        if (_start != null)
          'origin': '${_start!.point.latitude},${_start!.point.longitude}',
      });

  Widget _journey() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 32),
      Text('Préparer ma visite', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const Text(
        'Votre position sert uniquement à ce trajet. Les coordonnées sont envoyées au service de calcul d’itinéraire OpenStreetMap.',
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _locating ? null : _locate,
        icon: const Icon(Icons.my_location),
        label: Text(_locating ? 'Localisation…' : 'Utiliser ma position'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _address,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          if (!_searching) _search();
        },
        decoration: const InputDecoration(
          labelText: 'Adresse de départ',
          hintText: 'Rue, ville, pays',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      TextButton(
        onPressed: _searching ? null : _search,
        child: Text(_searching ? 'Recherche…' : 'Rechercher une adresse'),
      ),
      for (final place in _results)
        ListTile(
          title: Text(place.name),
          leading: const Icon(Icons.place_outlined),
          onTap: () => _select(place),
        ),
      if (_start != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Départ : ${_start!.name}'),
        ),
      SegmentedButton<TravelMode>(
        segments: const [
          ButtonSegment(
            value: TravelMode.driving,
            icon: Icon(Icons.directions_car),
            label: Text('Voiture'),
          ),
          ButtonSegment(
            value: TravelMode.walking,
            icon: Icon(Icons.directions_walk),
            label: Text('À pied'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (selection) {
          setState(() => _mode = selection.first);
          _calculate();
        },
      ),
      if (_routing)
        const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      if (_route != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_route!.distance} · ${_route!.duration}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Estimation sans trafic en temps réel · Itinéraire OpenStreetMap',
              ),
            ],
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_start != null && !_routing)
        TextButton.icon(
          onPressed: _calculate,
          icon: const Icon(Icons.refresh),
          label: const Text('Recalculer l’itinéraire'),
        ),
      const SizedBox(height: 16),
    ],
  );
  int _revision = 0;

  @override
  void dispose() {
    _request++;
    _routes.dispose();
    _address.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message(
          'Impossible d’ouvrir la navigation. Réessayez ou copiez l’adresse.',
        );
      }
    } catch (_) {
      _message('Impossible d’ouvrir ce lien. Réessayez ou copiez l’adresse.');
    }
  }

  void _zoom(double delta) => _controller.move(
    _controller.camera.center,
    (_controller.camera.zoom + delta).clamp(2.0, 19.0).toDouble(),
  );

  Widget _map(GymLocation gym) {
    final point = LatLng(gym.latitude, gym.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            key: ValueKey(_revision),
            mapController: _controller,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
              minZoom: 2,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ironfit.app',
                maxNativeZoom: 19,
                errorTileCallback: (_, _, _) {
                  if (!_tileError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _tileError = true);
                    });
                  }
                },
              ),
              if (_route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!.points,
                      color: AppColors.info,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_start != null)
                    Marker(
                      point: _start!.point,
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: _start!.name,
                        child: const Icon(
                          Icons.my_location,
                          color: AppColors.info,
                          size: 32,
                        ),
                      ),
                    ),
                  Marker(
                    point: point,
                    width: 56,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: '${gym.name}\n${gym.address}',
                      child: Semantics(
                        label: 'Emplacement de ${gym.name}',
                        child: const Icon(
                          Icons.location_on,
                          size: 56,
                          color: AppColors.amberDeep,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom avant',
                    onPressed: () => _zoom(1),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Zoom arrière',
                    onPressed: () => _zoom(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: 'Recentrer sur la salle',
                    onPressed: () => _controller.move(point, 16),
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: TextButton(
                onPressed: () =>
                    _open(Uri.parse('https://www.openstreetmap.org/copyright')),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(GymLocation gym) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fitness_center,
            color: AppColors.amberDeep,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(gym.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SelectableText(
            gym.address,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (gym.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(gym.details),
          ],
          const SizedBox(height: 20),
          _journey(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _open(_navigation(gym)),
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${gym.name}\n${gym.address}\n${gym.latitude}, ${gym.longitude}',
                      ),
                    );
                    _message('Adresse copiée');
                  } catch (_) {
                    _message('Impossible de copier l’adresse.');
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copier l’adresse'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'L’itinéraire s’ouvre dans Google Maps, dans votre navigateur ou votre application de navigation.',
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gym = _location;
    return Scaffold(
      appBar: AppBar(title: const Text('Notre salle')),
      body: gym == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'L’adresse de la salle sera bientôt disponible.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Contactez l’accueil pour préparer votre visite.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final map = SizedBox(
                  height: wide ? 520 : 360,
                  child: _map(gym),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_tileError)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  children: [
                                    const Text(
                                      'La carte n’a pas pu se charger. Vérifiez votre connexion.',
                                    ),
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _tileError = false;
                                        _revision++;
                                      }),
                                      child: const Text('Réessayer'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: map),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _details(gym)),
                              ],
                            )
                          else ...[
                            map,
                            const SizedBox(height: 16),
                            _details(gym),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
