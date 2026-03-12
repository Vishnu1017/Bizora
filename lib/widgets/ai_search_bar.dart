// ignore_for_file: unused_local_variable, avoid_print

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fuzzy/fuzzy.dart';
import 'dart:collection';

/// Advanced AI-Powered Search Bar with fuzzy matching, learning capabilities,
/// predictive search, and intelligent filtering
class AISearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function(Map<String, dynamic>)? onFilterChange;
  final List<DocumentSnapshot> data;
  final ValueNotifier<List<DocumentSnapshot>> searchResultsNotifier;
  final String hintText;
  final bool autoFocus;
  final bool showSuggestions;
  final bool showFilters;
  final bool showHistory;
  final bool enableVoice;
  final bool enableLearning;
  final int maxSuggestions;
  final int maxHistoryItems;
  final Duration debounceDuration;
  final Color? accentColor;
  final List<String> searchFields;
  final Map<String, double> fieldWeights;
  final List<String>? stopWords;
  final double fuzzyThreshold;
  final Function(String)? onVoiceSearch;
  final Widget? customLeading;
  final List<Widget>? customActions;

  const AISearchBar({
    super.key,
    required this.onSearch,
    this.onFilterChange,
    required this.data,
    required this.searchResultsNotifier,
    this.hintText = 'Search by name, email, phone, shop...',
    this.autoFocus = false,
    this.showSuggestions = true,
    this.showFilters = true,
    this.showHistory = true,
    this.enableVoice = false,
    this.enableLearning = true,
    this.maxSuggestions = 8,
    this.maxHistoryItems = 20,
    this.debounceDuration = const Duration(milliseconds: 150),
    this.accentColor,
    this.searchFields = const [
      'shopName',
      'ownerName',
      'email',
      'phone',
      'category',
      'address',
      'description',
    ],
    this.fieldWeights = const {
      'shopName': 2.0,
      'ownerName': 1.8,
      'email': 1.5,
      'phone': 1.5,
      'category': 1.2,
      'address': 1.0,
      'description': 0.8,
    },
    this.stopWords,
    this.fuzzyThreshold = 0.4,
    this.onVoiceSearch,
    this.customLeading,
    this.customActions,
  });

  @override
  State<AISearchBar> createState() => _AISearchBarState();
}

class _AISearchBarState extends State<AISearchBar>
    with TickerProviderStateMixin {
  // Controllers
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  late final AnimationController _expandController;
  AnimationController? _pulseController;
  late final AnimationController _suggestionsController;
  // Ultra fast search index
  final Map<DocumentSnapshot, String> _docSearchCache = {};
  final Map<String, List<DocumentSnapshot>> _tokenIndex = {};
  final Map<String, Set<String>> _prefixIndex = {};

  // Search state
  String _searchQuery = '';
  List<String> _suggestions = [];
  final Set<String> _recentSearches = LinkedHashSet<String>();

  // Filter state
  bool _showFilters = false;
  final Map<String, bool> _selectedFilters = {};
  DateTimeRange? _dateRangeFilter;
  String _sortBy = 'relevance';
  bool _sortAscending = false;

  // AI learning data
  final Map<String, double> _wordWeights = {};
  final Map<String, List<String>> _commonMisspellings = {};
  final Map<String, String> _corrections = {};
  final Map<String, List<String>> _synonyms = {};

  // Fuzzy search instance
  late Fuzzy<DocumentSnapshot> _fuzzy;

  // Debounce
  Timer? _debounceTimer;
  Timer? _learningTimer;

  // Voice search
  bool _isListening = false;

  // Recent searches storage key

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _focusNode = FocusNode();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseController!.repeat(reverse: true);
    _suggestionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _initializeFilters();
    _loadSearchHistory();
    _initializeFuzzySearch();
    _initializeAIModels();

    _focusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchTextChanged);

    if (widget.autoFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(AISearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data) {
      _initializeFuzzySearch();
    }
  }

  void _initializeFilters() {
    // Initialize filters based on data
    final categories = <String>{};
    final statuses = <String>{};

    for (var doc in widget.data) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['category'] != null) {
        categories.add(data['category'].toString());
      }
      if (data['status'] != null) {
        statuses.add(data['status'].toString());
      }
    }

    setState(() {
      for (var category in categories) {
        _selectedFilters['category_$category'] = false;
      }
      for (var status in statuses) {
        _selectedFilters['status_$status'] = false;
      }
    });
  }

  void _initializeFuzzySearch() {
    _docSearchCache.clear();
    _tokenIndex.clear();
    _prefixIndex.clear();

    for (var doc in widget.data) {
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null) continue;

      final buffer = StringBuffer();

      for (var field in widget.searchFields) {
        final value = data[field]?.toString().toLowerCase() ?? '';
        buffer.write('$value ');
      }

      final searchable = buffer.toString();
      _docSearchCache[doc] = searchable;

      final tokens = searchable.split(RegExp(r'\s+'));

      for (var token in tokens) {
        if (token.isEmpty) continue;

        _tokenIndex.putIfAbsent(token, () => []).add(doc);

        for (int i = 1; i <= token.length; i++) {
          final prefix = token.substring(0, i);

          _prefixIndex.putIfAbsent(prefix, () => <String>{}).add(token);
        }
      }
    }

    _fuzzy = Fuzzy<DocumentSnapshot>(
      widget.data,
      options: FuzzyOptions<DocumentSnapshot>(
        threshold: widget.fuzzyThreshold,
        shouldSort: true,
        tokenize: true,
        findAllMatches: false,
        minMatchCharLength: 2,
        keys: widget.searchFields.map((field) {
          return WeightedKey<DocumentSnapshot>(
            name: field,
            weight: widget.fieldWeights[field] ?? 1.0,
            getter: (doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?[field]?.toString().toLowerCase() ?? '';
            },
          );
        }).toList(),
      ),
    );
  }

  void _initializeAIModels() {
    // Initialize common misspellings
    _commonMisspellings.addAll({
      'restaurant': ['restraunt', 'resturant', 'resturent'],
      'pharmacy': ['farmacy', 'pharmasy', 'phamacy'],
      'grocery': ['grosery', 'grocary', 'grocerry'],
      'bakery': ['bakary', 'bakey', 'bakrey'],
      'electronics': ['electonics', 'elektronics', 'electronic'],
      'fashion': ['fasion', 'fashon', 'fahion'],
      'furniture': ['furnature', 'furnitur', 'furnitere'],
    });

    // Initialize synonyms
    _synonyms.addAll({
      'shop': ['store', 'outlet', 'retail', 'boutique'],
      'owner': ['seller', 'merchant', 'vendor', 'retailer'],
      'pending': ['waiting', 'new', 'unprocessed', 'queue'],
      'approved': ['accepted', 'verified', 'confirmed', 'valid'],
      'rejected': ['denied', 'declined', 'refused', 'disapproved'],
      'phone': ['mobile', 'cell', 'telephone', 'contact'],
      'email': ['mail', 'e-mail', 'electronic mail'],
    });

    // Train word weights based on existing data
    _trainWordWeights();
  }

  void _trainWordWeights() {
    // Analyze data to learn important words
    final wordFrequency = <String, int>{};

    for (var doc in widget.data) {
      final data = doc.data() as Map<String, dynamic>;
      for (var field in widget.searchFields) {
        final value = data[field]?.toString().toLowerCase() ?? '';
        final words = value.split(RegExp(r'\s+'));
        for (var word in words) {
          if (word.length > 2 && !_isStopWord(word)) {
            wordFrequency[word] = (wordFrequency[word] ?? 0) + 1;
          }
        }
      }
    }

    // Calculate TF-IDF inspired weights
    final totalDocs = widget.data.length;
    wordFrequency.forEach((word, freq) {
      final idf = math.log(totalDocs / (1 + freq));
      _wordWeights[word] = idf;
    });
  }

  bool _isStopWord(String word) {
    final stopWords =
        widget.stopWords ??
        const [
          'the',
          'and',
          'or',
          'but',
          'in',
          'on',
          'at',
          'to',
          'for',
          'of',
          'with',
          'by',
          'from',
          'as',
          'is',
          'was',
          'are',
        ];
    return stopWords.contains(word.toLowerCase());
  }

  void _loadSearchHistory() {
    // In a real app, load from SharedPreferences or Hive
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _searchQuery.isNotEmpty) {
      _expandController.forward();
      _generateSuggestions(_searchQuery);
    } else {
      _expandController.reverse();
    }
  }

  void _onSearchTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        final query = _searchController.text;
        setState(() => _searchQuery = query);

        if (query.isNotEmpty) {
          _performAISearch(query);
          if (widget.showSuggestions) {
            _generateSuggestions(query);
          }
        } else {
          widget.searchResultsNotifier.value = [];
          setState(() => _suggestions = []);
        }

        widget.onSearch(query);
      }
    });
  }

  void _performAISearch(String query) {
    if (query.trim().isEmpty) {
      widget.searchResultsNotifier.value = [];
      return;
    }

    final normalized = query.toLowerCase().trim();

    final tokens = normalized.split(RegExp(r'\s+'));

    final Set<DocumentSnapshot> fastResults = {};

    for (var token in tokens) {
      final prefixMatches = _prefixIndex[token];

      if (prefixMatches != null) {
        for (var match in prefixMatches) {
          final docs = _tokenIndex[match];
          if (docs != null) {
            fastResults.addAll(docs);
          }
        }
      }
    }

    List<DocumentSnapshot> results;

    if (fastResults.isNotEmpty) {
      results = fastResults.toList();
    } else {
      final fuzzyResults = _fuzzy.search(normalized);
      results = fuzzyResults.map((e) => e.item).toList();
    }

    results = _applyFilters(results);
    results = _applySorting(results, query);

    widget.searchResultsNotifier.value = results;

    if (widget.enableLearning) {
      _learnFromSearch(query, results);
    }
  }

  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> results) {
    if (_selectedFilters.isEmpty && _dateRangeFilter == null) {
      return results;
    }

    return results.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Category filters
      final selectedCategories = _selectedFilters.entries
          .where((e) => e.key.startsWith('category_') && e.value)
          .map((e) => e.key.replaceFirst('category_', ''))
          .toList();

      if (selectedCategories.isNotEmpty) {
        final docCategory = data['category']?.toString() ?? '';
        if (!selectedCategories.contains(docCategory)) {
          return false;
        }
      }

      // Status filters
      final selectedStatuses = _selectedFilters.entries
          .where((e) => e.key.startsWith('status_') && e.value)
          .map((e) => e.key.replaceFirst('status_', ''))
          .toList();

      if (selectedStatuses.isNotEmpty) {
        final docStatus = data['status']?.toString() ?? '';
        if (!selectedStatuses.contains(docStatus)) {
          return false;
        }
      }

      // Date range filter
      if (_dateRangeFilter != null) {
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final date = createdAt.toDate();
          if (date.isBefore(_dateRangeFilter!.start) ||
              date.isAfter(_dateRangeFilter!.end)) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  List<DocumentSnapshot> _applySorting(
    List<DocumentSnapshot> results,
    String query,
  ) {
    switch (_sortBy) {
      case 'date':
        results.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = (aData['createdAt'] as Timestamp?)?.toDate();
          final bDate = (bData['createdAt'] as Timestamp?)?.toDate();

          if (aDate == null || bDate == null) return 0;
          return _sortAscending
              ? aDate.compareTo(bDate)
              : bDate.compareTo(aDate);
        });
        break;

      case 'name':
        results.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = aData['shopName']?.toString() ?? '';
          final bName = bData['shopName']?.toString() ?? '';

          return _sortAscending
              ? aName.compareTo(bName)
              : bName.compareTo(aName);
        });
        break;

      case 'relevance':
      default:
        // Results are already sorted by relevance from fuzzy search
        if (!_sortAscending) {
          results = results.reversed.toList();
        }
        break;
    }

    return results;
  }

  void _generateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final normalized = query.toLowerCase();

    final prefixMatches = _prefixIndex[normalized];

    if (prefixMatches == null) {
      setState(() => _suggestions = []);
      return;
    }

    final suggestionList = prefixMatches.take(widget.maxSuggestions).toList();

    setState(() {
      _suggestions = suggestionList;
    });
  }

  void _learnFromSearch(String query, List<DocumentSnapshot> results) {
    _learningTimer?.cancel();
    _learningTimer = Timer(const Duration(seconds: 2), () {
      // Analyze click-through rate (in a real app)
      if (results.isNotEmpty) {
        // Boost words that led to results
        final words = query.toLowerCase().split(' ');
        for (var word in words) {
          if (word.length > 2) {
            _wordWeights[word] = (_wordWeights[word] ?? 1.0) * 1.1;
          }
        }
      }

      // Learn from no results (add to corrections)
      if (results.isEmpty) {
        final words = query.toLowerCase().split(' ');
        for (var word in words) {
          if (word.length > 3 && !_isStopWord(word)) {
            // Check if this might be a misspelling
            for (var correct in _wordWeights.keys) {
              if (_levenshteinDistance(word, correct) <= 2) {
                _corrections[word] = correct;
                break;
              }
            }
          }
        }
      }
    });
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (var i = 0; i <= s1.length; i++) matrix[i][0] = i;
    for (var j = 0; j <= s2.length; j++) matrix[0][j] = j;

    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _suggestions = [];
    });
    widget.searchResultsNotifier.value = [];
    widget.onSearch('');
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _expandController.forward();
      }
    });
  }

  void _applyFilter(String key, bool value) {
    setState(() {
      _selectedFilters[key] = value;
    });
    _performAISearch(_searchQuery);
    widget.onFilterChange?.call(_selectedFilters);
  }

  void _clearFilters() {
    setState(() {
      _selectedFilters.clear();
      _dateRangeFilter = null;
      _initializeFilters();
    });
    _performAISearch(_searchQuery);
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRangeFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.accentColor ?? Colors.deepPurple,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() => _dateRangeFilter = range);
      _performAISearch(_searchQuery);
    }
  }

  void _startVoiceSearch() {
    if (widget.enableVoice && widget.onVoiceSearch != null) {
      setState(() => _isListening = true);
      widget.onVoiceSearch!(_searchQuery);

      // Simulate voice recognition (in real app, use speech_to_text package)
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isListening = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _expandController.dispose();
    _pulseController?.dispose();
    _suggestionsController.dispose();
    _debounceTimer?.cancel();
    _learningTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? Colors.deepPurple;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main search bar
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _focusNode.hasFocus ? accentColor : Colors.grey.shade300,
                width: _focusNode.hasFocus ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 16),
            ),
            child: Row(
              children: [
                if (widget.customLeading != null)
                  widget.customLeading!
                else
                  AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (context, child) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: isSmallScreen ? 12 : 16,
                          right: isSmallScreen ? 8 : 12,
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          color: _focusNode.hasFocus
                              ? accentColor.withOpacity(
                                  0.5 + _pulseController!.value * 0.5,
                                )
                              : Colors.grey.shade400,
                          size: isSmallScreen ? 18 : 22,
                        ),
                      );
                    },
                  ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    onSubmitted: (value) {
                      _performAISearch(value);
                      _focusNode.unfocus();
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    onPressed: _clearSearch,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isSmallScreen ? 32 : 40,
                      minHeight: isSmallScreen ? 32 : 40,
                    ),
                  ),
                if (widget.showFilters)
                  IconButton(
                    icon: AnimatedBuilder(
                      animation: _expandController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _expandController.value * math.pi / 4,
                          child: Icon(
                            Icons.tune_rounded,
                            color: _showFilters
                                ? accentColor
                                : Colors.grey.shade400,
                            size: isSmallScreen ? 18 : 20,
                          ),
                        );
                      },
                    ),
                    onPressed: _toggleFilters,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isSmallScreen ? 32 : 40,
                      minHeight: isSmallScreen ? 32 : 40,
                    ),
                  ),
                if (widget.enableVoice)
                  IconButton(
                    icon: AnimatedBuilder(
                      animation: _pulseController!,
                      builder: (context, child) {
                        return Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? Colors.red
                              : Colors.grey.shade400,
                          size: isSmallScreen ? 18 : 20,
                        );
                      },
                    ),
                    onPressed: _startVoiceSearch,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: isSmallScreen ? 32 : 40,
                      minHeight: isSmallScreen ? 32 : 40,
                    ),
                  ),
                if (widget.customActions != null) ...widget.customActions!,
                SizedBox(width: isSmallScreen ? 4 : 8),
              ],
            ),
          ),

          // Filters section
          SizeTransition(
            sizeFactor: _expandController,
            axisAlignment: -1.0,
            child: _buildFiltersSection(accentColor, isSmallScreen),
          ),

          // Suggestions section
          if (widget.showSuggestions && _suggestions.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: isSmallScreen ? 150 : 200,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return _buildSuggestionTile(
                      _suggestions[index],
                      accentColor,
                      isSmallScreen,
                    );
                  },
                ),
              ),
            ),

          // Recent searches section
          if (widget.showHistory &&
              _recentSearches.isNotEmpty &&
              _searchQuery.isEmpty)
            _buildRecentSearches(accentColor, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(Color accentColor, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 13 : 14,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearFilters,
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),

          // Category filters
          if (_selectedFilters.keys.any((k) => k.startsWith('category_')))
            _buildFilterGroup(
              'Categories',
              _selectedFilters.entries
                  .where((e) => e.key.startsWith('category_'))
                  .toList(),
              accentColor,
              isSmallScreen,
            ),

          // Status filters
          if (_selectedFilters.keys.any((k) => k.startsWith('status_')))
            _buildFilterGroup(
              'Status',
              _selectedFilters.entries
                  .where((e) => e.key.startsWith('status_'))
                  .toList(),
              accentColor,
              isSmallScreen,
            ),

          // Date range filter
          _buildDateRangeFilter(accentColor, isSmallScreen),

          // Sort options
          _buildSortOptions(accentColor, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(
    String title,
    List<MapEntry<String, bool>> filters,
    Color accentColor,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Wrap(
            spacing: isSmallScreen ? 6 : 8,
            runSpacing: isSmallScreen ? 4 : 6,
            children: filters.map((filter) {
              final label = filter.key.split('_').last;
              final isSelected = filter.value;
              return FilterChip(
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                selected: isSelected,
                onSelected: (value) => _applyFilter(filter.key, value),
                backgroundColor: Colors.grey.shade100,
                selectedColor: accentColor,
                checkmarkColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeFilter(Color accentColor, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 12,
            vertical: isSmallScreen ? 8 : 10,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range_rounded,
                size: isSmallScreen ? 14 : 16,
                color: _dateRangeFilter != null
                    ? accentColor
                    : Colors.grey.shade400,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Expanded(
                child: Text(
                  _dateRangeFilter != null
                      ? '${DateFormat('dd MMM').format(_dateRangeFilter!.start)} - ${DateFormat('dd MMM').format(_dateRangeFilter!.end)}'
                      : 'Select date range',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: _dateRangeFilter != null
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
              ),
              if (_dateRangeFilter != null)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: isSmallScreen ? 14 : 16,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () {
                    setState(() => _dateRangeFilter = null);
                    _performAISearch(_searchQuery);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOptions(Color accentColor, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort by',
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Row(
          children: [
            _buildSortChip(
              'Relevance',
              'relevance',
              accentColor,
              isSmallScreen,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildSortChip('Date', 'date', accentColor, isSmallScreen),
            SizedBox(width: isSmallScreen ? 6 : 8),
            _buildSortChip('Name', 'name', accentColor, isSmallScreen),
            const Spacer(),
            IconButton(
              icon: Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: isSmallScreen ? 16 : 18,
                color: accentColor,
              ),
              onPressed: () {
                setState(() => _sortAscending = !_sortAscending);
                _performAISearch(_searchQuery);
              },
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: isSmallScreen ? 28 : 32,
                minHeight: isSmallScreen ? 28 : 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortChip(
    String label,
    String value,
    Color accentColor,
    bool isSmallScreen,
  ) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: isSmallScreen ? 11 : 12,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _sortBy = value);
        _performAISearch(_searchQuery);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: accentColor,
      checkmarkColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 4 : 6,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildSuggestionTile(
    String suggestion,
    Color accentColor,
    bool isSmallScreen,
  ) {
    return ListTile(
      leading: Icon(
        Icons.history_rounded,
        size: isSmallScreen ? 16 : 18,
        color: Colors.grey.shade400,
      ),
      title: Text(
        suggestion,
        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
      ),
      trailing: Icon(
        Icons.arrow_upward_rounded,
        size: isSmallScreen ? 14 : 16,
        color: Colors.grey.shade300,
      ),
      dense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 0,
      ),
      onTap: () {
        _searchController.text = suggestion;
        _performAISearch(suggestion);
        _focusNode.unfocus();
      },
    );
  }

  Widget _buildRecentSearches(Color accentColor, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent searches',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Wrap(
            spacing: isSmallScreen ? 6 : 8,
            runSpacing: isSmallScreen ? 4 : 6,
            children: _recentSearches.take(5).map((search) {
              return ActionChip(
                label: Text(
                  search,
                  style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                ),
                onPressed: () {
                  _searchController.text = search;
                  _performAISearch(search);
                },
                backgroundColor: Colors.grey.shade100,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
