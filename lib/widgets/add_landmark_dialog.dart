import 'dart:math' as math;
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
  bool _hasSearched = false;
  String? _searchError;

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
      final rawText = data.text!.trim();
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(rawText);
      if (urlMatch != null) {
        setState(() {
          _linkController.text = urlMatch.group(0)!;
          _parseError = null;
        });
        _handleParseLink();
      } else {
        setState(() {
          _linkController.text = rawText;
          _parseError =
              '⚠️ 剪貼簿中未偵測到有效網址（可能受中文輸入法或複製格式影響），請切換至英數鍵盤重新貼上網址！';
        });
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
    final text = _linkController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parseError = '請先貼上或輸入 Google 地圖網址！';
      });
      return;
    }

    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
    if (urlMatch == null &&
        !text.contains('goo.gl') &&
        !text.contains('google.com')) {
      setState(() {
        _parseError =
            '⚠️ 輸入內容非有效 Google 地圖網址（例如受中文輸入法影響轉為候選字）。請切換至英數鍵盤重新貼上網址！';
      });
      return;
    }

    setState(() {
      _isParsingLink = true;
      _parseError = null;
    });

    final result = await GoogleMapsParser.parseInput(text);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          content: Text(
            '🎉 成功精準解析地標：「${result.name}」！',
          ),
        ),
      );
    } else {
      setState(() {
        _parseError = '無法解析此連結，請確認網址或使用關鍵字搜尋。';
      });
    }
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchError = '請先輸入景點、餐廳或地址名稱！';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
    });

    final results =
        await NominatimService.searchPlaces(_searchController.text);

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
      if (results.isEmpty) {
        _searchError =
            '找不到與「${_searchController.text.trim()}」相符的地點，請換個關鍵字或改用「Google 連結」。';
      }
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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;

    // Total vertical margin for Dialog insetPadding (16 top + 16 bottom = 32)
    const double verticalMargin = 32.0;

    // Calculate exact max height available for Container without overflowing Dialog
    final availableHeight = screenHeight - viewInsetsBottom - verticalMargin;
    final maxDialogHeight =
        math.max(200.0, math.min(screenHeight * 0.70, availableHeight));

    return Dialog(
      insetPadding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + viewInsetsBottom,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: maxDialogHeight,
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
                Tab(text: 'Google 連結'),
                Tab(text: '即時搜尋'),
                Tab(text: '詳細資料'),
              ],
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Google Maps Link Parser
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '請貼上 Google 地圖分享連結',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _linkController,
                          maxLines: 2,
                          onChanged: (_) => setState(() {
                            if (_parseError != null) _parseError = null;
                          }),
                          decoration: InputDecoration(
                            hintText: '貼上 Google 地圖網址...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            suffixIcon: _linkController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() {
                                      _linkController.clear();
                                      _parseError = null;
                                    }),
                                  )
                                : null,
                          ),
                        ),
                        if (_parseError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _parseError!,
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handlePasteFromClipboard,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('貼上並解析'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _isParsingLink ? null : _handleParseLink,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isParsingLink
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('解析'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Keyword Search
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {
                                  if (_searchError != null) _searchError = null;
                                }),
                                decoration: InputDecoration(
                                  hintText: '輸入景點、餐廳或地址...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => setState(() {
                                            _searchController.clear();
                                            _searchResults.clear();
                                            _searchError = null;
                                            _hasSearched = false;
                                          }),
                                        )
                                      : null,
                                ),
                                onSubmitted: (_) => _handleSearch(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSearching ? null : _handleSearch,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('搜尋'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _handlePasteToSearch,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('貼上並搜尋'),
                          ),
                        ),
                        if (_searchError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _searchError!,
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          )
                        else
                          Expanded(
                            child: _searchResults.isEmpty
                                ? Center(
                                    child: Text(
                                      _hasSearched
                                          ? '查無結果'
                                          : '請輸入名稱或點擊貼上進行搜尋',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  )
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
                        if (_selectedLat == null || _selectedLng == null) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.amber.shade900, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '尚未選取座標定位點！請先在「Google 連結」解析或「即時搜尋」選取地點。',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: '分類標籤',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                items: LandmarkCategory.values.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(cat.iconSymbol),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            cat.displayName,
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                            const SizedBox(width: 8),
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
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: '分配天數',
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 12),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: List.generate(maxDayOption, (i) => i + 1)
                                        .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text('第 $d 天',
                                                  style: const TextStyle(fontSize: 12)),
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
