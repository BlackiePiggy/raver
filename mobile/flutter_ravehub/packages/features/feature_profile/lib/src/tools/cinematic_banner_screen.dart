import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Cinematic banner generation screen.
class CinematicBannerScreen extends StatefulWidget {
  const CinematicBannerScreen({super.key});

  @override
  State<CinematicBannerScreen> createState() => _CinematicBannerScreenState();
}

class _CinematicBannerScreenState extends State<CinematicBannerScreen> {
  int _selectedTemplate = 0;
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();

  static const _templateColors = [
    [Color(0xFF1a1a2e), Color(0xFF16213e)],
    [Color(0xFF0f3460), Color(0xFF533483)],
    [Color(0xFF2d132c), Color(0xFFee4540)],
    [Color(0xFF1b1b2f), Color(0xFF162447)],
  ];

  static const _templateNames = [
    'Midnight',
    'Neon Night',
    'Sunset Rave',
    'Deep Blue',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('电影风格横幅', 'Cinematic Banner', 'シネマティックバナー')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template selection
            Text(
              lt('选择模板', 'Choose Template', 'テンプレートを選択'),
              style: RaverTypography.label(
                size: 14,
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _templateColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final isSelected = _selectedTemplate == index;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedTemplate = index),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _templateColors[index],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? theme.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _templateNames[index],
                          style: RaverTypography.caption(
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Text inputs
            Text(
              lt('主标题', 'Title', 'メインタイトル'),
              style: RaverTypography.label(
                size: 14,
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt('输入主标题', 'Enter title', 'タイトルを入力'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              lt('副标题', 'Subtitle', 'サブタイトル'),
              style: RaverTypography.label(
                size: 14,
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subtitleController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    lt('输入副标题', 'Enter subtitle', 'サブタイトルを入力'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preview
            Text(
              lt('预览', 'Preview', 'プレビュー'),
              style: RaverTypography.label(
                size: 14,
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _templateColors[_selectedTemplate],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  // Film grain overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                  // Cinematic bars
                  Column(
                    children: [
                      Container(height: 16, color: Colors.black),
                      const Spacer(),
                      Container(height: 16, color: Colors.black),
                    ],
                  ),
                  // Text
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _titleController.text.isNotEmpty
                              ? _titleController.text
                              : lt('主标题', 'Title', 'タイトル'),
                          style: RaverTypography.headline(
                            color: Colors.white,
                          ).copyWith(
                            fontSize: 24,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_subtitleController.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _subtitleController.text,
                            style: RaverTypography.body(
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Generate & save
            PrimaryButton(
              label: lt('生成并保存', 'Generate & Save', '生成して保存'),
              icon: Icons.save_alt,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lt('已保存到相册', 'Saved to gallery',
                        'ギャラリーに保存しました')),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
