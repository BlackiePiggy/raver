import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/circle_id_api.dart';

class CircleIdComposerSheet extends StatefulWidget {
  const CircleIdComposerSheet({
    super.key,
    required this.onSubmit,
    required this.onSearchEvents,
    required this.onSearchDjs,
  });

  final Future<void> Function(CircleIdCreationDraft draft) onSubmit;
  final Future<List<WebEvent>> Function(String search) onSearchEvents;
  final Future<List<WebDJ>> Function(String search) onSearchDjs;

  @override
  State<CircleIdComposerSheet> createState() => _CircleIdComposerSheetState();
}

class _CircleIdComposerSheetState extends State<CircleIdComposerSheet> {
  final _songNameController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _videoUrlController = TextEditingController();
  WebEvent? _selectedEvent;
  final List<WebDJ> _selectedDjs = [];
  bool _rightsConfirmed = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit => !_isSubmitting;

  @override
  void dispose() {
    _songNameController.dispose();
    _audioUrlController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickEvent() async {
    final event = await showModalBottomSheet<WebEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CircleIdEventPickerSheet(onSearch: widget.onSearchEvents),
    );
    if (event != null) {
      setState(() => _selectedEvent = event);
    }
  }

  Future<void> _pickDjs() async {
    final djs = await showModalBottomSheet<List<WebDJ>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CircleIdDjPickerSheet(
        initialSelection: _selectedDjs,
        onSearch: widget.onSearchDjs,
      ),
    );
    if (djs != null) {
      setState(() {
        _selectedDjs
          ..clear()
          ..addAll(djs);
      });
    }
  }

  Future<void> _submit() async {
    final songName = _songNameController.text.trim();
    final audioUrl = _audioUrlController.text.trim();
    final videoUrl = _videoUrlController.text.trim();
    final event = _selectedEvent;

    String? message;
    if (songName.isEmpty) {
      message = lt('请填写歌曲名', 'Please enter the song name', '曲名を入力してください');
    } else if (event == null) {
      message = lt('请先选择活动', 'Please select an event', '先にイベントを選択してください');
    } else if (_selectedDjs.isEmpty) {
      message = lt(
        '请至少选择一位 DJ',
        'Please select at least one DJ',
        'DJを少なくとも1人選択してください',
      );
    } else if (audioUrl.isEmpty && videoUrl.isEmpty) {
      message = lt(
        '请至少填写音频或视频链接',
        'Please provide at least one audio or video URL',
        '音声または動画URLを少なくとも1つ入力してください',
      );
    } else if (!_rightsConfirmed) {
      message = lt(
        '请先确认你拥有发布权利，或链接来源合法且可公开引用。',
        'Please confirm you have posting rights, or that the link source is lawful and publicly referenceable.',
        '投稿権利がある、またはリンク元が合法で公開参照可能であることを確認してください。',
      );
    }
    if (message != null) {
      setState(() => _errorMessage = message);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    await widget.onSubmit(
      CircleIdCreationDraft(
        songName: songName,
        audioUrl: audioUrl,
        videoUrl: videoUrl,
        event: event!,
        djs: List.unmodifiable(_selectedDjs),
        rightsConfirmed: _rightsConfirmed,
      ),
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                lt('发布 ID', 'Post ID', 'IDを投稿'),
                style: RaverTypography.title(
                  size: 20,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: lt('歌曲名', 'Song Name', '曲名'),
                controller: _songNameController,
                hintText: lt(
                  '例如：ID - Intro Edit',
                  'e.g. ID - Intro Edit',
                  '例: ID - Intro Edit',
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: lt('音频链接（可选）', 'Audio URL (optional)', '音声URL（任意）'),
                controller: _audioUrlController,
                hintText: 'https://',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: lt('视频链接（可选）', 'Video URL (optional)', '動画URL（任意）'),
                controller: _videoUrlController,
                hintText: 'https://',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),
              _SectionHeader(
                title: lt('关联活动', 'Linked Event', '関連イベント'),
                actionLabel: _selectedEvent == null
                    ? lt('选择活动', 'Select Event', 'イベントを選択')
                    : lt('更换活动', 'Change Event', 'イベントを変更'),
                onAction: _pickEvent,
              ),
              const SizedBox(height: 8),
              if (_selectedEvent == null)
                _HintBox(
                  icon: Icons.event_outlined,
                  text: lt('尚未选择活动', 'No event selected', 'イベントが選択されていません'),
                )
              else
                _SelectedEventTile(
                  event: _selectedEvent!,
                  onRemove: () => setState(() => _selectedEvent = null),
                ),
              const SizedBox(height: 14),
              _SectionHeader(
                title: lt(
                  '关联 DJ（可多选）',
                  'Linked DJs (multi-select)',
                  '関連DJ（複数選択可）',
                ),
                actionLabel: lt('选择 DJ', 'Select DJs', 'DJを選択'),
                onAction: _pickDjs,
              ),
              const SizedBox(height: 8),
              if (_selectedDjs.isEmpty)
                _HintBox(
                  icon: Icons.person_search_outlined,
                  text: lt('尚未选择 DJ', 'No DJ selected', 'DJが選択されていません'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedDjs.map((dj) {
                    return _SelectedDjChip(
                      dj: dj,
                      onRemove: () {
                        setState(() {
                          _selectedDjs.removeWhere((item) => item.id == dj.id);
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _rightsConfirmed,
                onChanged: (value) => setState(() => _rightsConfirmed = value),
                title: Text(
                  lt(
                    '我确认拥有发布该音乐/视频链接的权利，或确认链接来源合法且可公开引用。',
                    'I confirm I have the right to post this music/video link, or that the link source is lawful and publicly referenceable.',
                    'この音楽/動画リンクを投稿する権利がある、またはリンク元が合法で公開参照可能であることを確認します。',
                  ),
                  style: RaverTypography.caption(
                    size: 12,
                    color: theme.secondaryText,
                  ),
                ),
                activeThumbColor: theme.accent,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: RaverTypography.caption(
                    color: Colors.redAccent,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    disabledBackgroundColor: theme.accent.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          lt('发布', 'Post', '投稿'),
                          style: RaverTypography.label(
                            size: 16,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RaverTypography.label(
            size: 13,
            color: theme.secondaryText,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: RaverTypography.body(
              size: 15,
              color: theme.secondaryText,
            ),
            filled: true,
            fillColor: theme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: RaverTypography.body(size: 15, color: theme.primaryText),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: RaverTypography.label(
              size: 13,
              color: theme.secondaryText,
              weight: FontWeight.w700,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: onAction,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: theme.cardBorder),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedEventTile extends StatelessWidget {
  const _SelectedEventTile({required this.event, required this.onRemove});

  final WebEvent event;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _NetworkThumb(url: event.coverImageUrl, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: RaverTypography.label(
                    size: 14,
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _compactDate(event.startDate),
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.cancel),
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}

class _SelectedDjChip extends StatelessWidget {
  const _SelectedDjChip({required this.dj, required this.onRemove});

  final WebDJ dj;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NetworkThumb(url: dj.avatarUrl, size: 22, circle: true),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              dj.name,
              style: RaverTypography.caption(
                color: theme.primaryText,
                weight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _CircleIdEventPickerSheet extends StatefulWidget {
  const _CircleIdEventPickerSheet({required this.onSearch});

  final Future<List<WebEvent>> Function(String search) onSearch;

  @override
  State<_CircleIdEventPickerSheet> createState() =>
      _CircleIdEventPickerSheetState();
}

class _CircleIdEventPickerSheetState extends State<_CircleIdEventPickerSheet> {
  final _searchController = TextEditingController();
  List<WebEvent> _events = [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.onSearch(_searchController.text);
      if (!mounted) return;
      setState(() => _events = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return _PickerShell(
      title: lt('选择活动', 'Select Event', 'イベントを選択'),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            hintText: lt(
              '搜索活动名/城市/国家',
              'Search event/city/country',
              'イベント名/都市/国を検索',
            ),
            onSearch: _load,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _error != null
                    ? ErrorStateView(
                        title: lt(
                          '活动加载失败',
                          'Events Failed to Load',
                          'イベントの読み込みに失敗しました',
                        ),
                        error: _error,
                        onRetry: _load,
                        retryLabel: lt('重试', 'Retry', '再試行'),
                      )
                    : _events.isEmpty
                        ? EmptyStateView(
                            icon: Icons.event_busy_outlined,
                            title: lt('没有匹配活动', 'No Matching Events',
                                '一致するイベントがありません'),
                          )
                        : ListView.separated(
                            itemCount: _events.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: theme.cardBorder),
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              return ListTile(
                                leading: _NetworkThumb(
                                  url: event.coverImageUrl,
                                  size: 42,
                                ),
                                title: Text(
                                  event.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_compactDate(event.startDate)),
                                onTap: () => Navigator.of(context).pop(event),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _CircleIdDjPickerSheet extends StatefulWidget {
  const _CircleIdDjPickerSheet({
    required this.initialSelection,
    required this.onSearch,
  });

  final List<WebDJ> initialSelection;
  final Future<List<WebDJ>> Function(String search) onSearch;

  @override
  State<_CircleIdDjPickerSheet> createState() => _CircleIdDjPickerSheetState();
}

class _CircleIdDjPickerSheetState extends State<_CircleIdDjPickerSheet> {
  final _searchController = TextEditingController();
  final Map<String, WebDJ> _selected = {};
  List<WebDJ> _djs = [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    for (final dj in widget.initialSelection) {
      _selected[dj.id] = dj;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.onSearch(_searchController.text);
      if (!mounted) return;
      setState(() => _djs = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggle(WebDJ dj) {
    setState(() {
      if (_selected.containsKey(dj.id)) {
        _selected.remove(dj.id);
      } else {
        _selected[dj.id] = dj;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return _PickerShell(
      title: lt('选择 DJ', 'Select DJs', 'DJを選択'),
      trailing: TextButton(
        onPressed: () => Navigator.of(context).pop(
          _selected.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
        ),
        child: Text(lt('完成', 'Done', '完了')),
      ),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            hintText: lt(
              '搜索 DJ 名称或别名',
              'Search DJ name or alias',
              'DJ名または別名を検索',
            ),
            onSearch: _load,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _error != null
                    ? ErrorStateView(
                        title: lt(
                          'DJ 加载失败',
                          'DJs Failed to Load',
                          'DJの読み込みに失敗しました',
                        ),
                        error: _error,
                        onRetry: _load,
                        retryLabel: lt('重试', 'Retry', '再試行'),
                      )
                    : _djs.isEmpty
                        ? EmptyStateView(
                            icon: Icons.person_search_outlined,
                            title: lt(
                                '没有匹配 DJ', 'No Matching DJs', '一致するDJがありません'),
                          )
                        : ListView.separated(
                            itemCount: _djs.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: theme.cardBorder),
                            itemBuilder: (context, index) {
                              final dj = _djs[index];
                              final selected = _selected.containsKey(dj.id);
                              return ListTile(
                                leading: _NetworkThumb(
                                  url: dj.avatarUrl,
                                  size: 36,
                                  circle: true,
                                ),
                                title: Text(dj.name),
                                subtitle:
                                    dj.aliases == null || dj.aliases!.isEmpty
                                        ? null
                                        : Text(dj.aliases!.take(2).join(' · ')),
                                trailing: Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? theme.accent
                                      : theme.secondaryText,
                                ),
                                onTap: () => _toggle(dj),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: RaverTypography.title(
                        size: 18,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hintText,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        onSubmitted: (_) => onSearch(),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.arrow_forward),
          ),
          filled: true,
          fillColor: theme.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  const _NetworkThumb({
    required this.url,
    required this.size,
    this.circle = false,
  });

  final String url;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(10),
      ),
      child: Icon(
        circle ? Icons.person : Icons.music_note,
        size: size * 0.45,
        color: theme.secondaryText,
      ),
    );
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius:
          circle ? BorderRadius.circular(size / 2) : BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

String _compactDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}
