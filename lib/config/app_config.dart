/// 应用配置常量
class AppConfig {
  // ====================== 后端API配置 ======================
  static const String apiBaseUrl = "http://101.37.205.98:8000";

  // FastAPI路由
  static const String recognizeEndpoint = "/api/garbage/recognize";
  static const String categoryEndpoint = "/api/category/all";
  static const String quizEndpoint = "/api/quiz/all";
  static const String userEndpoint = "/api/user";

  // 请求超时时间（秒）
  static const int requestTimeout = 30;

  // ====================== 应用配置 ======================
  static const String appName = "绿意分类";
  static const String appVersion = "1.0.0";

  // ====================== 本地存储Key ======================
  static const String keyUserId = "user_id";
  static const String keyUsername = "username";
  static const String keyToken = "token";
  static const String keySearchHistory = "search_history";

  // ====================== 垃圾分类映射 ======================
  static const Map<String, String> garbageCategoryMap = {
    "recyclable": "可回收垃圾",
    "kitchen": "厨余垃圾",
    "harmful": "有害垃圾",
    "other": "其他垃圾",
  };
}
