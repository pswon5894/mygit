import 'dart:convert';
import 'package:flutter/material.dart';

import 'detail_screen.dart';

const List<String?> cityList = [
  null,
  "강릉",
  "서울",
  "춘천",
  "인천",
  "안동",
  "전주",
  "경주",
  null,
  "부산",
  "여수",
  null,
  "제주",
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<String, dynamic> info = {};
  List<bool> cityCheckInList = List<bool>.generate(
    cityList.length,
      (_) => false,
  );

  @override
  void initState() {
    super.initState();
    DefaultAssetBundle.of(
      context,
    )
      .loadString(
      "assets/json/info.json",
    )
      .then((data) {
      info = jsonDecode(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "지역을 선택하세요",
        ),
      ),
      body: SingleChildScrollView(
        child:Column(
          children: [
            Container(
              margin: const EdgeInsets.only(
                top: 10.0,
                left: 10.0,
                right: 10.0,
              ),
              padding: const EdgeInsets.only(
                top: 30.0,
                left: 80.0,
                right: 80.0,
              ),
              // height: 700.0,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                image: DecorationImage(
                    fit: BoxFit.cover,
                    image: AssetImage(
                      "assets/images/map.png",
                    ),
                ),
              ),
              child: GridView.builder(
                // physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 15.0,
                    crossAxisSpacing: 50.0,
                ),
                itemBuilder: (context, index) => cityList[index] != null
                  ? InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(
                          city: cityList[index]!,
                          info: info[cityList[index]!] as List<dynamic>,
                          isCheckedIn: cityCheckInList[index],
                          onCheckInChanged: (bool value) {
                            setState(() {
                              cityCheckInList[index] = value;
                            });
                          },
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(
                    30.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [
                        const Color(
                          0x77F44336,
                        ),
                        const Color(
                          0x77FFEB3B,
                        ),
                        const Color(
                          0x772196F3,
                        ),
                        const Color(
                          0x774CAF50,
                        ),
                        const Color(
                          0x779C27B0,
                        ),
                      ][index % 5],
                    ),
                    child: Center(
                      child: cityCheckInList[index]
                        ? const Icon(
                          Icons.check,
                      )
                      : Text(
                        cityList[index]!,
                        style: const TextStyle(
                          fontSize: 20.0,
                        ),
                      ),

                    ),
                  ),
                )
                    : Container(),
                itemCount: cityList.length,
              )
            ),
          ],
        ),
      ),
    );
  }
}
