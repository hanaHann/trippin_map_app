import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../providers/trip_provider.dart';
import '../services/google_maps_parser.dart';
import '../services/nominatim_service.dart';

class AddLandmarkDialog extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final int? initialDay;

  const AddLandmarkDialog({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialDay,
  });

  @override
  State<AddLandmarkDialog> createState() => _AddLandmarkDialogState();
}

class _AddLandmarkDialogState extends State<AddLandmarkDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: Google Maps Link Parser
  final _linkController = TextEditingController();
  bool _isParsingLink = false;
  String? _parseError;

  // Tab 2: Keyword Search
  final _searchController = TextEditingController();
  List<SearchPlaceResult> _searchResults = [];
  bool _isSearching = false;

  // Form Fields
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  double? _selectedLat;
  double? _selectedLng;
  LandmarkCategory _selectedCategory = LandmarkCategory.attraction;
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialDay != null) {
      _selectedDay = widget.initialDay!;
    } else {
      final activeFilter = context.read<TripProvider>().selectedDayFilter;
      if (activeFilter != null) {
        _selectedDay = activeFilter;
      }
    }

    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLat = widget.initialLat;
      _selectedLng = widget.initialLng;
      _nameController.text = '地圖定位點';
      _tabController.index = 2; // Default to Manual/Picked tab
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _linkController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handlePasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _linkController.text = data.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 已自動貼上剪貼簿內容！'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ 剪貼簿中沒有文字內容'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _handlePasteToSearch() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _searchController.text = data.text!;
      });
      _handleSearch();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 已自動貼上剪貼簿內容並開始搜尋！'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ 剪貼簿中沒有文字內容'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _handleParseLink() async {
    setState(() {
      _isParsingLink = true;
      _parseError = null;
    });

    final result = await GoogleMapsParser.parseInput(_linkController.text);

    if (!mounted) return;

    setState(() {
      _isParsingLink = false;
    });

    if (result != null) {
      setState(() {
        _nameController.text = result.name;
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
        _tabController.animateTo(2); // Jump to Form Tab
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (result.resolutionMethod == 'viewport_coords') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
            content: Text(
              '⚠️ 提醒：此網址僅包含視角中心點\n若欲定位特定店家，請在 Google 地圖點選「特定店家地標圖示」再點「分享」複製連結！',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
            content: Text(
              '🎉 成功精準解析地標：「${result.name}」！',
            ),
          ),
        );
      }
    } else {
      setState(() {
        _parseError = '無法解析此連結，請確認網址或使用關鍵字搜尋。';
      });
    }
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    final results =
        await NominatimService.searchPlaces(_searchController.text);

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectSearchResult(SearchPlaceResult result) {
    setState(() {
      _nameController.text = result.displayName.split(',').first;
      _addressController.text = result.displayName;
      _selectedLat = result.latitude;
      _selectedLng = result.longitude;
      _tabController.animateTo(2); // Jump to Form
    });
  }

  void _submitForm() {
    if (_nameController.text.trim().isEmpty ||
        _selectedLat == null ||
        _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫地點名稱並確認經緯度！')),
      );
      return;
    }

    final newLandmark = Landmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      latitude: _selectedLat!,
      longitude: _selectedLng!,
      category: _selectedCategory,
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
      day: _selectedDay,
    );

    context.read<TripProvider>().addLandmark(newLandmark);
    Navigator.of(context).pop(newLandmark);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎉 已成功新增「${newLandmark.name}」到行程！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: screenHeight * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded),
                  const SizedBox(width: 8),
                  Text(
                    '新增自訂旅遊地標',
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
            ),
            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.link), text: 'Google 連結'),
                Tab(icon: Icon(Icons.search), text: '即時搜尋'),
                Tab(icon: Icon(Icons.edit_location), text: '詳細資料'),
              ],
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Google Maps Link Parser (Wrapped in SingleChildScrollView for Keyboard Safety)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '請貼上 Google 地圖分享連結或經緯度 (例如: @35.6812,139.7671 或 https://maps.app.goo.gl/...)',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _linkController,
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '在此貼上 Google 地圖分享網址...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.paste_rounded,
                                      color: Colors.indigo),
                                  tooltip: '貼上剪貼簿內容',
                                  onPressed: _handlePasteFromClipboard,
                                ),
                                if (_linkController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setState(() => _linkController.clear()),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_parseError != null) ...[
                          const SizedBox(height: 8),
                          Text(_parseError!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _handlePasteFromClipboard,
                                icon: const Icon(Icons.paste_rounded,
                                    color: Colors.indigo),
                                label: const Text('貼上剪貼簿'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isParsingLink ? null : _handleParseLink,
                                icon: _isParsingLink
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.bolt),
                                label: const Text('自動解析地點'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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

                  // Tab 2: Keyword Search (Scrollable ListView)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: '輸入景點、餐廳或地址名稱...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.paste_rounded,
                                            color: Colors.indigo),
                                        tooltip: '貼上剪貼簿內容並搜尋',
                                        onPressed: _handlePasteToSearch,
                                      ),
                                      if (_searchController.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => setState(() {
                                            _searchController.clear();
                                            _searchResults.clear();
                                          }),
                                        ),
                                    ],
                                  ),
                                ),
                                onSubmitted: (_) => _handleSearch(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSearching ? null : _handleSearch,
                              child: const Text('搜尋'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handlePasteToSearch,
                            icon: const Icon(Icons.paste_rounded,
                                color: Colors.indigo),
                            label: const Text('📋 貼上剪貼簿並搜尋'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          )
                        else
                          Expanded(
                            child: _searchResults.isEmpty
                                ? const Center(
                                    child: Text('輸入名稱或點擊貼上進行搜尋',
                                        style: TextStyle(color: Colors.grey)))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final item = _searchResults[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                            item.displayName.split(',').first,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        subtitle: Text(item.displayName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        leading: const Icon(Icons.place,
                                            color: Colors.redAccent),
                                        onTap: () => _selectSearchResult(item),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                  ),

                  // Tab 3: Detailed Form (Wrapped in SingleChildScrollView)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: '地點名稱 *',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<LandmarkCategory>(
                                initialValue: _selectedCategory,
                                decoration: InputDecoration(
                                  labelText: '分類標籤',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                items: LandmarkCategory.values.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Row(
                                      children: [
                                        Text(cat.iconSymbol),
                                        const SizedBox(width: 6),
                                        Text(cat.displayName,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCategory = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final activeTrip =
                                      context.watch<TripProvider>().activeTrip;
                                  final totalDays = activeTrip?.totalDays ?? 5;
                                  final maxDayOption = _selectedDay > totalDays
                                      ? _selectedDay
                                      : totalDays;

                                  return DropdownButtonFormField<int>(
                                    initialValue: _selectedDay,
                                    decoration: InputDecoration(
                                      labelText: '分配天數',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: List.generate(maxDayOption, (i) => i + 1)
                                        .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text('第 $d 天'),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedDay = val);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: '系統地址 (選填)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: '備註與門票資訊 (選填)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitForm,
                            icon: const Icon(Icons.check),
                            label: const Text('儲存並加到地圖'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
