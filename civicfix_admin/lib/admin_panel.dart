import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final int _limit = 10;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _issues = [];

  final List<String> _departments = [
    'All',
    'PWD',
    'JSD',
    'SMC',
    'KPDCL',
    'JKFD',
  ];
  String _selectedDept = 'All';

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  Future<void> _fetchIssues({bool loadMore = false}) async {
    if (_isLoadingMore || (!_hasMore && loadMore)) return;

    setState(() {
      _isLoadingMore = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('in_progress_issues')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (_selectedDept != 'All') {
      query = query.where('department_assigned', isEqualTo: _selectedDept);
    }

    if (loadMore && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    final newData = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['status'] = data['status'] ?? 'In Progress';
      data['department_assigned'] = data['department_assigned'] ?? 'Unassigned';
      return data;
    }).toList();

    setState(() {
      if (loadMore) {
        _issues.addAll(newData);
      } else {
        _issues = newData;
      }
      _lastDocument = snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : _lastDocument;
      _hasMore = snapshot.docs.length == _limit;
      _isLoadingMore = false;
    });
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = timestamp is Timestamp
          ? timestamp.toDate()
          : (timestamp is DateTime ? timestamp : DateTime.now());
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  void _openMap(double? lat, double? long) async {
    if (lat == null || long == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$long';
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 4,
      ),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _departments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final dept = _departments[index];
                final isSelected = dept == _selectedDept;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDept = dept;
                      _lastDocument = null;
                      _hasMore = true;
                    });
                    _fetchIssues();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      dept,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // List of issues
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (_hasMore &&
                    !_isLoadingMore &&
                    scrollInfo.metrics.pixels ==
                        scrollInfo.metrics.maxScrollExtent) {
                  _fetchIssues(loadMore: true);
                }
                return false;
              },
              child: _issues.isEmpty
                  ? const Center(
                      child: Text(
                        'No issues found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _issues.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _issues.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final data = _issues[index];
                        final imageUrl = data['imageUrl']?.toString();
                        final caption = data['caption'] ?? '';
                        final createdAt = data['createdAt'];
                        final location =
                            data['location'] as Map<String, dynamic>?;
                        final lat = location?['lat']?.toDouble();
                        final long = location?['long']?.toDouble();
                        final department = data['department_assigned'];
                        final status = data['status'];

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[850]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null && imageUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: SizedBox(
                                        height: 300,
                                        width: double.infinity,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  color: Colors.grey[900],
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              },
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: Colors.grey[900],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white38,
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _formatTimestamp(createdAt),
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Spacer(),
                                            Chip(
                                              label: Text(
                                                status,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor: Colors.orange,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (caption.isNotEmpty)
                                          Text(
                                            caption,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.5,
                                              height: 1.5,
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.apartment,
                                              size: 16,
                                              color: Colors.deepPurpleAccent,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                department,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (lat != null && long != null)
                                              InkWell(
                                                onTap: () =>
                                                    _openMap(lat, long),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors
                                                        .deepPurpleAccent
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          30,
                                                        ),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_pin,
                                                        size: 16,
                                                        color: Colors
                                                            .deepPurpleAccent,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Map",
                                                        style: TextStyle(
                                                          color: Colors
                                                              .deepPurpleAccent,
                                                          fontSize: 12.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
