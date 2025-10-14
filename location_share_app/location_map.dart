import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LocationMap extends StatefulWidget {
  @override
  State<LocationMap> createState() => _LocalMapState();
}

class _LocalMapState extends State<LocationMap> {
  final mapController = MapController();
  final Location location = Location();
  LatLng _currentCenter = LatLng(37.5665, 126.9780); // 기본: 서울
  Marker? _currentMarker;

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  String? _currentCoordinatesText;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/last_location.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final savedLatLng = LatLng(data['latitude'], data['longitude']);
        setState(() {
          _currentCenter = savedLatLng;
          _currentMarker = Marker(
            point: savedLatLng,
            width: 80,
            height: 80,
            alignment: Alignment.center,
            child: Icon(Icons.my_location, color: Colors.red, size: 40),
          );
        });
        mapController.move(savedLatLng, 17.0);
      }
    } catch (e) {
      print('위치 불러오기 실패: $e');
    }
  }

  Future<void> _saveLocationToJson(double lat, double lng) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/last_location.json');
      final data = {'latitude': lat, 'longitude': lng};
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('위치 저장 실패: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
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

    final loc = await location.getLocation();
    final newCenter = LatLng(loc.latitude!, loc.longitude!);

    setState(() {
      _currentCenter = newCenter;
      _currentMarker = Marker(
        point: newCenter,
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Icon(Icons.my_location, color: Colors.red, size: 40),
      );
      setState(() {
        _currentCoordinatesText =
        '위도: ${newCenter.latitude.toStringAsFixed(6)}\n경도: ${newCenter.longitude.toStringAsFixed(6)}';
      });
    });

    mapController.move(newCenter, 17.0);
    await _saveLocationToJson(loc.latitude!, loc.longitude!); // 위치 저장
  }

  Future<void> _shareLocationOnly() async {
    if (_currentCenter == null) return;

    final locationText =
        '내 위치 좌표 \nhttps://maps.google.com/?q=${_currentCenter.latitude},${_currentCenter.longitude}';

    await Share.share(locationText);
  }

  void _moveToEnteredCoordinates() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('올바른 좌표를 입력하세요')),
      );
      return;
    }

    final newPoint = LatLng(lat, lng);

    setState(() {
      _currentCenter = newPoint;
      _currentMarker = Marker(
        point: newPoint,
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Icon(Icons.place, color: Colors.green, size: 40),
      );
    });

    mapController.move(newPoint, 17.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('주차위치 공유')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(37.5665, 126.9780),
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                  if (_currentMarker != null) _currentMarker!,
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: Icon(Icons.my_location),
              tooltip: '현재 위치로 이동',
            ),
          ),
          Positioned(
            bottom: 160,
            right: 20,
            child: FloatingActionButton(
              onPressed: _shareLocationOnly,
              child: Icon(Icons.share),
              tooltip: '좌표만 공유',
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: '위도'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: '경도'),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _moveToEnteredCoordinates,
                    child: Text('이동'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentCoordinatesText ?? '현재 위치를 가져오세요',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
