import 'package:flutter/material.dart';

import '../../media_library/data/demo_media_library_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.mediaLibraryRepository,
    required this.initialDirectoryPath,
  });

  final DemoMediaLibraryRepository mediaLibraryRepository;
  final String? initialDirectoryPath;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String? _currentDirectoryPath = widget.initialDirectoryPath;
  String? _errorMessage;
  bool _isPickingDirectory = false;

  Future<void> _pickDirectory() async {
    if (_isPickingDirectory) {
      return;
    }

    setState(() {
      _isPickingDirectory = true;
      _errorMessage = null;
    });

    try {
      final String? directory = await widget.mediaLibraryRepository
          .pickDirectory(initialDirectory: _currentDirectoryPath);
      if (!mounted || directory == null) {
        return;
      }

      final bool hasAccess = await widget.mediaLibraryRepository
          .ensureDirectoryAccess(directory);
      if (!mounted) {
        return;
      }
      if (!hasAccess) {
        setState(() {
          _errorMessage = '系统没有保留这个目录的读取授权，请重新选择目录。';
        });
        return;
      }

      setState(() {
        _currentDirectoryPath = directory;
      });
      Navigator.of(context).pop(directory);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '系统目录选择器没有成功启动：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingDirectory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      appBar: AppBar(
        title: const Text('媒体库设置'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                const Text(
                  '配置扫描目录后，后续点歌页会基于这个目录建立扫描范围。取消目录选择后会回到这个设置页。',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '扫描目录',
                        style: TextStyle(
                          color: Color(0xFF1D1230),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _currentDirectoryPath ?? '当前还没有配置扫描目录。',
                        style: const TextStyle(
                          color: Color(0xFF6B5D7C),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isPickingDirectory ? null : _pickDirectory,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6E67),
                  ),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(_isPickingDirectory ? '选择中' : '选择目录'),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF9C2F2F),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
