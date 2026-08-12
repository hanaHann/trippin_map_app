import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/landmark.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import '../utils/day_colors.dart';

class LandmarkListDrawer extends StatelessWidget {
  final Function(Landmark) onSelectLandmark;

  const LandmarkListDrawer({super.key, required this.onSelectLandmark});

  Future<void> _openGoogleMapsNavigation(Landmark landmark) async {
    final String name = landmark.name.trim();
    final String address = landmark.address.trim();

    // Prefer searching by landmark name (+ address if available) so Google Maps opens the Place Card
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

  void _showEditTripDialog(BuildContext context, Trip trip) {
    final titleController = TextEditingController(text: trip.title);
    final descController = TextEditingController(text: trip.description);
    int selectedTotalDays = trip.totalDays;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('編輯行程資訊'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '行程名稱',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: '行程描述 (選填)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedTotalDays,
                      decoration: const InputDecoration(
                        labelText: '行程總天數',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(30, (i) => i + 1)
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('共 $d 天'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedTotalDays = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      context.read<TripProvider>().updateTrip(
                            trip.id,
                            titleController.text.trim(),
                            descController.text.trim(),
                            selectedTotalDays,
                          );
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
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
      width: MediaQuery.of(context).size.width,
      child: Column(
        children: [
          // Compact Non-Blocking Drawer Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 14,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded,
                          color: Colors.white),
                      tooltip: '編輯行程天數與名稱',
                      onPressed: () => _showEditTripDialog(context, activeTrip),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: '關閉全螢幕選單',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '共 ${activeTrip.totalDays} 天 · ${activeTrip.landmarks.length} 個地點',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Day Filter Chips (Day Color Coded)
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
                ...List.generate(activeTrip.totalDays, (i) => i + 1).map((d) {
                  final dayColor = getDayColor(d);
                  final isSelected = provider.selectedDayFilter == d;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      avatar: CircleAvatar(
                        radius: 5,
                        backgroundColor: dayColor,
                      ),
                      label: Text(
                        '第 $d 天',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: dayColor,
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
                : Builder(builder: (context) {
                    final List<_DrawerNode> flatNodes = [];

                    if (provider.selectedDayFilter != null) {
                      final dayLandmarks = landmarks
                          .where((l) => l.day == provider.selectedDayFilter)
                          .toList();
                      for (int i = 0; i < dayLandmarks.length; i++) {
                        final item = dayLandmarks[i];
                        double? distNext;
                        if (i < dayLandmarks.length - 1) {
                          distNext = provider.calculateDistanceKm(
                              item.location, dayLandmarks[i + 1].location);
                        }
                        flatNodes.add(_LandmarkCardNode(item, i + 1, distNext));
                      }
                    } else {
                      final totalDays = activeTrip.totalDays;
                      for (int d = 1; d <= totalDays; d++) {
                        flatNodes.add(_DayHeaderNode(d));
                        final dayLandmarks =
                            landmarks.where((l) => l.day == d).toList();
                        for (int i = 0; i < dayLandmarks.length; i++) {
                          final item = dayLandmarks[i];
                          double? distNext;
                          if (i < dayLandmarks.length - 1) {
                            distNext = provider.calculateDistanceKm(
                                item.location, dayLandmarks[i + 1].location);
                          }
                          flatNodes.add(_LandmarkCardNode(item, i + 1, distNext));
                        }
                      }
                    }

                    return ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: flatNodes.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final bool isDraggingDownwards = newIndex > oldIndex;
                        if (newIndex > oldIndex) newIndex -= 1;

                        final movedNode = flatNodes.removeAt(oldIndex);

                        if (movedNode is _LandmarkCardNode) {
                          // Direction-aware Day Header drop logic:
                          // 1) Dragging DOWNWARDS onto a Day Header -> place AFTER the header (1st card of next day).
                          // 2) Dragging UPWARDS onto a day's last card -> place AFTER that last card (last card of previous day).
                          if (isDraggingDownwards) {
                            if (newIndex < flatNodes.length &&
                                flatNodes[newIndex] is _DayHeaderNode) {
                              newIndex = newIndex + 1;
                            }
                          } else {
                            if (newIndex < flatNodes.length - 1 &&
                                flatNodes[newIndex] is _LandmarkCardNode &&
                                flatNodes[newIndex + 1] is _DayHeaderNode) {
                              newIndex = newIndex + 1;
                            }
                          }
                          flatNodes.insert(newIndex, movedNode);

                          final List<Landmark> updatedLandmarks = [];
                          int currentDay = 1;
                          for (final node in flatNodes) {
                            if (node is _DayHeaderNode) {
                              currentDay = node.day;
                            } else if (node is _LandmarkCardNode) {
                              updatedLandmarks.add(
                                  node.landmark.copyWith(day: currentDay));
                            }
                          }
                          provider.updateAllLandmarks(updatedLandmarks);
                        } else if (movedNode is _DayHeaderNode) {
                          flatNodes.insert(newIndex, movedNode);
                          final newHeaderDays = flatNodes
                              .whereType<_DayHeaderNode>()
                              .map((h) => h.day)
                              .toList();
                          final Map<int, int> dayMapping = {};
                          for (int i = 0; i < newHeaderDays.length; i++) {
                            dayMapping[newHeaderDays[i]] = i + 1;
                          }
                          final newLandmarks = activeTrip.landmarks.map((l) {
                            final newDay = dayMapping[l.day] ?? l.day;
                            return l.copyWith(day: newDay);
                          }).toList();
                          newLandmarks.sort((a, b) => a.day.compareTo(b.day));
                          provider.updateAllLandmarks(newLandmarks);
                        }
                      },
                      itemBuilder: (context, index) {
                        final node = flatNodes[index];
                        if (node is _DayHeaderNode) {
                          final dayColor = getDayColor(node.day);
                          return Container(
                            key: ValueKey(node.keyString),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            margin: const EdgeInsets.only(
                                top: 12, bottom: 4, left: 10, right: 10),
                            decoration: BoxDecoration(
                              color: dayColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: dayColor.withAlpha(120), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 14, color: dayColor),
                                const SizedBox(width: 6),
                                Text(
                                  '第 ${node.day} 天',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: dayColor,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward_rounded,
                                      size: 16),
                                  color: dayColor,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  tooltip: '將整天行程上移',
                                  onPressed: node.day > 1
                                      ? () => provider.swapDays(
                                          node.day, node.day - 1)
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward_rounded,
                                      size: 16),
                                  color: dayColor,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                  tooltip: '將整天行程下移',
                                  onPressed: node.day <
                                          (provider.activeTrip?.totalDays ?? 1)
                                      ? () => provider.swapDays(
                                          node.day, node.day + 1)
                                      : null,
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(Icons.drag_handle,
                                        color: dayColor, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          final cardNode = node as _LandmarkCardNode;
                          final item = cardNode.landmark;
                          final dayIndex = cardNode.dayIndex;
                          final distNext = cardNode.distNext;
                          final dayColor = getDayColor(item.day);

                          return Column(
                            key: ValueKey(node.keyString),
                            children: [
                              Dismissible(
                                key: ValueKey('dismiss_${item.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_forever,
                                          color: Colors.white, size: 24),
                                      SizedBox(width: 6),
                                      Text(
                                        '刪除地點',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('確認刪除地點'),
                                          content: Text(
                                              '確定要刪除「${item.name}」嗎？刪除後將無法復原。'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: const Text('取消'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red),
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: const Text('刪除',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                },
                                onDismissed: (_) {
                                  provider.deleteLandmark(item.id);
                                },
                                child: Card(
                                  elevation: 1.5,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: dayColor.withAlpha(120),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      onSelectLandmark(item);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: dayColor,
                                                child: Text(
                                                  '$dayIndex',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(item.category.iconSymbol,
                                                  style: const TextStyle(
                                                      fontSize: 16)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    height: 1.3,
                                                  ),
                                                  softWrap: true,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              ReorderableDragStartListener(
                                                index: index,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 4),
                                                  child: Icon(Icons.drag_handle,
                                                      color: Colors.grey,
                                                      size: 22),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Subtitle details (Full Width)
                                          if (item.address.isNotEmpty ||
                                              item.notes.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 36),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (item.address.isNotEmpty)
                                                    Text(
                                                      '📍 ${item.address}',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black87),
                                                      softWrap: true,
                                                    ),
                                                  if (item.notes.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '💡 ${item.notes}',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .deepOrange),
                                                      softWrap: true,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],

                                          // Bottom Actions (Navigation Button & Swipe Left Hint)
                                          const SizedBox(height: 8),
                                          const Divider(height: 1),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _openGoogleMapsNavigation(
                                                        item),
                                                icon: const Icon(
                                                    Icons.navigation,
                                                    color: Colors.blue,
                                                    size: 16),
                                                label: const Text(
                                                    'Google 地圖導航',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.blue)),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Relative distance indicator to next point
                              if (distNext != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
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
                        }
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

abstract class _DrawerNode {
  final String keyString;
  _DrawerNode(this.keyString);
}

class _DayHeaderNode extends _DrawerNode {
  final int day;
  _DayHeaderNode(this.day) : super('day_header_$day');
}

class _LandmarkCardNode extends _DrawerNode {
  final Landmark landmark;
  final int dayIndex;
  final double? distNext;
  _LandmarkCardNode(this.landmark, this.dayIndex, this.distNext)
      : super('landmark_card_${landmark.id}');
}
