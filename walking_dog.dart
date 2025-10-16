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

  List<Map<String, dynamic>> _walkPath = [];
  bool _isTracking = false;
  Timer? _trackingTimer;
  Timer? _playTimer;
  int _playIndex = 0;

  Future<void> _savePathToJson() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/walk_path_$dateStr.json');
      await file.writeAsString(jsonEncode(_walkPath));
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
        _walkPath = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('날짜별 경로 불러오기 실패: $e');
    }
  }

  Future<void> _pickDateAndLoadPath() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
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

    final initialLoc = await location.getLocation();
    final initialPoint = {
      'latitude': initialLoc.latitude!,
      'longitude': initialLoc.longitude!,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _walkPath.add(initialPoint);
    });
    mapController.move(
      LatLng(
        (initialPoint['latitude'] as num).toDouble(),
        (initialPoint['longitude'] as num).toDouble(),
      ),
      17.0,
    );

    _trackingTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      final loc = await location.getLocation();
      final point = {
        'latitude': loc.latitude!,
        'longitude': loc.longitude!,
        'timestamp': DateTime.now().toIso8601String(),
      };
      setState(() {
        _walkPath.add(point);
      });
      mapController.move(
        LatLng(
          (point['latitude'] as num).toDouble(),
          (point['longitude'] as num).toDouble(),
        ),
        17.0,
      );
    });
  }

  void _stopTracking() async {
    _trackingTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
    await _savePathToJson();
  }

  List<double> calculateSpeeds() {
    final speeds = <double>[];
    final distance = Distance();

    for (int i = 1; i < _walkPath.length; i++) {
      final prev = _walkPath[i - 1];
      final curr = _walkPath[i];

      final p1 = LatLng(
        (prev['latitude'] as num).toDouble(),
        (prev['longitude'] as num).toDouble(),
      );
      final p2 = LatLng(
        (curr['latitude'] as num).toDouble(),
        (curr['longitude'] as num).toDouble(),
      );

      final time1 = DateTime.parse(prev['timestamp']);
      final time2 = DateTime.parse(curr['timestamp']);

      final dtSeconds = time2.difference(time1).inSeconds;
      final meters = distance(p1, p2);

      if (dtSeconds > 0) {
        final speed = meters / dtSeconds;
        speeds.add(speed);
      }
    }

    return speeds;
  }

  void playPathAnimation() {
    if (_walkPath.isEmpty) return;

    _playIndex = 0;
    _playTimer?.cancel();

    _playTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_playIndex >= _walkPath.length) {
        timer.cancel();
        return;
      }

      final point = _walkPath[_playIndex];
      final latlng = LatLng(
        (point['latitude'] as num).toDouble(),
        (point['longitude'] as num).toDouble(),
      );

      mapController.move(latlng, 17.0);
      setState(() {});
      _playIndex++;
    });
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _walkPath.isNotEmpty
            ? LatLng(
          (_walkPath.last['latitude'] as num).toDouble(),
          (_walkPath.last['longitude'] as num).toDouble(),
        )
            : LatLng(37.5665, 126.9780),
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
              points: _walkPath
                  .map((p) => LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ))
                  .toList(),
              strokeWidth: 4.0,
              color: Colors.green,
            ),
          ],
        ),
        MarkerLayer(
          markers: _walkPath.isNotEmpty
              ? [
            Marker(
              point: LatLng(
                (_walkPath.last['latitude'] as num).toDouble(),
                (_walkPath.last['longitude'] as num).toDouble(),
              ),
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
    final speeds = calculateSpeeds();
    final avgSpeed = speeds.isNotEmpty
        ? (speeds.reduce((a, b) => a + b) / speeds.length).toStringAsFixed(2)
        : '0.00';

    return Scaffold(
      appBar: AppBar(title: Text('산책 경로 기록')),
      body: Stack(
        children: [
          _buildMap(),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text('평균 속도: $avgSpeed m/s'),
                SizedBox(height: 10),
                Row(
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
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: playPathAnimation,
                      child: Text('경로 재생'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
