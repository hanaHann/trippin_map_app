import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/landmark.dart';
import '../providers/trip_provider.dart';
import '../widgets/add_landmark_dialog.dart';
import '../widgets/landmark_list_drawer.dart';
import '../widgets/ad_banner_widget.dart';
import 'trip_list_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  double _currentRotation = 0.0;

  Future<void> _openGoogleMapsNavigation(Landmark landmark) async {
    final String name = landmark.name.trim();
    final String address = landmark.address.trim();
    final String queryText = name.isNotEmpty
        ? (address.isNotEmpty ? '$name $address' : name)
        : '${landmark.latitude},${landmark.longitude}';

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(queryText)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _resetCompassNorth() {
    _mapController.rotate(0.0);
    setState(() {
      _currentRotation = 0.0;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧭 已將地圖回正至正北方向'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  List<LatLng> _generateRouteDots(List<Landmark> landmarks) {
    final List<LatLng> dots = [];
    for (int i = 0; i < landmarks.length - 1; i++) {
      final start = landmarks[i].location;
      final end = landmarks[i + 1].location;
      for (double step = 0.25; step < 0.99; step += 0.25) {
        final lat = start.latitude + (end.latitude - start.latitude) * step;
        final lng = start.longitude + (end.longitude - start.longitude) * step;
        dots.add(LatLng(lat, lng));
      }
    }
    return dots;
  }

  void _zoomToFitAll(List<Landmark> landmarks) {
    if (landmarks.isEmpty) return;
    if (landmarks.length == 1) {
      _mapController.move(landmarks.first.location, 14.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(
      landmarks.map((l) => l.location).toList(),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  void _showAddDialog({double? lat, double? lng}) {
    showDialog(
      context: context,
      builder: (context) => AddLandmarkDialog(initialLat: lat, initialLng: lng),
    );
  }

  String _getTileUrl(MapTileStyle style) {
    switch (style) {
      case MapTileStyle.light:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case MapTileStyle.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case MapTileStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapTileStyle.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final activeTrip = provider.activeTrip;
    final landmarks = provider.currentLandmarks;

    final initialCenter = landmarks.isNotEmpty
        ? landmarks.first.location
        : const LatLng(35.6812, 139.7671); // Tokyo default

    return Scaffold(
      drawer: LandmarkListDrawer(
        onSelectLandmark: (landmark) {
          _mapController.move(landmark.location, 15.5);
        },
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeTrip?.title ?? '選擇行程',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '共 ${landmarks.length} 個自訂地標 (已屏蔽其他雜項)',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Transform.rotate(
              angle: -_currentRotation * (math.pi / 180),
              child: Icon(
                Icons.explore,
                color: _currentRotation.abs() > 0.5 ? Colors.redAccent : null,
              ),
            ),
            tooltip: '指北針回正',
            onPressed: _resetCompassNorth,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: '一鍵全覽視角',
            onPressed: () => _zoomToFitAll(landmarks),
          ),
          IconButton(
            icon: Icon(
              provider.showPermanentLabels
                  ? Icons.label
                  : Icons.label_outlined,
              color: provider.showPermanentLabels ? Colors.amber : null,
            ),
            tooltip: provider.showPermanentLabels
                ? '已開啟：常駐顯示名稱 (Google Maps 痛點解法)'
                : '隱藏常駐名稱',
            onPressed: () => provider.togglePermanentLabels(),
          ),
          IconButton(
            icon: const Icon(Icons.collections_bookmark_rounded),
            tooltip: '管理/切換行程',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TripListScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // FlutterMap Tile Engine
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 12.0,
              onPositionChanged: (camera, hasGesture) {
                if ((camera.rotation - _currentRotation).abs() > 0.1) {
                  setState(() {
                    _currentRotation = camera.rotation;
                  });
                }
              },
              onTap: (tapPosition, point) {
                _showAddDialog(lat: point.latitude, lng: point.longitude);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(provider.tileStyle),
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.hana.trip_pin_app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),

              // Polyline Route Connectors & Waypoint Dots
              if (provider.showRouteLines && landmarks.length > 1) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: landmarks.map((l) => l.location).toList(),
                      color: Colors.indigo.withAlpha(200),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                CircleLayer(
                  circles: [
                    // Intermediate route segment dots
                    ..._generateRouteDots(landmarks).map(
                      (point) => CircleMarker(
                        point: point,
                        radius: 3.5,
                        color: Colors.indigoAccent,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1.5,
                      ),
                    ),
                    // Landmark vertex dots
                    ...landmarks.map(
                      (l) => CircleMarker(
                        point: l.location,
                        radius: 6.5,
                        color: Colors.indigo,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2.5,
                      ),
                    ),
                  ],
                ),
              ],

              // Custom Pin Markers with Always-Visible Permanent Labels
              MarkerLayer(
                markers: landmarks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final landmark = entry.value;

                  return Marker(
                    point: landmark.location,
                    width: 220,
                    height: 100,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(landmark.category.iconSymbol,
                                        style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        landmark.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('📍 地址: ${landmark.address.isNotEmpty ? landmark.address : "暫無"}'),
                                const SizedBox(height: 4),
                                Text('💡 筆記: ${landmark.notes.isNotEmpty ? landmark.notes : "無備註"}'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          _openGoogleMapsNavigation(landmark);
                                        },
                                        icon: const Icon(Icons.navigation,
                                            color: Colors.white),
                                        label: const Text('開啟 Google 地圖景點'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        provider.deleteLandmark(landmark.id);
                                      },
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      tooltip: '刪除此地標',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Permanent Visible Label Badge (Solves Google Maps pain point)
                          if (provider.showPermanentLabels)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 210),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                  border: Border.all(
                                    color: landmark.category.color,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor: landmark.category.color,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        landmark.name,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          height: 1.25,
                                        ),
                                        softWrap: true,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          // Pin Icon
                          Icon(
                            Icons.location_on,
                            size: 28,
                            color: landmark.category.color,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Tile Style & Floating Controls (Zoom + Compass Reset)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: DropdownButton<MapTileStyle>(
                      value: provider.tileStyle,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.layers, size: 20),
                      items: const [
                        DropdownMenuItem(
                            value: MapTileStyle.light, child: Text('極簡亮色')),
                        DropdownMenuItem(
                            value: MapTileStyle.dark, child: Text('霓虹暗黑')),
                        DropdownMenuItem(
                            value: MapTileStyle.osm, child: Text('經典地圖')),
                        DropdownMenuItem(
                            value: MapTileStyle.satellite, child: Text('衛星地圖')),
                      ],
                      onChanged: (val) {
                        if (val != null) provider.setTileStyle(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_compass_reset',
                  tooltip: '指北針回正',
                  backgroundColor: _currentRotation.abs() > 0.5
                      ? Colors.redAccent
                      : Colors.white,
                  foregroundColor: _currentRotation.abs() > 0.5
                      ? Colors.white
                      : Colors.indigo,
                  onPressed: _resetCompassNorth,
                  child: Transform.rotate(
                    angle: -_currentRotation * (math.pi / 180),
                    child: const Icon(Icons.explore),
                  ),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_in',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom + 1.0;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1.0;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),

      // FAB to Add Landmark
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add_location),
        label: const Text('新增地標'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const SafeArea(
        child: SizedBox(
          height: 52,
          child: Center(
            child: AdBannerWidget(),
          ),
        ),
      ),
    );
  }
}
