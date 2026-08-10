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
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
            accountName: Text(
              activeTrip.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              '共 ${activeTrip.landmarks.length} 個自訂地標 • ${activeTrip.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.map,
                  color: Theme.of(context).colorScheme.primary, size: 30),
            ),
          ),

          // Day Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          const Divider(),

          // Landmarks Reorderable List
          Expanded(
            child: landmarks.isEmpty
                ? const Center(
                    child: Text('本天數尚無加入的地標',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ReorderableListView.builder(
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
                              leading: CircleAvatar(
                                backgroundColor:
                                    item.category.color.withAlpha(50),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
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
                                          fontWeight: FontWeight.bold),
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
                                        color: Colors.blue, size: 20),
                                    tooltip: '開啟 Google 地圖導航',
                                    onPressed: () =>
                                        _openGoogleMapsNavigation(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.grey, size: 20),
                                    onPressed: () =>
                                        provider.deleteLandmark(item.id),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).pop(); // Close drawer
                                onSelectLandmark(item);
                              },
                            ),
                          ),
                          // Relative distance indicator
                          if (distNext != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.south,
                                      size: 14, color: Colors.indigo),
                                  const SizedBox(width: 4),
                                  Text(
                                    '相對距離: ${distNext.toStringAsFixed(1)} 公里',
                                    style: const TextStyle(
                                      fontSize: 11,
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
