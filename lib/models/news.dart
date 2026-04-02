class News {
  final String id;
  final String title;
  final String content;
  final String summary;
  final String author;
  final String category;
  final String? imageUrl;
  final DateTime createdAt;

  // 1. ADD THESE TWO NEW FIELDS
  final List<String> likes;
  final List<dynamic> comments;
  final int shares;  // add to News model fields


  News({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.author,
    required this.category,
    this.imageUrl,
    required this.createdAt,

    // 2. REQUIRE THEM IN THE CONSTRUCTOR
    required this.likes,
    required this.comments,
    required this.shares
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['_id'] ?? '', // Mapping MongoDB's _id
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      summary: json['summary'] ?? '',
      author: json['author'] ?? 'Unknown',
      category: json['category'] ?? 'General',
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),

      // 3. SAFELY PARSE THEM FROM THE JSON
      // If the backend returns null, default to an empty list []
      likes: json['likes'] != null ? List<String>.from(json['likes']) : [],
      comments: json['comments'] != null ? List<dynamic>.from(json['comments']) : [],
      shares: json['shares'] ?? 0,

    );
  }
}