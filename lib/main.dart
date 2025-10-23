import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jjgetpvtnzlorpfoyxtr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqZ2V0cHZ0bnpsb3JwZm95eHRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExNjk2MjcsImV4cCI6MjA3Njc0NTYyN30.ace5Kpdo3Mrph-jxdcOnD1cVFJ3KZNoIddEGjWeVLXc',
  );

  runApp(const MapApp());
}

final supabase = Supabase.instance.client;

class MapApp extends StatelessWidget {
  const MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa Supabase - Pasto',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapHomePage(),
    );
  }
}

class MarkerData {
  final String id;
  final String name;
  final String? description;
  final LatLng position;

  MarkerData({
    required this.id,
    required this.name,
    this.description,
    required this.position,
  });
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  List<Marker> markers = [];
  List<MarkerData> markersData = [];
  final TextEditingController searchController = TextEditingController();

  LatLng pastoCenter = const LatLng(1.2136, -77.2811);
  LatLng? currentLocation;
  List<LatLng> routePoints = [];
  String? distanceText;
  String? durationText;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        currentLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      debugPrint('Error al obtener ubicación: $e');
    }
  }

  Future<void> _loadMarkers() async {
    try {
      final response = await supabase.from('locations').select();
      final data = response as List<dynamic>;

      setState(() {
        markersData = data.map((item) {
          return MarkerData(
            id: item['id'],
            name: item['name'],
            description: item['description'],
            position: LatLng(item['lat'], item['lng']),
          );
        }).toList();

        markers = markersData.map((markerData) {
          return Marker(
            width: 60,
            height: 60,
            point: markerData.position,
            child: GestureDetector(
              onTap: () => _showMarkerInfo(markerData),
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
          );
        }).toList();

        // Agregar marcador de ubicación actual
        if (currentLocation != null) {
          markers.add(
            Marker(
              width: 60,
              height: 60,
              point: currentLocation!,
              child: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 40,
              ),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error al cargar marcadores: $e');
    }
  }

  void _showMarkerInfo(MarkerData markerData) {
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esperando ubicación actual...')),
      );
      return;
    }

    final distance = const Distance().as(
      LengthUnit.Kilometer,
      currentLocation!,
      markerData.position,
    );

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                markerData.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (markerData.description != null)
                Text(markerData.description!),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.straighten, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Distancia: ${distance.toStringAsFixed(2)} km',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _getRoute(markerData.position);
                },
                icon: const Icon(Icons.directions),
                label: const Text('Trazar ruta'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getRoute(LatLng destination) async {
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ubicación')),
      );
      return;
    }

    try {
      // Usar OSRM (Open Source Routing Machine) para obtener la ruta
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${currentLocation!.longitude},${currentLocation!.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['code'] == 'Ok') {
        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List;

        final distance = route['distance'] / 1000; // metros a km
        final duration = route['duration'] / 60; // segundos a minutos

        setState(() {
          routePoints = geometry
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();
          distanceText = '${distance.toStringAsFixed(2)} km';
          durationText = '${duration.toStringAsFixed(0)} min';
        });

        // Centrar el mapa en la ruta
        _mapController.move(currentLocation!, 13);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ruta trazada: $distanceText - $durationText'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al trazar ruta: $e')),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      routePoints = [];
      distanceText = null;
      durationText = null;
    });
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa la ubicación en tu dispositivo.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado.')),
        );
        return;
      }
    }

    final pos = await Geolocator.getCurrentPosition();
    final current = LatLng(pos.latitude, pos.longitude);

    setState(() {
      currentLocation = current;
    });

    _mapController.move(current, 15);
    _loadMarkers(); // Recargar para actualizar el marcador azul
  }

  Future<void> _addMarker(LatLng point) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Agregar marcador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Descripción')),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Guardar'),
              onPressed: () async {
                try {
                  await supabase.from('locations').insert({
                    'name': nameController.text,
                    'description': descController.text,
                    'lat': point.latitude,
                    'lng': point.longitude,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marcador agregado con éxito')),
                    );
                    Navigator.pop(context);
                    _loadMarkers();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al guardar: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchPlace() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

    try {
      final res = await http.get(url);
      final List data = json.decode(res.body);

      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        _mapController.move(LatLng(lat, lon), 15);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar el lugar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Supabase - Pasto'),
        actions: [
          if (routePoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearRoute,
              tooltip: 'Limpiar ruta',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pastoCenter,
              initialZoom: 13.0,
              onTap: (tapPos, point) => _addMarker(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 8,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar lugar...',
                        contentPadding: EdgeInsets.all(10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchPlace,
                  ),
                ],
              ),
            ),
          ),
          if (distanceText != null && durationText != null)
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: Card(
                elevation: 8,
                color: Colors.blue,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            distanceText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            durationText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}