import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/landmark.dart';
import '../providers/trip_provider.dart';

class LandmarkListDrawer extends StatelessWidget {
  final Function(Landmark) onSelectLandmark;

  const LandmarkListDrawer({super.key, required this.onSelectLandmark});

  Future<void> _openGoogleMapsNavigation(Landmark landmark) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${landmark.latitude},${landmark.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final activeTrip = provider.activeTrip;

    if (activeTrip == null) {
      return const Drawer(child: Center(child: Text('目前沒有選取的行程')));
    }

    final landmarks = provider.currentLandmarks;

    return Drawer(
      child: Column(
        children: [
          // Compact Non-Blocking Drawer Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.map, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeTrip.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '共 ${activeTrip.landmarks.length} 個地點',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '可按住右側 ☰ 拖曳排順序',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Day Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('全部天數'),
                  selected: provider.selectedDayFilter == null,
                  onSelected: (_) => provider.setSelectedDayFilter(null),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (i) => i + 1).map((d) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text('第 $d 天'),
                      selected: provider.selectedDayFilter == d,
                      onSelected: (selected) =>
                          provider.setSelectedDayFilter(selected ? d : null),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Landmarks Drag-to-Reorder List
          Expanded(
            child: landmarks.isEmpty
                ? const Center(
                    child: Text('本天數尚無加入的地標',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: landmarks.length,
                    onReorderItem: (oldIndex, newIndex) {
                      provider.reorderLandmarks(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = landmarks[index];
                      double? distNext;
                      if (index < landmarks.length - 1) {
                        distNext = provider.calculateDistanceKm(
                          item.location,
                          landmarks[index + 1].location,
                        );
                      }

                      return Column(
                        key: ValueKey(item.id),
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.only(
                                  left: 12, right: 8, top: 4, bottom: 4),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    item.category.color.withAlpha(40),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: item.category.color,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(item.category.iconSymbol,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.address.isNotEmpty)
                                    Text(item.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11)),
                                  if (item.notes.isNotEmpty)
                                    Text('💡 ${item.notes}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.deepOrange)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.navigation,
                                        color: Colors.blue, size: 18),
                                    tooltip: '開啟 Google 地圖導航',
                                    onPressed: () =>
                                        _openGoogleMapsNavigation(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.grey, size: 18),
                                    onPressed: () =>
                                        provider.deleteLandmark(item.id),
                                  ),
                                  // Drag Handle to Reorder
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Icon(Icons.drag_handle,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).pop(); // Close drawer
                                onSelectLandmark(item);
                              },
                            ),
                          ),
                          // Relative distance indicator to next point
                          if (distNext != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.south,
                                      size: 12, color: Colors.indigo),
                                  const SizedBox(width: 2),
                                  Text(
                                    '下個地點相對距離: ${distNext.toStringAsFixed(1)} 公里',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
