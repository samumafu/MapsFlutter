import 'package:maps_flutter/app/config/supabase_client.dart';
import 'marker_model.dart';

class MarkerService {
  final _client = SupabaseConfig.client;

  Future<List<MarkerModel>> fetchMarkers() async {
    final response = await _client.from('markers').select();
    return (response as List)
        .map((e) => MarkerModel.fromJson(e))
        .toList();
  }

  Future<void> addMarker(MarkerModel marker) async {
    await _client.from('markers').insert(marker.toJson());
  }
}
