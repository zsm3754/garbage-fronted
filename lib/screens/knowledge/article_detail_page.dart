import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class ArticleDetailPage extends StatefulWidget {
  final String title;
  final int? categoryId;

  const ArticleDetailPage({
    super.key,
    required this.title,
    this.categoryId,
  });

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  Map<String, dynamic>? _article;
  bool _isLoading = true;
  String? _error;
  bool _isFavorited = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadRandomArticle();
  }

  Future<void> _loadRandomArticle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 调用文章推荐接口，只获取一篇文章
      String url = '${ApiConfig.baseUrl}/article/recommend?count=1';
      if (widget.categoryId != null) {
        url += '&category_id=${widget.categoryId}';
      }
      
      final response = await http.get(
        Uri.parse(url),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        final articles = data['data'] ?? [];
        setState(() {
          _article = articles.isNotEmpty ? articles[0] : null;
          _isLoading = false;
          _isFavorited = false;
        });
      } else {
        setState(() {
          _error = data['msg'] ?? '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_article == null) return;
    
    final articleId = _article!['article_id'];
    if (articleId == null) return;
    
    if (_isFavorited) {
      // 取消收藏
      final success = await _apiService.removeArticleFavorite(articleId);
      if (success && mounted) {
        setState(() {
          _isFavorited = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消收藏')),
        );
      }
    } else {
      // 添加收藏
      final success = await _apiService.addArticleFavorite(articleId);
      if (success && mounted) {
        setState(() {
          _isFavorited = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏成功')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: widget.categoryId == 1 ? Colors.green : Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (_article != null)
            IconButton(
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited ? Colors.red : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRandomArticle,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRandomArticle,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_article == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无文章',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文章标题
          Text(
            _article!['title'] ?? '无标题',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // 文章信息
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(_article!['created_at']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
              if (_article!['category'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.categoryId == 1 ? Colors.green : Colors.purple)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _article!['category']['name'] ?? '未分类',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.categoryId == 1 ? Colors.green : Colors.purple,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          // 文章内容
          Text(
            _article!['content'] ?? '暂无内容',
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 32),
          // 刷新按钮
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadRandomArticle,
              icon: const Icon(Icons.refresh),
              label: const Text('换一篇文章'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.categoryId == 1 ? Colors.green : Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '未知时间';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '时间格式错误';
    }
  }
}
