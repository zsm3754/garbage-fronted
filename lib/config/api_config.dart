import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Web 使用相对路径（让 Nginx 代理）
  // APP 使用完整 URL（直接访问后端）
  static String get baseUrl {
    if (kIsWeb) {
      return '/api';
    } else {
      // 你的服务器公网 IP 和端口
      return 'http://101.37.205.98:8000/api';
    }
  }
  
  // 获取完整图片 URL
static String getImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  
  // 提取文件名（去掉可能的路径前缀）
  final fileName = path.contains('/') ? path.split('/').last : path;
  
  // 统一返回完整 URL
  return 'http://101.37.205.98/avatars/$fileName';
}
}
