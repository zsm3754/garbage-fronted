import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ApiService {
  static String? _accessToken;

  // 设置JWT令牌
  static void setAuthToken(String token) {
    _accessToken = token;
  }

  // 清除JWT令牌
  static void clearAuthToken() {
    _accessToken = null;
  }

  // 获取请求头
  static Map<String, String> _getHeaders({bool needAuth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (needAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // 用户注册
  Future<Map<String, dynamic>> registerUser(String username, String password, {String? email}) async {
    try {
      final body = {'username': username, 'password': password};
      if (email != null) body['email'] = email;
      
      debugPrint('注册请求: ${ApiConfig.baseUrl}/user/register');
      debugPrint('请求体: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/register'),
        headers: _getHeaders(needAuth: false),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('响应状态码: ${response.statusCode}');
      debugPrint('响应体: ${response.body}');
      
      // 检查响应是否为有效的JSON格式
      if (response.body.isEmpty) {
        return {'success': false, 'error': '服务器返回空响应'};
      }
      
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        // 如果不是JSON格式，直接返回原始响应
        if (response.statusCode >= 500) {
          return {'success': false, 'error': '服务器内部错误，请稍后重试'};
        } else if (response.statusCode >= 400) {
          return {'success': false, 'error': '请求错误，请检查输入信息'};
        } else {
          return {'success': false, 'error': '服务器响应格式错误: ${response.body}'};
        }
      }
      
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        String errorMsg = data['msg'] ?? data['message'] ?? '注册失败';
        if (response.statusCode >= 500) {
          errorMsg = '服务器错误，请稍后重试';
        } else if (response.statusCode == 400) {
          errorMsg = '请求参数错误';
        }
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      debugPrint('注册异常: $e');
      String errorMsg = '注册失败';
      if (e.toString().contains('Connection refused')) {
        errorMsg = '无法连接到服务器，请检查网络';
      } else if (e.toString().contains('timeout')) {
        errorMsg = '请求超时，请重试';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = '网络连接失败，请检查网络设置';
      }
      return {'success': false, 'error': errorMsg};
    }
  }

  // 用户登录
  Future<Map<String, dynamic>> loginUser(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/login'),
        headers: _getHeaders(needAuth: false),
        body: jsonEncode({'username': username, 'password': password}),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        // 简化：直接使用data作为返回，让AuthProvider处理
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['msg'] ?? '登录失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取当前用户信息
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      // 获取当前登录用户的ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '1';
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/$userId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': '获取用户信息失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取每日问卷
  Future<Map<String, dynamic>> getTodayQuiz() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/quiz/today'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      
      
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': data['msg'] ?? '获取题目失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 提交问卷答案
  Future<Map<String, dynamic>> submitQuizAnswer(int quizId, String answer, {String? userId}) async {
    try {
      // 如果没有传入userId，尝试从本地存储获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id') ?? '';
      }
      
      // 构建请求体，确保user_id是整数
      Map<String, dynamic> requestBody = {
        'quiz_id': quizId,
        'answer': answer,
      };
      
      // 只有当userId不为空时才添加user_id
      if (userId.isNotEmpty) {
        final userIdInt = int.tryParse(userId);
        if (userIdInt != null) {
          requestBody['user_id'] = userIdInt;
        }
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/quiz/submit'),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      );
      
      final data = jsonDecode(response.body);
      
      
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        // 提供更详细的错误信息
        String errorMessage = '提交失败';
        if (data['msg'] != null) {
          errorMessage = data['msg'];
        } else if (data['detail'] != null) {
          errorMessage = data['detail'].toString();
        } else if (response.statusCode != 200) {
          errorMessage = 'HTTP错误: ${response.statusCode}';
        }
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 搜索垃圾
  Future<Map<String, dynamic>> searchGarbage(String keyword) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/search/keyword?keyword=$keyword'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': '搜索失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 添加搜索历史
  Future<bool> addSearchHistory(String searchQuery, {String? userId}) async {
    try {
      // 如果没有传入userId，尝试从本地存储获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id') ?? '1'; // 默认使用用户ID=1，与profile接口一致
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/search/history/add'),
        headers: _getHeaders(),
        body: jsonEncode({
          'user_id': int.tryParse(userId) ?? 1,
          'search_query': searchQuery
        }),
      );
      
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  // 获取搜索历史
  Future<List<dynamic>> getSearchHistory({String? userId}) async {
    try {
      // 如果没有传入userId，尝试从本地存储获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id') ?? '1'; // 默认使用用户ID=1，与profile接口一致
      }
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/search/history/$userId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 删除搜索历史
  static Future<bool> deleteSearchHistory(int historyId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/search/history/$historyId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  // 清空用户所有搜索历史
  static Future<bool> clearAllSearchHistory({String? userId}) async {
    try {
      // 如果没有传入userId，尝试从本地存储获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id') ?? '1'; // 默认使用用户ID=1，与profile接口一致
      }
      
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/search/history/clear/$userId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  // 获取用户真实排名
  static Future<Map<String, dynamic>> getUserRanking({String? userId}) async {
    try {
      // 如果没有传入userId，尝试从本地存储获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id') ?? '1'; // 默认使用用户ID=1，与profile接口一致
      }
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/rank/user/$userId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': data['detail'] ?? '获取排名失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // AI识别垃圾 - 支持Web和APP
  Future<Map<String, dynamic>> recognizeGarbage(dynamic imageFile) async {
    try {
      // 尝试多个可能的API路径
      final urls = [
        '${ApiConfig.baseUrl}/garbage/recognize',
        '${ApiConfig.baseUrl}/recognize',
        '${ApiConfig.baseUrl}/garbage/classify',
        '${ApiConfig.baseUrl}/classify',
      ];
      
      Map<String, dynamic>? data;
      int? statusCode;
      String? successUrl;
      
      for (String url in urls) {
        try {
          final request = http.MultipartRequest('POST', Uri.parse(url));
          request.headers.addAll(_getHeaders());
          
          // 根据平台处理文件上传
          if (kIsWeb) {
            // Web平台使用XFile
            if (imageFile is XFile) {
              final bytes = await imageFile.readAsBytes();
              final mimeType = lookupMimeType(imageFile.name) ?? 'image/jpeg';
              
              // 尝试不同的参数名
              if (url.contains('garbage/recognize')) {
                request.files.add(http.MultipartFile.fromBytes(
                  'file',
                  bytes,
                  filename: imageFile.name,
                  contentType: MediaType.parse(mimeType),
                ));
              } else {
                request.files.add(http.MultipartFile.fromBytes(
                  'image',
                  bytes,
                  filename: imageFile.name,
                  contentType: MediaType.parse(mimeType),
                ));
              }
            }
          } else {
            // APP平台使用File
            if (imageFile is File) {
              // 尝试不同的参数名
              if (url.contains('garbage/recognize')) {
                request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
              } else {
                request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
              }
            }
          }
          
          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          
          // 先检查响应状态码，再尝试解析JSON
          statusCode = response.statusCode;
          successUrl = url;
          
          // 只有状态码为200时才尝试解析JSON
          if (response.statusCode == 200) {
            try {
              data = jsonDecode(response.body);
            } catch (e) {
              continue; // 尝试下一个URL
            }
            break; // 找到可用的API
          } else {
            // 非200状态码，尝试解析错误信息
            try {
              data = jsonDecode(response.body);
            } catch (e) {
              data = {'detail': response.body}; // 使用原始响应作为错误信息
            }
          }
        } catch (e) {
          continue; // 尝试下一个URL
        }
      }
      
      if (statusCode == 200 && data != null) {
        // 处理后端返回的预测结果
        List<dynamic> processedResults = [];
        
        // 检查是否有data字段（后端标准格式）
        if (data['data'] != null && data['data'] is List) {
          final dataList = data['data'] as List;
          
          for (var item in dataList) {
            if (item is Map<String, dynamic>) {
              String className = item['item'] ?? 'unknown'; // 后端返回的是item不是class
              double confidence = (item['confidence'] ?? 0.0).toDouble();
              
              // 将英文分类名转换为中文
              String chineseName = _translateClassName(className);
              
              processedResults.add({
                'item': chineseName,
                'class': className,
                'confidence': confidence,
              });
            }
          }
        }
        // 检查是否有predictions字段（YOLO模型直接返回格式）
        else if (data['predictions'] != null) {
          final predictions = data['predictions'] as List;
          
          for (var pred in predictions) {
            String className = pred['class'] ?? 'unknown';
            double confidence = (pred['confidence'] ?? 0.0).toDouble();
            
            // 将英文分类名转换为中文
            String chineseName = _translateClassName(className);
            
            processedResults.add({
              'item': chineseName,
              'class': className,
              'confidence': confidence,
            });
          }
        }
        // 检查是否是YOLO直接返回的格式（没有包装）
        else if (data['item'] != null && data['confidence'] != null) {
          String className = data['item']; // 后端返回的是item
          double confidence = (data['confidence'] ?? 0.0).toDouble();
          String chineseName = _translateClassName(className);
          
          processedResults.add({
            'item': chineseName,
            'class': className,
            'confidence': confidence,
          });
        }
        
        if (processedResults.isEmpty) {
          return {'success': false, 'error': '未识别到垃圾类型'};
        }
        
        return {'success': true, 'data': processedResults};
      } else {
        return {'success': false, 'error': '识别失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 将英文分类名转换为中文
  String _translateClassName(String className) {
    switch (className.toLowerCase()) {
      case 'kitchen':
      case 'wet':
        return '湿垃圾';
      case 'recyclable':
        return '可回收物';
      case 'harmful':
        return '有害垃圾';
      case 'other':
      case 'dry':
        return '干垃圾';
      default:
        return '未知垃圾';
    }
  }

  // 获取所有分类
  Future<Map<String, dynamic>> getAllCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/category/all'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': '获取分类失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取分类详情
  Future<Map<String, dynamic>> getCategoryDetail(String categoryName) async {
    try {
      // 尝试多个可能的API路径
      final urls = [
        '${ApiConfig.baseUrl}/category/detail?name=$categoryName',
        '${ApiConfig.baseUrl}/category/$categoryName',
        '${ApiConfig.baseUrl}/categories/$categoryName',
        '${ApiConfig.baseUrl}/categories/detail?name=$categoryName',
      ];
      
      Map<String, dynamic>? data;
      int? statusCode;
      String? successUrl;
      
      for (String url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: _getHeaders(),
          );
          
          data = jsonDecode(response.body);
          statusCode = response.statusCode;
          successUrl = url;
          
          if (response.statusCode == 200) {
            break; // 找到可用的API
          }
        } catch (e) {
          continue; // 尝试下一个URL
        }
      }
      
      
      if (statusCode == 200 && data != null && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': data?['msg'] ?? '获取分类详情失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取用户档案
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      // 获取当前登录用户的ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '1';
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profile/$userId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': '获取用户档案失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取文章推荐
  Future<Map<String, dynamic>> getRecommendArticles({int? categoryId, int count = 6}) async {
    try {
      String url = '${ApiConfig.baseUrl}/article/recommend?count=$count';
      if (categoryId != null) {
        url += '&category_id=$categoryId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': data['msg'] ?? '获取推荐文章失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取投放记录
  Future<List<dynamic>> getDisposalRecords() async {
    try {
      // 获取当前登录用户的ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '1';
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/record/list/$userId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return data['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // 添加投放记录
  static Future<Map<String, dynamic>> addDisposalRecord(
    String garbageName, 
    int categoryId, {
    String? userId,
    double? weight = 0.0,
    String? locationName = "APP投放",
    bool isCorrect = true,
  }) async {
    try {
      // 如果没有传入userId，尝试从本地存储获取
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id') ?? '1'; // 默认使用用户ID=1，与profile接口一致
      }
      
      final body = {
        'user_id': int.tryParse(userId) ?? 1,
        'category_id': categoryId,
        'garbage_name': garbageName,
        'is_correct': isCorrect,
      };
      
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/record/add'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data, 'point': data['point'] ?? 0};
      } else {
        return {'success': false, 'error': data['msg'] ?? '添加失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 获取收藏列表
  Future<List<dynamic>> getFavorites() async {
    try {
      // 需要用户ID，暂时使用用户ID=1
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/fav/list/1'), // 临时使用用户ID=1
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 添加收藏
  Future<bool> addFavorite(int exampleId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/fav/add'),
        headers: _getHeaders(),
        body: jsonEncode({'example_id': exampleId}),
      );
      
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  // 取消收藏
  Future<bool> removeFavorite(int exampleId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/fav/$exampleId'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  // 添加文章收藏
  Future<bool> addArticleFavorite(int articleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '1';
      
      final requestBody = {
        'user_id': int.tryParse(userId) ?? 1,
        'item_id': articleId,
        'item_type': 'article',
      };
      
      debugPrint('添加文章收藏请求: ${ApiConfig.baseUrl}/fav/add');
      debugPrint('请求体: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/fav/add'),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      );
      
      debugPrint('响应状态码: ${response.statusCode}');
      debugPrint('响应体: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['code'] == 200) {
        debugPrint('收藏成功');
        return true;
      } else {
        debugPrint('收藏失败: ${data['msg']}');
        return false;
      }
    } catch (e) {
      debugPrint('收藏异常: $e');
      return false;
    }
  }

  // 取消文章收藏
  Future<bool> removeArticleFavorite(int articleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '1';
      
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/fav/remove?user_id=$userId&item_id=$articleId&item_type=article'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  // 获取推荐文章
  Future<List<dynamic>> getRecommendedArticles({int? categoryId, int count = 6}) async {
    try {
      String url = '${ApiConfig.baseUrl}/article/recommend?count=$count';
      if (categoryId != null) url += '&category_id=$categoryId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 获取成就类型
  Future<List<dynamic>> getAchievementTypes() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/achievement/types'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 获取用户成就
  Future<List<dynamic>> getUserAchievements() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/achievement/user'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 获取用户统计
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/stats/user'),
        headers: _getHeaders(),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': '获取统计数据失败'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 健康检查
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
        headers: _getHeaders(needAuth: false),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': '服务不可用'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
