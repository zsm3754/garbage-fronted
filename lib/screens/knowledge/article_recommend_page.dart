import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'article_detail_page.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class ArticleRecommendPage extends StatefulWidget {
  const ArticleRecommendPage({super.key});

  @override
  State<ArticleRecommendPage> createState() => _ArticleRecommendPageState();
}

class _ArticleRecommendPageState extends State<ArticleRecommendPage> {
  List<dynamic> _articles = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  Set<int> _favoritedArticles = {};
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/article/recommend?count=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          setState(() {
            _articles = data['data'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextArticle() {
    if (_articles.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _articles.length;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_articles.isEmpty) return;
    
    final article = _articles[_currentIndex];
    final articleId = article['article_id'];
    
    debugPrint('当前文章数据: $article');
    debugPrint('文章ID: $articleId');
    
    if (articleId == null) {
      debugPrint('文章ID为空，无法收藏');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文章ID为空，无法收藏')),
        );
      }
      return;
    }
    
    if (_favoritedArticles.contains(articleId)) {
      // 取消收藏
      debugPrint('取消收藏文章ID: $articleId');
      final success = await _apiService.removeArticleFavorite(articleId);
      if (success && mounted) {
        setState(() {
          _favoritedArticles.remove(articleId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消收藏')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取消收藏失败')),
        );
      }
    } else {
      // 添加收藏
      debugPrint('添加收藏文章ID: $articleId');
      final success = await _apiService.addArticleFavorite(articleId);
      if (success && mounted) {
        setState(() {
          _favoritedArticles.add(articleId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏成功')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏失败，请查看控制台日志')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("垃圾小贴士"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _articles.isNotEmpty)
            IconButton(
              icon: Icon(
                _favoritedArticles.contains(_articles[_currentIndex]['id'])
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _favoritedArticles.contains(_articles[_currentIndex]['id'])
                    ? Colors.red
                    : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/beijing/beijing1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? const Center(
                  child: Text(
                    "No recommended articles",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Current article
                      Expanded(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  _articles[_currentIndex]['title'] ?? 'No title',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Content/Description
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Article content',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _articles[_currentIndex]['content'] ?? 
                                        _articles[_currentIndex]['summary'] ?? 
                                        'No content available',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Date
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, 
                                         size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getCurrentDate(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Next article button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _nextArticle,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text(
                                "Next article",
                                style: TextStyle(fontSize: 16),
                              ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
    );
  }

  String _getCurrentDate() {
    final date = DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
