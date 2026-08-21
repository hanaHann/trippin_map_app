import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  Future<void> _confirmDeleteTrip(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認刪除行程'),
            content: Text('確定要刪除「${trip.title}」嗎？刪除後將無法復原。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('刪除', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && context.mounted) {
      context.read<TripProvider>().deleteTrip(trip.id);
    }
  }

  void _showTripDialog(BuildContext context, {Trip? trip}) {
    final isEditing = trip != null;
    final titleController = TextEditingController(text: trip?.title ?? '');
    final descController = TextEditingController(text: trip?.description ?? '');
    int selectedDays = trip?.totalDays ?? 5;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? '編輯行程資訊' : '建立全新旅遊行程'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '行程名稱 (例如: 2026 東京5天4夜)',
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
                      initialValue: selectedDays,
                      decoration: const InputDecoration(
                        labelText: '規劃總天數',
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
                          setDialogState(() => selectedDays = val);
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
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      if (isEditing) {
                        context.read<TripProvider>().updateTrip(
                              trip.id,
                              title,
                              descController.text.trim(),
                              selectedDays,
                            );
                      } else {
                        context.read<TripProvider>().addTrip(
                              title,
                              descController.text.trim(),
                              totalDays: selectedDays,
                            );
                      }
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(isEditing ? '儲存修改' : '建立'),
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
    final trips = provider.trips;
    final activeId = provider.activeTripId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('行程列表與過濾遮罩'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          final isActive = trip.id == activeId;

          return Card(
            elevation: isActive ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isActive
                  ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                  : BorderSide.none,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: isActive ? Colors.indigo : Colors.grey.shade300,
                child: Icon(
                  Icons.map_rounded,
                  color: isActive ? Colors.white : Colors.grey.shade700,
                ),
              ),
              title: Text(
                trip.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(trip.description.isNotEmpty
                      ? trip.description
                      : '尚無描述'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.calendar_month, size: 14),
                        label: Text('共 ${trip.totalDays} 天'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        avatar: const Icon(Icons.pin_drop, size: 14),
                        label: Text('${trip.landmarks.length} 個獨佔地標'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'select') {
                    provider.setActiveTrip(trip.id);
                    Navigator.of(context).pop();
                  } else if (val == 'edit') {
                    _showTripDialog(context, trip: trip);
                  } else if (val == 'delete') {
                    _confirmDeleteTrip(context, trip);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'select',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('切換至此行程'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('編輯行程 (名稱/天數)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('刪除行程', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                provider.setActiveTrip(trip.id);
                Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTripDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增行程'),
      ),
    );
  }
}
