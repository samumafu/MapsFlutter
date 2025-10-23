import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_flutter/app/map/location_service.dart';
import 'package:maps_flutter/app/map/marker_model.dart';
import 'package:maps_flutter/app/map/marker_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MarkerService _markerService = MarkerService();
  final MapController _mapController = MapController();
  List<MarkerModel> _markers = [];
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final position = await LocationService.getCurrentLocation();
      final markers = await _markerService.fetchMarkers();

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers = markers;
      });
    } catch (e) {
      debugPrint('Error cargando mapa: $e');
    }
  }

  Future<void> _addMarker(LatLng point) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo marcador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descripción')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final marker = MarkerModel(
                  id: '',
                  name: nameController.text,
                  description: descriptionController.text,
                  latitude: point.latitude,
                  longitude: point.longitude,
                );
                await _markerService.addMarker(marker);
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
    final Distance distance = const Distance();
    return distance.as(LengthUnit.Kilometer, start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de marcadores')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation!,
          initialZoom: 14.0,
          onTap: (tapPosition, point) => _addMarker(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: _currentLocation!,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 35),
              ),
              ..._markers.map(
                (m) => Marker(
                  width: 80.0,
                  height: 80.0,
                  point: LatLng(m.latitude, m.longitude),
                  child: GestureDetector(
                    onTap: () {
                      final dist = _calculateDistance(
                        _currentLocation!,
                        LatLng(m.latitude, m.longitude),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${m.name}: ${dist.toStringAsFixed(2)} km de distancia')),
                      );
                    },
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
