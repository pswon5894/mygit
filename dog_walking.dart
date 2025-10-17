import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  bool isTracking = false;
  double totalDistanceKm = 0.0;
  LatLng? currentLocation; // 현재 위치를 저장하여 마커 표시용으로 사용

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
    _initLocationService();
  }

  Future<void> _initLocationService() async {
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

    // 초기 현재 위치 설정 (지도 중앙에 사용)
    final loc = await location.getLocation();
    setState(() {
      currentLocation = LatLng(loc.latitude!, loc.longitude!);
    });
  }

  // Haversine 공식을 사용하여 두 지점 간의 거리(km)를 계산
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double R = 6371; // 지구의 반경 (km)
    double lat1Rad = p1.latitude * pi / 180;
    double lat2Rad = p2.latitude * pi / 180;
    double dLat = (p2.latitude - p1.latitude) * pi / 180;
    double dLon = (p2.longitude - p1.longitude) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // 총 거리 계산
  void _calculateTotalDistance() {
    double distance = 0.0;
    for (int i = 0; i < trackedPoints.length - 1; i++) {
      distance += _calculateDistance(trackedPoints[i], trackedPoints[i + 1]);
    }
    setState(() {
      totalDistanceKm = distance;
    });
    print('총 산책 거리: ${totalDistanceKm.toStringAsFixed(2)} km');
  }

  // 추적 시작 (개선: Timer 대신 Stream 사용)
  void _startTracking() {
    if (isTracking) return;
    setState(() {
      isTracking = true;
      trackedPoints.clear(); // 새 추적 시작 시 이전 경로 초기화
      totalDistanceKm = 0.0;
    });

    locationSubscription = location.onLocationChanged.listen((loc) {
      final point = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        currentLocation = point; // 현재 위치 마커 업데이트
        trackedPoints.add(point);
      });
      // *지도 자동 이동 로직 제거: _goToCurrentLocation() 호출을 사용자 버튼으로 대체*
    });
    // 5초 간격 대신, 위치 변화가 있을 때마다 또는 OS가 최적이라고 판단할 때마다 업데이트
    location.changeSettings(interval: 5000, distanceFilter: 10); // 5초 간격, 10미터 이상 이동 시
  }

  // 추적 정지
  void _stopTracking() {
    if (!isTracking) return;
    locationSubscription?.cancel();
    setState(() {
      isTracking = false;
    });
    _calculateTotalDistance(); // 정지 시 총 거리 계산
    // 사용자에게 거리 정보를 팝업 등으로 보여줄 수 있음
    _showDistanceDialog();
  }

  void _showDistanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('산책 완료! 🐾'),
        content: Text('총 산책 거리: ${totalDistanceKm.toStringAsFixed(2)} km'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  // 현재 위치로 지도 이동 (사용자 요청 시에만)
  void _goToCurrentLocation() {
    if (currentLocation != null) {
      mapController.move(currentLocation!, 17.0);
    }
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
          trackedPoints = points.cast<LatLng>();
          _calculateTotalDistance(); // 불러온 경로의 거리 계산
        });
        if (trackedPoints.isNotEmpty) {
          mapController.move(trackedPoints.last, 15.0);
        }
      } else {
        // 저장된 경로가 없으면 현재 위치로 이동
        if (currentLocation != null) {
          mapController.move(currentLocation!, 15.0);
        }
      }
    } catch (e) {
      print('경로 불러오기 실패: $e');
      // UI에 오류 메시지를 표시하는 것이 좋음
    }
  }

  Future<void> _savePath() async {
    if (trackedPoints.isEmpty) {
      // 경로가 없을 경우 저장하지 않음
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장할 경로가 없습니다.')),
      );
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/path.json');
      // 거리 정보도 저장할 수 있도록 확장 (선택 사항)
      final data = {
        'distance': totalDistanceKm,
        'points': trackedPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      };
      await file.writeAsString(jsonEncode(data));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로가 저장되었습니다.')),
      );
    } catch (e) {
      print('경로 저장 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로 저장 실패!')),
      );
    }
  }

  Future<void> _sharePath() async {
    if (trackedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유할 경로가 없습니다.')),
      );
      return;
    }
    // 더 유용한 정보 추가
    final pathText = trackedPoints.map((p) => '${p.latitude},${p.longitude}').join(';');
    final text = '내 산책 기록: ${totalDistanceKm.toStringAsFixed(2)} km\n\n좌표:\n$pathText';
    await Share.share(text, subject: '강아지 산책 경로 공유');
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = currentLocation ?? LatLng(37.5665, 126.9780); // 서울 시청

    return Scaffold(
      appBar: AppBar(
        title: Text('개 산책 경로 (거리: ${totalDistanceKm.toStringAsFixed(2)} km)'),
        backgroundColor: isTracking ? Colors.red.shade700 : Colors.blue.shade700,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // 추적 중일 때만 경로 표시
              if (trackedPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trackedPoints,
                      strokeWidth: 4.0,
                      color: isTracking ? Colors.red : Colors.blue, // 추적 상태에 따라 색상 변경
                    ),
                  ],
                ),
              // 현재 위치 마커만 표시
              if (currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.pets, // 강아지 발자국 아이콘
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 우측 상단 현재 위치 이동 버튼
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              mini: true,
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // 하단 메인 컨트롤 버튼 그룹
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 추적 시작/정지 버튼
                    ElevatedButton.icon(
                      onPressed: isTracking ? _stopTracking : _startTracking,
                      icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
                      label: Text(isTracking ? '산책 정지' : '산책 시작'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTracking ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(120, 40),
                      ),
                    ),

                    // 저장 버튼
                    IconButton(
                      onPressed: _savePath,
                      icon: Icon(Icons.save),
                      tooltip: '경로 저장',
                    ),

                    // 공유 버튼
                    IconButton(
                      onPressed: _sharePath,
                      icon: Icon(Icons.share),
                      tooltip: '경로 공유',
                    ),

                    // 불러오기 버튼
                    IconButton(
                      onPressed: _loadSavedPath,
                      icon: Icon(Icons.folder_open),
                      tooltip: '경로 불러오기',
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