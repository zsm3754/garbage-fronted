import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import '../../services/api_service.dart';
import '../detail/category_detail_page.dart';
import '../../config/api_config.dart';

class CameraRecognitionPage extends StatefulWidget {
  const CameraRecognitionPage({super.key});

  @override
  State<CameraRecognitionPage> createState() => _CameraRecognitionPageState();
}

class _CameraRecognitionPageState extends State<CameraRecognitionPage> {
  dynamic _selectedImage; // Web用XFile，APP用File
  List<dynamic> _recognitionResults = [];
  bool _isRecognizing = false;

  // 检查是否支持相机 - Web平台只支持相册，APP支持相机和相册
  bool get _supportsCamera => !kIsWeb;

  @override
  void initState() {
    super.initState();
    print('=== 拍照识别页面初始化 ===');
    print('当前页面: CameraRecognitionPage');
    // 修复：使用 kIsWeb 替代 Platform.operatingSystem
    print('平台: ${kIsWeb ? "Web" : "Mobile"}');
    print('支持相机: $_supportsCamera');
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      
      if (kDebugMode) {
        print('=== 开始选择图片 ===');
        print('图片来源: ${source == ImageSource.camera ? "相机" : "相册"}');
      }
      
      // Web 端只能用相册，如果请求相机则提示
      if (kIsWeb && source == ImageSource.camera) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Web版本不支持相机，请使用相册选择图片")),
          );
        }
        return;
      }
      
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        if (kDebugMode) {
          print('图片选择成功');
        }
        
        setState(() {
          // Web平台直接使用XFile，APP平台转换为File
          if (kIsWeb) {
            _selectedImage = pickedFile;
          } else {
            _selectedImage = io.File(pickedFile.path);
          }
          _recognitionResults = [];
        });
        _recognizeGarbage();
      } else {
        if (kDebugMode) {
          print('用户取消了图片选择');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('图片选择失败: $e');
        print('错误类型: ${e.runtimeType}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("图片选择失败: $e")),
        );
      }
    }
  }

  Future<void> _recognizeGarbage() async {
    if (_selectedImage == null) return;

    setState(() => _isRecognizing = true);

    try {
      print('=== 开始拍照识别 ===');
      
      final apiService = ApiService();
      final result = await apiService.recognizeGarbage(_selectedImage!);

      print('识别结果: $result');

      if (result['success']) {
        setState(() {
          _recognitionResults = result['data'] as List;
        });
        print('识别成功，结果数量: ${_recognitionResults.length}');
      } else {
        print('识别失败: ${result['error']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("识别失败: ${result['error'] ?? '未知错误'}")),
          );
        }
      }
    } catch (e) {
      print('识别异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("识别错误: $e")),
        );
      }
    } finally {
      setState(() => _isRecognizing = false);
      print('=== 拍照识别结束 ===');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI拍照识别'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片选择区域
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(child: Text('图片加载失败'));
                              },
                            )
                          : Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            '请选择或拍摄垃圾图片',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // 平台提示
            if (kIsWeb)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Web版本仅支持相册上传，请使用相册选择图片',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 按钮组
            Row(
              children: [
                // 相机按钮 - 只在APP平台显示
                if (_supportsCamera) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRecognizing ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 相册按钮 - 所有平台都显示
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRecognizing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(kIsWeb ? '选择图片' : '相册'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 识别结果
            if (_isRecognizing)
              const Center(child: CircularProgressIndicator())
            else if (_recognitionResults.isNotEmpty)
              _buildResults()
            else if (_selectedImage != null)
              const Center(
                child: Text('暂无识别结果', style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '识别结果',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._recognitionResults.map((result) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: const Icon(Icons.recycling, color: Colors.green),
              ),
              title: Text(result['item'] ?? '未知'),
              subtitle: Text('置信度: ${((result['confidence'] ?? 0) * 100).toStringAsFixed(1)}%'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                final categoryName = result['item'] as String;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryDetailPage(categoryName: categoryName),
                  ),
                );
              },
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        const Text(
          '💡 点击识别结果查看详细分类信息',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}