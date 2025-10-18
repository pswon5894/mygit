import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ListItem extends StatefulWidget {
  const ListItem({
    super.key,
    required this.data,
  });
  final dynamic data;

  @override
  State<ListItem> createState() => _ListItemState();
}

class _ListItemState extends State<ListItem> {
  bool isCheckedIn = false;

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = <Marker>{
      Marker(
        markerId: MarkerId(
          widget.data["name"] ?? "",
        ),
        position: LatLng(
          widget.data["lat"] ?? 37.495361,
          widget.data["logt"] ?? 127.033079,
        ),
        infoWindow: InfoWindow(
          title: widget.data["name"] ?? "",
          snippet: widget.data["address"] ?? "",
        ),
      ),
    };

    return Padding(
      padding: const EdgeInsets.all(
        10.0,
    ),
    child: Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.data["name"] ?? "",
              style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
            ),
         ),
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: widget.data["cost"] ?? "",
            child: const Icon(
              Icons.attach_money,
            ),
          ),
        ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 10.0,
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width - 140.0,
              child: Text(
                  "${widget.data["description"] ?? ""}\n"
                      "위치: ${widget.data["address"] ?? ""}"),
            ),
            SizedBox(
              width: 100.0,
              height: 100.0,
              child: Image.asset(
                "asset/images/${widget.data["image"] ?? "placeholder.png"}",
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            vertical:10.0,
          ),
        ),
        SizedBox(
          height: 200.0,
          child: GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.data["lat"] ?? 37.495361,
                  widget.data["logt"] ?? 127.033079,
                ),
              zoom: 15.0,
            ),
            markers: markers,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: true,
            buildingsEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              // 마커가 항상 열려 있도록 설정
              // ignore: avoid_function_literals_in_foreach_calls
              markers.forEach((marker) {
                controller.showMarkerInfoWindow(
                  marker.markerId,
                );
              });
            },
          ),
        ),
      ],
    ),
    );
  }
}
