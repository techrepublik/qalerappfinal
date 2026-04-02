import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'models/news.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NewsFeedPage extends StatefulWidget {
  final String lguCode;
  const NewsFeedPage({super.key, required this.lguCode});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  late Future<List<News>> _newsFuture;

  // Update this to your production URL when ready
  // final String apiBaseUrl = "http://192.168.1.7:3000";

  final String apiBaseUrl = "https://ems.qalertapp.com";

  final String _apiKey = dotenv.env['MOBILE_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _newsFuture = fetchNews();
  }

  @override
  void didUpdateWidget(NewsFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lguCode != widget.lguCode) {
      _refreshNews();
    }
  }

  Future<List<News>> fetchNews() async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v2/news/?lguCode=${widget.lguCode}');
      final response = await http.get(uri, headers: {
        'x-api-key': _apiKey,
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(utf8.decode(response.bodyBytes));
        if (decodedData['success'] == true) {
          List<dynamic> newsList = decodedData['data'];
          return newsList.map((item) => News.fromJson(item)).toList();
        }
      }
      throw Exception('Failed to load news feed');
    } catch (e) {
      throw ('Network error: connection failed!');
    }
  }

  void _refreshNews() {
    setState(() => _newsFuture = fetchNews());
  }

  @override
  Widget build(BuildContext context) {
    const Color darkMint = Color(0xFF3EB489);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("News Feed", style: TextStyle(color: darkMint, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<News>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(itemCount: 4, itemBuilder: (context, index) => const NewsCardSkeleton());
          }
          if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));

          final newsItems = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async => _refreshNews(),
            color: darkMint,
            child: ListView.builder(
              itemCount: newsItems.length,
              itemBuilder: (context, index) => NewsCard(
                news: newsItems[index],
                apiBaseUrl: apiBaseUrl, // Pass URL down to the card
              ),
            ),
          );
        },
      ),
    );
  }
}

class NewsCard extends StatefulWidget {
  final News news;
  final String apiBaseUrl;
  const NewsCard({super.key, required this.news, required this.apiBaseUrl});

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool isExpanded = false;
  late List<dynamic> _likes;
  late List<dynamic> _comments;
  bool _isLiked = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _likes = List.from(widget.news.likes ?? []);
    _comments = List.from(widget.news.comments ?? []);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    setState(() {
      _currentUserId = userId;
      _isLiked = _likes.any((l) => l['userId'] == userId);
    });
  }

  String _getDisplayName(String fullName) {
    final firstName = fullName.trim().split(' ').first;
    const maxLength = 10;
    return firstName.length > maxLength
        ? '${firstName.substring(0, maxLength)}...'
        : firstName;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = date is DateTime ? date : DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _showCommentModal(BuildContext context) {
    final TextEditingController commentController = TextEditingController();
    final ValueNotifier<int> charCount = ValueNotifier(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text("Comments",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),

                    // Comments List
                    Expanded(
                      child: _comments.isEmpty
                          ? const Center(
                        child: Text("No comments yet. Be the first!",
                            style: TextStyle(color: Colors.grey)),
                      )
                          : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFD4F0E4),
                                  child: Text(
                                    (comment['userName'] ?? 'U')
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Color(0xFF3EB489),
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Bubble
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F2F5),
                                          borderRadius:
                                          BorderRadius.circular(14),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['userName'] ??
                                                  'User',
                                              style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              comment['text'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8, top: 4),
                                        child: Text(
                                          _formatDate(
                                              comment['createdAt']),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Input Area
                    Container(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 75,
                        left: 12, right: 12, top: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                              color: Colors.grey.shade200, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF3EB489), width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              child: ValueListenableBuilder<int>(
                                valueListenable: charCount,
                                builder: (_, count, __) => TextField(
                                  controller: commentController,
                                  autofocus: false,
                                  maxLines: 4,
                                  minLines: 1,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                  onChanged: (val) =>
                                  charCount.value = val.length,
                                  decoration: const InputDecoration(
                                    hintText: "Write a comment...",
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Post Button
                          GestureDetector(
                            onTap: () async {
                              if (commentController.text.trim().isNotEmpty) {
                                final text = commentController.text.trim();
                                // Optimistic update
                                final prefs =
                                await SharedPreferences.getInstance();
                                final userName =
                                    prefs.getString('name') ?? 'Guest';
                                final newComment = {
                                  'userName': _getDisplayName(userName),
                                  'text': text,
                                  'createdAt':
                                  DateTime.now().toIso8601String(),
                                };
                                setModalState(
                                        () => _comments.insert(0, newComment));
                                setState(() {});
                                commentController.clear();
                                charCount.value = 0;
                                // Post to backend
                                await _interact('comment',
                                    commentText: text, silent: true);
                              }
                            },
                            child: Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3EB489),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }



  Future<void> _interact(String action,
      {String? commentText, bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');
    final String? userName = prefs.getString('name') ?? 'Guest';

    if (userId == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please login to interact")));
      }
      return;
    }


    if (action == 'share') {
      // ❌ Don't use Uri.encodeComponent — Uri.parse handles encoding
      final String shareUrl = '${widget.apiBaseUrl}/news/${widget.news.id}';

      final Uri fbUrl = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(shareUrl)}'
      );

      if (await canLaunchUrl(fbUrl)) {
        await launchUrl(fbUrl, mode: LaunchMode.externalApplication);
      }
    }


    // Optimistic UI for LIKE
    if (action == 'like') {
      setState(() {
        if (_isLiked) {
          _likes.removeWhere((l) => l['userId'] == userId);
          _isLiked = false;
        } else {
          _likes.add({'userId': userId, 'userName': userName});
          _isLiked = true;
        }
      });
    }

    final url = Uri.parse(
        '${widget.apiBaseUrl}/api/v2/news/${widget.news.id}/interact');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': dotenv.env['MOBILE_API_KEY'] ?? '',
        },
        body: json.encode({
          'action': action,
          'userId': userId,
          'userName': _getDisplayName(userName!),
          if (commentText != null) 'text': commentText,
        }),
      );

      if (response.statusCode == 200) {
        // Sync real data from server response
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['data'] != null) {
          setState(() {
            if (data['data']['likes'] != null) {
              _likes = List.from(data['data']['likes']);
              _isLiked = _likes.any((l) => l['userId'] == userId);
            }
            if (data['data']['comments'] != null) {
              _comments = List.from(data['data']['comments']);
            }
          });
        }
      } else if (action == 'like') {
        // Revert optimistic update on failure
        setState(() {
          if (_isLiked) {
            _likes.removeWhere((l) => l['userId'] == userId);
            _isLiked = false;
          } else {
            _likes.add({'userId': userId});
            _isLiked = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Interaction failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkMint = Color(0xFF3EB489);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFD4F0E4),
                  child: const Icon(Icons.person, color: darkMint),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.news.author,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      "${widget.news.createdAt.day}/${widget.news.createdAt.month} • ${widget.news.category}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Title & Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.news.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => isExpanded = !isExpanded),
                  child: Text(
                    isExpanded ? widget.news.content : widget.news.summary,
                    maxLines: isExpanded ? null : 3,
                    style: const TextStyle(
                        fontSize: 15, height: 1.4, color: Colors.black87),
                  ),
                ),
                if (!isExpanded)
                  TextButton(
                    onPressed: () => setState(() => isExpanded = true),
                    child: const Text("See more...",
                        style: TextStyle(
                            color: darkMint, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // 3. Image
          if (widget.news.imageUrl != null && widget.news.imageUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImage(
                      imageUrl: widget.news.imageUrl!, tag: widget.news.id),
                ),
              ),
              child: Hero(
                tag: widget.news.id,
                child: Image.network(widget.news.imageUrl!, fit: BoxFit.cover),
              ),
            ),

          const Divider(height: 20),

          // 4. Counts Row
          if (_likes.isNotEmpty || _comments.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_likes.isNotEmpty)
                    Row(children: [
                      Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                            color: darkMint, shape: BoxShape.circle),
                        child: const Icon(Icons.thumb_up,
                            size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 5),
                      Text("${_likes.length}",
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ])
                  else
                    const SizedBox.shrink(),
                  if (_comments.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showCommentModal(context),
                      child: Text(
                        "${_comments.length} comment${_comments.length == 1 ? '' : 's'}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),

          const Divider(height: 10),

          // 5. Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Like button — changes color when liked
                InkWell(
                  onTap: () => _interact('like'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    child: Row(children: [
                      Icon(
                        _isLiked
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 20,
                        color: _isLiked ? darkMint : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text("Like",
                          style: TextStyle(
                            color: _isLiked ? darkMint : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                ),
                _buildActionButton(Icons.comment_outlined, "Comment",
                        () => _showCommentModal(context)),
                _buildActionButton(
                    Icons.share_outlined, "Share", () => _interact('share')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
        const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}



// ==========================================
// SKELETON & IMAGE VIEWER CLASSES BELOW
// ==========================================

class SkeletonItem extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonItem({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<SkeletonItem> createState() => _SkeletonItemState();
}

class _SkeletonItemState extends State<SkeletonItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class NewsCardSkeleton extends StatelessWidget {
  const NewsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SkeletonItem(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonItem(width: 120, height: 12),
                    SizedBox(height: 6),
                    SkeletonItem(width: 80, height: 10),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonItem(width: double.infinity, height: 18),
                SizedBox(height: 10),
                SkeletonItem(width: double.infinity, height: 14),
                SizedBox(height: 6),
                SkeletonItem(width: 200, height: 14),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: const SkeletonItem(
                width: double.infinity,
                height: 200,
                borderRadius: 0
            ),
          ),
          const Divider(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SkeletonItem(width: 60, height: 15),
              SkeletonItem(width: 60, height: 15),
              SkeletonItem(width: 60, height: 15),
            ],
          ),
        ],
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImage({super.key, required this.imageUrl, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}