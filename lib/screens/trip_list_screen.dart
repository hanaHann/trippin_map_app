import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  void _showCreateTripDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('建立全新旅遊行程'),
          content: Column(
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  context.read<TripProvider>().addTrip(
                        titleController.text.trim(),
                        descController.text.trim(),
                      );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('建立'),
            ),
          ],
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
                  Chip(
                    avatar: const Icon(Icons.pin_drop, size: 14),
                    label: Text('${trip.landmarks.length} 個獨佔地標 (完全屏蔽雜訊)'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'select') {
                    provider.setActiveTrip(trip.id);
                    Navigator.of(context).pop();
                  } else if (val == 'delete') {
                    provider.deleteTrip(trip.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'select',
                    child: Text('切換至此行程'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('刪除行程', style: TextStyle(color: Colors.red)),
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
        onPressed: () => _showCreateTripDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增行程'),
      ),
    );
  }
}
