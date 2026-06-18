import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../data/events_api_service.dart';
import 'view_models/event_upload_view_model.dart';
import '../../_shared/discover_service_locator.dart';

/// EventLineupImportScreen -- AI OCR lineup poster import.
///
/// Flow:
/// 1. Show image picker (camera or gallery)
/// 2. Upload image to POST /v1/events/lineup/import-image
/// 3. Show loading state
/// 4. Display matched DJs as selectable list (CheckboxListTile)
/// 5. Confirm button -> returns selected LineupEntry list to caller
///
/// Widget is a full-screen modal presented by EventUploadFlowScreen step 3.
/// It calls context.pop(selectedEntries) on confirm.
class EventLineupImportScreen extends StatefulWidget {
  /// Creates an [EventLineupImportScreen].
  const EventLineupImportScreen({
    super.key,
    this.eventId,
    this.startDate,
    this.endDate,
  });

  /// The event ID that opened the import flow, if any.
  ///
  /// The current live OCR endpoint is global and does not require this ID; the
  /// field is kept so existing event-detail routes remain source-compatible.
  final String? eventId;

  /// Event-local date bounds used by the live OCR endpoint as context.
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<EventLineupImportScreen> createState() =>
      _EventLineupImportScreenState();
}

class _EventLineupImportScreenState extends State<EventLineupImportScreen> {
  final ImagePicker _picker = ImagePicker();
  final EventsApiService _api = DiscoverServiceLocator.eventsApi;

  /// Current phase of the import flow.
  _ImportPhase _phase = _ImportPhase.pickImage;

  /// The picked image file.
  File? _imageFile;

  /// Matched DJs returned by the OCR endpoint.
  List<LineupImportMatch> _matches = [];

  /// Selection state keyed by index.
  final Set<int> _selectedIndices = {};

  /// Error message, if any.
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Image picking
  // ---------------------------------------------------------------------------

  Future<void> _pickFromGallery() => _pickImage(ImageSource.gallery);
  Future<void> _pickFromCamera() => _pickImage(ImageSource.camera);

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(source: source);
      if (xFile == null) return;

      setState(() {
        _imageFile = File(xFile.path);
        _phase = _ImportPhase.uploading;
        _errorMessage = null;
      });

      await _uploadAndProcess();
    } on Exception catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _phase = _ImportPhase.error;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Upload & OCR processing
  // ---------------------------------------------------------------------------

  Future<void> _uploadAndProcess() async {
    try {
      final matches = await _api.importLineupFromImage(
        imageFile: _imageFile!,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      setState(() {
        _matches = matches;
        // Select all matches with confidence >= 0.5 by default.
        _selectedIndices.clear();
        for (int i = 0; i < matches.length; i++) {
          if (matches[i].confidence >= 0.5) {
            _selectedIndices.add(i);
          }
        }
        _phase =
            matches.isEmpty ? _ImportPhase.emptyResult : _ImportPhase.results;
      });
    } on Exception catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _phase = _ImportPhase.error;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Confirm selection
  // ---------------------------------------------------------------------------

  void _onConfirm() {
    final selected = _selectedIndices.map((i) {
      final match = _matches[i];
      return LineupEntry(
        djId: match.djId ?? '',
        djName: match.djName,
      );
    }).toList();

    context.pop(selected);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(
          lt('AI导入阵容', 'AI Lineup Import', 'AI ラインナップ取込'),
          style: RaverTypography.title(size: 18, color: theme.primaryText),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _ImportPhase.pickImage => _buildPickImageView(theme),
          _ImportPhase.uploading => _buildUploadingView(theme),
          _ImportPhase.results => _buildResultsView(theme),
          _ImportPhase.emptyResult => _buildEmptyResultView(theme),
          _ImportPhase.error => _buildErrorView(theme),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phase views
  // ---------------------------------------------------------------------------

  Widget _buildPickImageView(RaverThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 72,
              color: theme.accent.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              lt(
                '拍摄或选择阵容海报',
                'Take a photo or select a lineup poster',
                'ラインナップポスターを撮影または選択',
              ),
              textAlign: TextAlign.center,
              style: RaverTypography.body(
                size: 16,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lt(
                'AI将自动识别海报中的DJ名称',
                'AI will automatically detect DJ names from the poster',
                'AIがポスターからDJ名を自動検出します',
              ),
              textAlign: TextAlign.center,
              style: RaverTypography.caption(
                size: 13,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              label: lt('从相册选择', 'Choose from Gallery', 'ギャラリーから選択'),
              onPressed: _pickFromGallery,
              isExpanded: true,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: lt('拍照', 'Take Photo', '写真を撮る'),
              variant: PrimaryButtonVariant.outline,
              onPressed: _pickFromCamera,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadingView(RaverThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
          ),
          const SizedBox(height: 24),
          Text(
            lt('正在分析海报...', 'Analyzing poster...', 'ポスターを分析中...'),
            style: RaverTypography.body(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            lt(
              'AI正在识别DJ名称，请稍候',
              'AI is detecting DJ names, please wait',
              'AIがDJ名を検出中です。お待ちください',
            ),
            style: RaverTypography.caption(
              size: 13,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(RaverThemeData theme) {
    return Column(
      children: [
        // Header with count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                lt(
                  '识别到 ${_matches.length} 位DJ',
                  '${_matches.length} DJs detected',
                  '${_matches.length} 人のDJを検出',
                ),
                style:
                    RaverTypography.title(size: 16, color: theme.primaryText),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == _matches.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices.clear();
                      for (int i = 0; i < _matches.length; i++) {
                        _selectedIndices.add(i);
                      }
                    }
                  });
                },
                child: Text(
                  _selectedIndices.length == _matches.length
                      ? lt('取消全选', 'Deselect All', '全選択解除')
                      : lt('全选', 'Select All', '全選択'),
                  style: RaverTypography.label(size: 14, color: theme.accent),
                ),
              ),
            ],
          ),
        ),

        // Match list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              final isSelected = _selectedIndices.contains(index);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIndices.add(index);
                        } else {
                          _selectedIndices.remove(index);
                        }
                      });
                    },
                    activeColor: theme.accent,
                    title: Text(
                      match.djName,
                      style: RaverTypography.label(
                        size: 15,
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        _ConfidenceBadge(
                          confidence: match.confidence,
                          accent: theme.accent,
                        ),
                        if (match.djId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: theme.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lt('已匹配', 'Matched', 'マッチ済'),
                            style: RaverTypography.caption(
                              size: 12,
                              color: theme.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    secondary: match.avatarUrl != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(match.avatarUrl!),
                            radius: 20,
                          )
                        : CircleAvatar(
                            backgroundColor:
                                theme.accent.withValues(alpha: 0.15),
                            radius: 20,
                            child: Text(
                              match.djName.isNotEmpty
                                  ? match.djName[0].toUpperCase()
                                  : '?',
                              style: RaverTypography.label(
                                size: 16,
                                color: theme.accent,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),

        // Confirm button
        Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: lt(
              '导入已选 (${_selectedIndices.length})',
              'Import Selected (${_selectedIndices.length})',
              '選択した項目をインポート (${_selectedIndices.length})',
            ),
            onPressed: _selectedIndices.isNotEmpty ? _onConfirm : null,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyResultView(RaverThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateView(
              icon: Icons.search_off,
              title: lt('未识别到DJ', 'No DJs Detected', 'DJが検出されませんでした'),
              subtitle: lt(
                '请尝试使用更清晰的海报图片',
                'Try using a clearer poster image',
                'より鮮明なポスター画像をお試しください',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: lt('重新选择图片', 'Choose Another Image', '別の画像を選択'),
              onPressed: () => setState(() => _phase = _ImportPhase.pickImage),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(RaverThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorStateView(
              title: lt('识别失败', 'Import Failed', 'インポートに失敗しました'),
              error: _errorMessage ?? 'Unknown error',
              onRetry: () {
                if (_imageFile != null) {
                  setState(() {
                    _phase = _ImportPhase.uploading;
                    _errorMessage = null;
                  });
                  _uploadAndProcess();
                } else {
                  setState(() => _phase = _ImportPhase.pickImage);
                }
              },
              retryLabel: lt('重试', 'Retry', '再試行'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _phase = _ImportPhase.pickImage),
              child: Text(
                lt('重新选择图片', 'Choose Another Image', '別の画像を選択'),
                style: RaverTypography.label(
                  size: 14,
                  color: theme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Import flow phases
// ---------------------------------------------------------------------------

enum _ImportPhase {
  /// Waiting for user to pick an image.
  pickImage,

  /// Image is being uploaded and processed.
  uploading,

  /// OCR results are ready and displayed.
  results,

  /// OCR returned no matches.
  emptyResult,

  /// An error occurred.
  error,
}

// ---------------------------------------------------------------------------
// Confidence badge widget
// ---------------------------------------------------------------------------

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({
    required this.confidence,
    required this.accent,
  });

  final double confidence;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final percentage = (confidence * 100).round();

    final Color badgeColor;
    if (confidence >= 0.8) {
      badgeColor = const Color(0xFF2ECC71); // green
    } else if (confidence >= 0.5) {
      badgeColor = const Color(0xFFF39C12); // orange
    } else {
      badgeColor = const Color(0xFFE74C3C); // red
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}
