import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DogWalking extends StatefulWidget {
  @override
  State<DogWalking> createState() => _DogWalkingState();
}

class _DogWalkingState extends State<DogWalking> {
  final mapController = MapController();
  final Location location = Location();
  List<LatLng> trackedPoints = [];
  StreamSubscription<LocationData>? locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
    _initLocationTracking();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    locationSubscription = location.onLocationChanged.listen((loc) {
      final point = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        trackedPoints.add(point);
      });
      mapController.move(point, 17.0);
    });
  }

  Future<void> _loadSavedPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/path.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final points = data.map<LatLng>((p) => LatLng(p['lat'], p['lng'])).toList();
        setState(() {
          trackedPoints = points;
        });
      }
    } catch (e) {
      print('경로 불러오기 실패: $e');
    }
  }

  Future<void> _savePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/path.json');
      final data = trackedPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('경로 저장 실패: $e');
    }
  }

  Future<void> _sharePath() async {
    final text = trackedPoints.map((p) => '${p.latitude},${p.longitude}').join('\n');
    await Share.share('내 산책 경로:\n$text');
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastPoint = trackedPoints.isNotEmpty ? trackedPoints.last : LatLng(37.5665, 126.9780);

    return Scaffold(
      appBar: AppBar(title: Text('개 산책 경로')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: lastPoint,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: trackedPoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: trackedPoints.map((point) => Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.circle, color: Colors.red, size: 10),
                )).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _savePath,
                  child: Text('경로 저장'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sharePath,
                  child: Text('경로 공유'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loadSavedPath,
                  child: Text('경로 불러오기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}