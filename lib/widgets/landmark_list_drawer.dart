import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/landmark.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import '../utils/day_colors.dart';
import 'edit_landmark_dialog.dart';

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
                        if (dayLandmarks.isEmpty) {
                          // An empty day's header alone is only a sliver of
                          // vertical space -- when a card is dragged toward
                          // it, ReorderableListView's own drop-target math
                          // (based on comparing the dragged item's extent
                          // against each row's) can skip straight over the
                          // header (and even the next day's header right
                          // after it) without ever registering this day as
                          // a valid landing slot. Give an empty day a real,
                          // card-sized placeholder row so it has enough
                          // vertical footprint to actually be droppable.
                          flatNodes.add(_EmptyDayPlaceholderNode(d));
                        }
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
                        // Flutter's ReorderableListView already adjusts
                        // newIndex for the removed item before invoking
                        // onReorderItem -- do not decrement it again here.
                        final bool isDraggingDownwards = newIndex > oldIndex;

                        final emptyDaysBeforeDrag = flatNodes
                            .whereType<_EmptyDayPlaceholderNode>()
                            .map((n) => n.day)
                            .toSet();

                        final movedNode = flatNodes.removeAt(oldIndex);

                        if (movedNode is _LandmarkCardNode) {
                          final originalDay = movedNode.landmark.day;

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
                              // The landing slot is a day's last card, immediately
                              // followed by the next day's header. This is only a
                              // genuine cross-day drop (append after that day's
                              // last card) if the dragged item started on a
                              // DIFFERENT day. If it started on the SAME day as
                              // the landing card, this is a same-day reorder that
                              // happens to target the day's last position -- e.g.
                              // swapping the last two cards of a day -- and must
                              // NOT be pushed past the header, or it silently
                              // lands back at its original spot.
                              final landingCard =
                                  flatNodes[newIndex] as _LandmarkCardNode;
                              if (landingCard.landmark.day !=
                                  movedNode.landmark.day) {
                                newIndex = newIndex + 1;
                              }
                            }
                          }

                          // An empty day's header (or its placeholder row) is
                          // far shorter than the dragged card, so Flutter's own
                          // drop-target math can jump straight past an entire
                          // empty day without ever resolving newIndex to a slot
                          // inside it -- landing one or more days further than
                          // intended. Detect that: figure out which day
                          // newIndex would actually land in, and if getting
                          // there from originalDay skipped over a day that was
                          // empty before this drag, redirect to land in the
                          // FIRST such skipped empty day instead.
                          int resolvedDay = originalDay;
                          for (int i = 0; i < newIndex && i < flatNodes.length; i++) {
                            final n = flatNodes[i];
                            if (n is _DayHeaderNode) resolvedDay = n.day;
                          }
                          if (resolvedDay != originalDay) {
                            final step = resolvedDay > originalDay ? 1 : -1;
                            for (int d = originalDay + step;
                                d != resolvedDay;
                                d += step) {
                              if (emptyDaysBeforeDrag.contains(d)) {
                                final headerIdx = flatNodes.indexWhere(
                                    (n) => n is _DayHeaderNode && n.day == d);
                                if (headerIdx != -1) {
                                  newIndex = headerIdx + 1;
                                }
                                break;
                              }
                            }
                          }

                          flatNodes.insert(newIndex, movedNode);

                          if (provider.selectedDayFilter != null) {
                            // Filtered single-day view: flatNodes only holds
                            // that day's cards (no _DayHeaderNode present), so
                            // it must NOT be used as the full replacement list
                            // -- doing so would silently discard every other
                            // day's landmarks. Splice the reordered day back
                            // into the full, unfiltered landmark list instead.
                            final reorderedDayIds = flatNodes
                                .whereType<_LandmarkCardNode>()
                                .map((n) => n.landmark.id)
                                .toList();
                            final Map<String, Landmark> byId = {
                              for (final l in activeTrip.landmarks) l.id: l,
                            };
                            var dayCursor = 0;
                            final updatedLandmarks =
                                activeTrip.landmarks.map((l) {
                              if (l.day == provider.selectedDayFilter) {
                                return byId[reorderedDayIds[dayCursor++]]!;
                              }
                              return l;
                            }).toList();
                            provider.updateAllLandmarks(updatedLandmarks);
                          } else {
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
                          }
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
                        } else if (node is _EmptyDayPlaceholderNode) {
                          final dayColor = getDayColor(node.day);
                          return Container(
                            key: ValueKey(node.keyString),
                            width: double.infinity,
                            height: 64,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: dayColor.withAlpha(90), width: 1.2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '本天尚無地標，可從其他天拖曳地標到這裡',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: dayColor.withAlpha(180),
                                fontSize: 12,
                              ),
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
                                              Icon(item.category.icon,
                                                  color: item.category.color,
                                                  size: 16),
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
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message: '編輯此地點',
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16),
                                                  onTap: () =>
                                                      showEditLandmarkDialog(
                                                          context, item),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 4),
                                                    child: Icon(
                                                        Icons.edit_rounded,
                                                        color: Colors.grey,
                                                        size: 22),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message: '複製此地點',
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16),
                                                  onTap: () {
                                                    final newName = provider
                                                        .duplicateLandmark(
                                                            item.id);
                                                    if (newName != null) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              '已複製為「$newName」'),
                                                          duration:
                                                              const Duration(
                                                                  seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 4),
                                                    child: Icon(
                                                        Icons.copy_rounded,
                                                        color: Colors.grey,
                                                        size: 22),
                                                  ),
                                                ),
                                              ),
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

class _EmptyDayPlaceholderNode extends _DrawerNode {
  final int day;
  _EmptyDayPlaceholderNode(this.day) : super('empty_day_placeholder_$day');
}

class _LandmarkCardNode extends _DrawerNode {
  final Landmark landmark;
  final int dayIndex;
  final double? distNext;
  _LandmarkCardNode(this.landmark, this.dayIndex, this.distNext)
      : super('landmark_card_${landmark.id}');
}
