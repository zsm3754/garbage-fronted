import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_config.dart';
import '../knowledge/article_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> _favorites = [];
  List<dynamic> _articleFavorites = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. 加载垃圾分类收藏
      final favorites = await _apiService.getFavorites();
      
      // 2. 加载文章收藏
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '1';
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/fav/list/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      List<dynamic> articles = [];
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          final allFavorites = data['data'] ?? [];
          // 筛选出文章类型的收藏
          final articleFavorites = allFavorites.where((fav) => fav['item_type'] == 'article').toList();
          
          for (var fav in articleFavorites) {
            articles.add({
              'article_id': fav['item_id'],
              'title': fav['title'] ?? '文章 ${fav['item_id']}',
              'content': fav['content'] ?? '',
              'summary': fav['summary'] ?? '',
              'category_id': fav['category_id'],
              'created_at': fav['created_at'],
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _articleFavorites = articles;
        });
      }
    } catch (e) {
      debugPrint('加载收藏失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("加载失败: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFavorite(int exampleId) async {
    try {
      final success = await _apiService.removeFavorite(exampleId);
      if (success) {
        await _loadFavorites();
        _showSnackBar("已取消收藏");
      } else {
        _showSnackBar("取消收藏失败");
      }
    } catch (e) {
      _showSnackBar("操作失败: $e");
    }
  }

  Future<void> _removeArticleFavorite(int articleId) async {
    try {
      final success = await _apiService.removeArticleFavorite(articleId);
      if (success) {
        await _loadFavorites(); // 重新加载数据，触发 setState 刷新
        _showSnackBar("已取消收藏");
      } else {
        _showSnackBar("取消收藏失败");
      }
    } catch (e) {
      _showSnackBar("操作失败: $e");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '可回收物': return Colors.blue;
      case '有害垃圾': return Colors.red;
      case '厨余垃圾': return Colors.orange;
      case '其他垃圾': return Colors.grey;
      default: return Colors.green;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '可回收物': return Icons.recycling;
      case '有害垃圾': return Icons.warning;
      case '厨余垃圾': return Icons.compost;
      case '其他垃圾': return Icons.delete;
      default: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 DefaultTabController 包裹，设置 length 为 2，且默认选中第 1 个标签（文章收藏）
    return DefaultTabController(
      length: 2,
      initialIndex: 1, // 默认为 1（对应文章收藏），如果要默认垃圾分类请改为 0
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的收藏'),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: '垃圾分类'),
              Tab(text: '文章收藏'),
            ],
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
            : TabBarView(
                children: [
                  // 第 1 个 Tab：垃圾分类
                  _favorites.isEmpty ? _buildEmptyState() : _buildFavoritesList(),
                  // 第 2 个 Tab：文章收藏
                  _buildArticleFavoritesList(),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '暂无收藏',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text('收藏的垃圾信息将显示在这里', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('去搜索', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleEmptyState() {
    return Center(
      child: ListView( // 使用 ListView 确保在空状态下 RefreshIndicator 依然可以下拉
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '暂无文章收藏',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('收藏的文章将显示在这里', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          final example = favorite['garbage_example'] ?? favorite;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getCategoryColor(example['category'] ?? '').withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(example['category'] ?? ''),
                  color: _getCategoryColor(example['category'] ?? ''),
                ),
              ),
              title: Text(
                example['name'] ?? '未知',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '分类: ${example['category'] ?? '未知'}',
                    style: TextStyle(
                      color: _getCategoryColor(example['category'] ?? ''),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (example['tips'] != null && example['tips'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      example['tips'],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('取消收藏'),
                          content: Text('确定要取消收藏 "${example['name']}" 吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _removeFavorite(example['example_id']);
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("查看 ${example['name']} 详情")),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticleFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: Colors.green,
      child: _articleFavorites.isEmpty
          ? _buildArticleEmptyState()
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _articleFavorites.length,
              itemBuilder: (context, index) {
                final article = _articleFavorites[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.article, color: Colors.green),
                    title: Text(article['title'] ?? '无标题'),
                    subtitle: Text(article['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => _removeArticleFavorite(article['article_id']),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArticleDetailPage(
                            title: article['title'] ?? '文章详情',
                            categoryId: article['category_id'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}