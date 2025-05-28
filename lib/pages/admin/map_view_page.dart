import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapViewPage extends StatelessWidget {
  final double latitude;
  final double longitude;

  const MapViewPage({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    final LatLng location = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('عرض الموقع'),
        backgroundColor: Colors.blue,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: location,
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('checkin_location'),
            position: location,
            infoWindow: const InfoWindow(title: 'موقع الحضور'),
          ),
        },
      ),
    );
  }
}
