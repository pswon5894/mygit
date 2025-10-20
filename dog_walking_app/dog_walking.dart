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
import 'package:intl/intl.dart'; // 날짜/시간 포맷을 위해 추가

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
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }


  Future<void> _initLocationService() async {
    // 1. 서비스 활성화 체크
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        // 위치 서비스 활성화 거부 시, 사용자에게 알림만 주고 종료 방지
        print("위치 서비스가 활성화되지 않았습니다.");
        return;
      }
    }

    // 2. 권한 요청 및 체크
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        // 위치 권한 거부 시, 사용자에게 알림만 주고 종료 방지
        print("위치 권한이 거부되었습니다.");
        return;
      }
    }

    // 3. 위치 가져오기 및 null 처리 강화
    try {
      final loc = await location.getLocation();

      // loc 자체가 null이거나, latitude/longitude가 null일 경우 처리
      if (loc.latitude == null || loc.longitude == null) {
        print("위치 정보를 가져오는 데 실패했습니다 (좌표 null).");
        return; // 앱 종료 대신 함수 종료
      }

      setState(() {
        currentLocation = LatLng(loc.latitude!, loc.longitude!);
      });

      // 4. 맵 초기화 시 현재 위치로 이동
      if (currentLocation != null) {
        mapController.move(currentLocation!, 15.0);
      }
    } catch (e) {
      // 예외 발생 시(타임아웃, I/O 오류 등), 앱 종료 대신 메시지 출력
      print('초기 위치를 가져오는 중 오류 발생: $e');
    }
  }

  // Haversine 공식을 사용하여 두 지점 간의 거리(km)를 계산
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double R = 6371;
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

  void _calculateTotalDistance() {
    double distance = 0.0;
    for (int i = 0; i < trackedPoints.length - 1; i++) {
      distance += _calculateDistance(trackedPoints[i], trackedPoints[i + 1]);
    }
    setState(() {
      totalDistanceKm = distance;
    });
  }

  void _startTracking() {
    if (isTracking) return;
    setState(() {
      isTracking = true;
      trackedPoints.clear();
      totalDistanceKm = 0.0;
      // 시작 지점 추가
      if (currentLocation != null) {
        trackedPoints.add(currentLocation!);
      }
    });

    _goToCurrentLocation();

    location.changeSettings(interval: 5000, distanceFilter: 10);
    locationSubscription = location.onLocationChanged.listen((loc) {
      final point = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        currentLocation = point;
        // 위치 변화에 따른 거리 누적
        if (trackedPoints.isNotEmpty) {
          totalDistanceKm += _calculateDistance(trackedPoints.last, point);
        }
        trackedPoints.add(point);
      });
    });
  }

  void _stopTracking() {
    if (!isTracking) return;
    locationSubscription?.cancel();
    setState(() {
      isTracking = false;
    });
    // 추적 완료 후 총 거리 재계산 (정확한 값 보장)
    _calculateTotalDistance();
    _showDistanceDialog();
  }

  void _showDistanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('산책 완료!'),
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

  void _goToCurrentLocation() {
    if (currentLocation != null) {
      mapController.move(currentLocation!, 17.0);
    }
  }

  // ------------------------- 경로 저장/불러오기 개선 로직 -------------------------

  // 1. 경로를 고유한 파일명으로 저장
  Future<void> _savePath() async {
    if (trackedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장할 경로가 없습니다.')),
      );
      return;
    }
    try {
      final now = DateTime.now();
      final formatter = DateFormat('yyyyMMdd_HHmmss');
      final filename = 'walk_${formatter.format(now)}.json';

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');

      final data = {
        'distance': totalDistanceKm,
        'points': trackedPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      };

      await file.writeAsString(jsonEncode(data));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로가 "$filename"으로 저장되었습니다.')),
      );
    } catch (e) {
      print('경로 저장 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로 저장 실패!')),
      );
    }
  }

  // 2. 저장된 모든 경로 파일 목록 가져오기
  Future<List<String>> _getSavedPathFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await dir.list().toList();
      // 'walk_'로 시작하고 '.json'으로 끝나는 파일만 필터링
      return files
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.startsWith('walk_') && name.endsWith('.json'))
          .toList();
    } catch (e) {
      print('경로 파일 목록 불러오기 실패: $e');
      return [];
    }
  }

  // 3. 경로 선택 다이얼로그 표시
  Future<void> _showLoadPathDialog() async {
    final fileNames = await _getSavedPathFiles();

    if (fileNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장된 경로 파일이 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('저장된 경로 불러오기'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fileNames.length,
              itemBuilder: (context, index) {
                final fileName = fileNames[index];
                String displayDate = fileName.substring(5, 20);

                try {
                  final dateTime = DateFormat('yyyyMMdd_HHmmss').parse(displayDate);
                  displayDate = DateFormat('yyyy년 MM월 dd일 HH:mm').format(dateTime);
                } catch (_) {
                  displayDate = fileName;
                }

                return ListTile(
                  title: Text(displayDate),
                  onTap: () {
                    Navigator.of(context).pop();
                    _loadPathFromFile(fileName);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
          ],
        );
      },
    );
  }

  // 4. 선택된 파일에서 경로 로드
  Future<void> _loadPathFromFile(String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');

      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        final List<LatLng> points = (data['points'] as List)
            .map((p) => LatLng(p['lat'], p['lng']))
            .toList();

        setState(() {
          trackedPoints = points;
          totalDistanceKm = (data['distance'] is num)
              ? (data['distance'] as num).toDouble()
              : 0.0;
          _calculateTotalDistance();

          if (trackedPoints.isNotEmpty) {
            currentLocation = trackedPoints.last;
            mapController.move(currentLocation!, 15.0);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$filename" 경로가 성공적으로 불러와졌습니다.')),
        );
      }
    } catch (e) {
      print('경로 로드 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로 로드 실패!')),
      );
    }
  }

  // ------------------------- 기존 로직 유지 -------------------------

  Future<void> _sharePath() async {
    if (trackedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유할 경로가 없습니다.')),
      );
      return;
    }
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
    final initialCenter = currentLocation ?? LatLng(37.5665, 126.9780);

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
              if (trackedPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trackedPoints,
                      strokeWidth: 4.0,
                      color: isTracking ? Colors.red : Colors.blue,
                    ),
                  ],
                ),
              if (currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.pets,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              if (trackedPoints.length > 1 && !isTracking)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: trackedPoints.first,
                      child: Icon(Icons.location_on, color: Colors.green, size: 30),
                    ),
                    Marker(
                      point: trackedPoints.last,
                      child: Icon(Icons.flag, color: Colors.purple, size: 30),
                    ),
                  ],
                ),
            ],
          ),

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

                    IconButton(
                      onPressed: _savePath,
                      icon: Icon(Icons.save),
                      tooltip: '경로 저장',
                    ),

                    IconButton(
                      onPressed: _sharePath,
                      icon: Icon(Icons.share),
                      tooltip: '경로 공유',
                    ),

                    IconButton(
                      onPressed: _showLoadPathDialog,
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