import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../providers/trip_provider.dart';

Future<void> showEditLandmarkDialog(BuildContext context, Landmark landmark) {
  final nameController = TextEditingController(text: landmark.name);
  final addressController = TextEditingController(text: landmark.address);
  final notesController = TextEditingController(text: landmark.notes);
  LandmarkCategory selectedCategory = landmark.category;

  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('編輯地標'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '地點名稱 *'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LandmarkCategory>(
                    initialValue: selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '分類標籤',
                      border: OutlineInputBorder(),
                    ),
                    items: LandmarkCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, color: cat.color, size: 18),
                            const SizedBox(width: 6),
                            Text(cat.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: '系統地址 (選填)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: '備註與門票資訊 (選填)'),
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
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) return;
                  context.read<TripProvider>().updateLandmark(
                        landmark.id,
                        name: newName,
                        category: selectedCategory,
                        address: addressController.text.trim(),
                        notes: notesController.text.trim(),
                      );
                  Navigator.of(context).pop();
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
