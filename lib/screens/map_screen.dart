import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../providers/trip_provider.dart';
import '../widgets/add_landmark_dialog.dart';
import '../widgets/landmark_list_drawer.dart';
import 'trip_list_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

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

              // Polyline Route Connectors
              if (provider.showRouteLines && landmarks.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: landmarks.map((l) => l.location).toList(),
                      color: Colors.indigo.withAlpha(200),
                      strokeWidth: 3.5,
                    ),
                  ],
                ),

              // Custom Pin Markers with Always-Visible Permanent Labels
              MarkerLayer(
                markers: landmarks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final landmark = entry.value;

                  return Marker(
                    point: landmark.location,
                    width: 140,
                    height: 75,
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
                                    Text(
                                      landmark.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('📍 地址: ${landmark.address.isNotEmpty ? landmark.address : "暫無"}'),
                                const SizedBox(height: 4),
                                Text('💡 筆記: ${landmark.notes.isNotEmpty ? landmark.notes : "無備註"}'),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    provider.deleteLandmark(landmark.id);
                                  },
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text('刪除此地標', style: TextStyle(color: Colors.red)),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
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
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: landmark.category.color,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      landmark.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
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

          // Tile Style & Floating Zoom Controllers
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
    );
  }
}
