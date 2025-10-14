import 'package:flutter/material.dart';
import 'location_map.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "주차 위치 공유",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LocationMap(),
    );
  }
}