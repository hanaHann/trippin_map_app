import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gal/gal.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/landmark.dart';
import '../models/trip.dart';
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
  late PageController _carouselPageController;
  double _currentRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _carouselPageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _carouselPageController.dispose();
    super.dispose();
  }

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

  final GlobalKey _repaintKey = GlobalKey();

  Future<void> _exportAndShareMapImage(
      BuildContext context, Trip? activeTrip) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('✨ 正在生成可愛地圖高清圖片...'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final RenderRepaintBoundary? boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (!context.mounted) return;
      Navigator.pop(context);

      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final String tripTitleClean = activeTrip?.title
              .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5]'), '_') ??
          'cute_map';
      final filePath =
          '${tempDir.path}/${tripTitleClean}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!context.mounted) return;

      _showExportPreviewDialog(context, file, activeTrip);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('導出圖片時發生錯誤: $e')),
        );
      }
    }
  }

  void _showExportPreviewDialog(
      BuildContext context, File imageFile, Trip? activeTrip) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '✨ 可愛地圖導出與分享',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.indigo.withAlpha(50), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(imageFile, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.collections_bookmark_rounded,
                          size: 14, color: Colors.indigo),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${activeTrip?.title ?? "我的可愛地圖"} · ${activeTrip?.landmarks.length ?? 0} 個地點',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final hasAccess = await Gal.hasAccess(toAlbum: true);
                            if (!hasAccess) {
                              await Gal.requestAccess(toAlbum: true);
                            }
                            await Gal.putImage(imageFile.path);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 可愛地圖圖片已成功儲存至手機相簿！'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ 儲存至相簿失敗：$e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('儲存至相簿'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // ignore: deprecated_member_use
                          await Share.shareXFiles(
                            [XFile(imageFile.path)],
                            text:
                                '✨ 這是我的可愛旅遊地圖「${activeTrip?.title ?? "分享地圖"}」！歡迎一起探索~ 🗺️',
                          );
                        },
                        icon: const Icon(Icons.share_rounded,
                            color: Colors.white),
                        label: const Text('一鍵分享圖片',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
      _mapController.move(landmarks.first.location, 14.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(
      landmarks.map((l) => l.location).toList(),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 120.0,
          bottom: 120.0,
          left: 100.0,
          right: 100.0,
        ),
        maxZoom: 16.0,
      ),
    );
  }

  void _showAddDialog({double? lat, double? lng}) async {
    final newLandmark = await showDialog<Landmark>(
      context: context,
      builder: (context) => AddLandmarkDialog(initialLat: lat, initialLng: lng),
    );
    if (newLandmark != null) {
      _mapController.move(newLandmark.location, 15.5);
    }
  }

  String _getTileUrl(MapTileStyle style) {
    switch (style) {
      case MapTileStyle.macaronCream:
        return 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png';
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

  void _showTileStyleBottomSheet(
      BuildContext context, TripProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final styles = [
          {
            'style': MapTileStyle.macaronCream,
            'label': '低調灰白',
            'desc': '極簡灰白無字質感色調'
          },
          {
            'style': MapTileStyle.light,
            'label': '經典馬卡龍',
            'desc': 'CartoDB 經典 Voyager 地圖'
          },
          {
            'style': MapTileStyle.dark,
            'label': '霓虹暗黑',
            'desc': '夜間高對比風格'
          },
          {
            'style': MapTileStyle.osm,
            'label': '經典地圖',
            'desc': 'OpenStreetMap 傳統樣式'
          },
          {
            'style': MapTileStyle.satellite,
            'label': '衛星地圖',
            'desc': '高清實景衛星圖'
          },
        ];

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      '選擇地圖配色風格',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: styles.map((item) {
                        final MapTileStyle style = item['style'] as MapTileStyle;
                        final String label = item['label'] as String;
                        final String desc = item['desc'] as String;
                        final bool isSelected = provider.tileStyle == style;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.indigo.withAlpha(20)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.indigo
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            dense: true,
                            title: Text(
                              label,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color:
                                    isSelected ? Colors.indigo : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(desc,
                                style: const TextStyle(fontSize: 11)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.indigo, size: 20)
                                : null,
                            onTap: () {
                              provider.setTileStyle(style);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            icon: const Icon(Icons.camera_alt_rounded, color: Colors.pinkAccent),
            tooltip: '導出/分享可愛地圖圖片',
            onPressed: () => _exportAndShareMapImage(context, activeTrip),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: '一鍵全覽視角',
            onPressed: () => _zoomToFitAll(landmarks),
          ),
          IconButton(
            icon: Icon(
              provider.labelDisplayMode == LabelDisplayMode.onMap
                  ? Icons.label
                  : (provider.labelDisplayMode == LabelDisplayMode.hidden
                      ? Icons.label_off_outlined
                      : Icons.view_carousel_rounded),
              color: provider.labelDisplayMode == LabelDisplayMode.onMap
                  ? Colors.amber
                  : (provider.labelDisplayMode == LabelDisplayMode.bottomDeck
                      ? Colors.pinkAccent
                      : null),
            ),
            tooltip: provider.labelDisplayMode == LabelDisplayMode.onMap
                ? '標籤模式 1：地圖常駐名稱 (點擊切換模式 2：隱藏標籤)'
                : (provider.labelDisplayMode == LabelDisplayMode.hidden
                    ? '標籤模式 2：隱藏標籤 (點擊切換模式 3：底部橫向卡片列)'
                    : '標籤模式 3：底部橫向卡片列 (點擊切換模式 1：地圖常駐名稱)'),
            onPressed: () => provider.cycleLabelDisplayMode(),
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
          // Pure Map Layer wrapped in RepaintBoundary (Only captures map, markers, and route lines/dots)
          RepaintBoundary(
            key: _repaintKey,
            child: FlutterMap(
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
                      alignment: Alignment.bottomCenter,
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
                                          style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          landmark.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      '📍 地址: ${landmark.address.isNotEmpty ? landmark.address : "無系統地址"}'),
                                  const SizedBox(height: 4),
                                  Text(
                                      '💡 筆記: ${landmark.notes.isNotEmpty ? landmark.notes : "無備註"}'),
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
                            // Permanent Label Badge
                            if (provider.showPermanentLabels)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(240),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: landmark.category.color,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(maxWidth: 210),
                                child: Text(
                                  landmark.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 3,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Map Pin Icon Badge
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: landmark.category.color,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Mode 3: Bottom Horizontal Carousel Deck
          if (provider.labelDisplayMode == LabelDisplayMode.bottomDeck &&
              landmarks.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: SizedBox(
                height: 115,
                child: PageView.builder(
                  controller: _carouselPageController,
                  itemCount: landmarks.length,
                  onPageChanged: (index) {
                    _mapController.move(landmarks[index].location, 15.5);
                  },
                  itemBuilder: (context, index) {
                    final landmark = landmarks[index];
                    final distNext = index < landmarks.length - 1
                        ? provider.calculateDistanceKm(
                            landmark.location, landmarks[index + 1].location)
                        : null;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(245),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                            color: landmark.category.color, width: 2),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: landmark.category.color,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(landmark.category.iconSymbol,
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        landmark.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (landmark.address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '📍 ${landmark.address}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (distNext != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '🚗 距下一站: ${distNext.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.navigation,
                                color: Colors.blue),
                            onPressed: () =>
                                _openGoogleMapsNavigation(landmark),
                            tooltip: 'Google 地圖導航',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Interactive UI Controls (Excluded from RepaintBoundary)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Icon Only Map Tile Selector Button
                FloatingActionButton.small(
                  heroTag: 'btn_tile_style',
                  tooltip: '選擇地圖配色',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo,
                  onPressed: () => _showTileStyleBottomSheet(context, provider),
                  child: const Icon(Icons.layers_rounded),
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
                    _mapController.move(
                        _mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1.0;
                    _mapController.move(
                        _mapController.camera.center, zoom);
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
