import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';

class WalkingDog extends StatefulWidget {
  @override
  State<WalkingDog> createState() => _WalkingDogState();
}

class _WalkingDogState extends State<WalkingDog> {
  final mapController = MapController();
  final Location location = Location();

  List<LatLng> _walkPath = [];
  bool _isTracking = false;
  Timer? _trackingTimer;

  Future<void> _savePathToJson() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/walk_path_$dateStr.json');

      final pathData = _walkPath.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList();

      await file.writeAsString(jsonEncode(pathData));
      print('경로 저장 완료: ${file.path}');
    } catch (e) {
      print('경로 저장 실패: $e');
    }
  }

  Future<void> _loadPathByDate(String date) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/walk_path_$date.json');
      if (!await file.exists()) {
        print('해당 날짜의 경로 파일이 없습니다.');
        return;
      }

      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);

      setState(() {
        _walkPath = data.map((item) => LatLng(item['latitude'], item['longitude'])).toList();
      });
    } catch (e) {
      print('날짜별 경로 불러오기 실패: $e');
    }
  }

  Future<void> _pickDateAndLoadPath() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final dateStr = picked.toIso8601String().split('T').first;
      await _loadPathByDate(dateStr);
    }
  }

  void _startTracking() async {
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

    _walkPath.clear();
    setState(() {
      _isTracking = true;
    });

    // 처음 위치 한 번 기록
    final initialLoc = await location.getLocation();
    final initialPoint = LatLng(initialLoc.latitude!, initialLoc.longitude!);
    setState(() {
      _walkPath.add(initialPoint);
    });
    mapController.move(initialPoint, 17.0);

    // 이후 1분마다 위치 기록
    _trackingTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      final loc = await location.getLocation();
      final point = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        _walkPath.add(point);
      });
      mapController.move(point, 17.0);
    });
  }

  void _stopTracking() async {
    _trackingTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
    await _savePathToJson();
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _walkPath.isNotEmpty ? _walkPath.last : LatLng(37.5665, 126.9780),
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _walkPath,
              strokeWidth: 4.0,
              color: Colors.green,
            ),
          ],
        ),
        MarkerLayer(
          markers: _walkPath.isNotEmpty
              ? [
            Marker(
              point: _walkPath.last,
              width: 60,
              height: 60,
              child: Icon(Icons.directions_walk, color: Colors.red),
            ),
          ]
              : [],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('산책 경로 기록')),
      body: Stack(
        children: [
          _buildMap(),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isTracking ? null : _startTracking,
                  child: Text('산책 시작'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : null,
                  child: Text('산책 종료'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pickDateAndLoadPath,
                  child: Text('날짜별 경로 불러오기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}