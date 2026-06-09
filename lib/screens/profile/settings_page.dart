import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../main.dart';
import '../auth/login_page.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("设置"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text("更换用户名"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showChangeUsernameDialog();
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("上传头像"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showUploadAvatarDialog();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeUsernameDialog() {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("更换用户名"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: "新用户名",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "密码",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () async {
              if (usernameController.text.trim().isNotEmpty && passwordController.text.isNotEmpty) {
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final userId = authProvider.userId ?? 1;
                  
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/user/update/username'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'user_id': userId,
                      'new_username': usernameController.text.trim(),
                      'password': passwordController.text.trim(),
                    }),
                  );

                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("用户名修改成功")),
                    );
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.refreshUserInfo();
                    if (mounted) {
                      setState(() {});
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("用户名修改失败")),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("网络错误")),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  void _showUploadAvatarDialog() {
    final TextEditingController passwordController = TextEditingController();
    // Web 只支持相册
    final bool supportsCamera = !kIsWeb;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("上传头像"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kIsWeb)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Web版本仅支持相册上传',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "密码",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text("选择头像来源："),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (supportsCamera) ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImageFromCamera(passwordController.text);
                    },
                    child: const Text("拍照"),
                  ),
                  const SizedBox(width: 16),
                ],
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImageFromGallery(passwordController.text);
                  },
                  child: Text(kIsWeb ? "选择图片" : "相册"),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
        ],
      ),
    );
  }

  void _pickImageFromCamera(String password) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _uploadImage(image, password);
    }
  }

  void _pickImageFromGallery(String password) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _uploadImage(image, password);
    }
  }

  // ========== 关键修改：支持 Web 和 APP 的上传方法 ==========
  void _uploadImage(XFile image, String password) async {
    try {
      // Get current logged-in user ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId ?? 1;
      
      // 使用 ApiConfig.baseUrl
      final uri = Uri.parse('${ApiConfig.baseUrl}/user/upload/avatar?user_id=$userId&password=$password');
      final request = http.MultipartRequest('POST', uri);
      
      if (kIsWeb) {
        // Web 端：使用 fromBytes
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      } else {
        // APP 端：使用 fromPath
        final file = io.File(image.path);
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );
      }
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        // Parse response to get avatar URL
        final responseData = json.decode(responseBody);
        final avatarUrl = responseData['avatar_url'];
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("头像上传成功")),
        );
        
        // Directly update avatar URL in user profile
        if (avatarUrl != null) {
          // 使用 ApiConfig.getImageUrl 获取完整 URL
          authProvider.updateAvatarUrl(ApiConfig.getImageUrl(avatarUrl));
        }
        
        // Don't call refreshUserInfo as it will override the avatar URL
        // The avatar is already updated via updateAvatarUrl
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("头像上传失败: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("上传错误: $e")),
      );
    }
  }
}