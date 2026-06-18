import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import 'view_models/squad_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Squad management screen (only accessible by squad owner).
class SquadManageScreen extends StatefulWidget {
  const SquadManageScreen({super.key, required this.squadId});

  final String squadId;

  @override
  State<SquadManageScreen> createState() => _SquadManageScreenState();
}

class _SquadManageScreenState extends State<SquadManageScreen> {
  late final SquadProfileViewModel _viewModel;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = SquadProfileViewModel(
      squadId: widget.squadId,
      repository: CircleServiceLocator.squadRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    // Sync text controllers when squad loads
    if (_viewModel.squad != null && _nameController.text.isEmpty) {
      _nameController.text = _viewModel.squad!.name;
      _descController.text = _viewModel.squad!.description;
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _nameController.dispose();
    _descController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    await _viewModel.updateSquad(
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('已保存', 'Saved', '保存しました')),
        ),
      );
    }
  }

  Future<void> _confirmDisband() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lt('解散小队', 'Disband Squad', 'スクワッドを解散')),
        content: Text(lt(
          '确定要解散这个小队吗？此操作无法撤销。',
          'Are you sure you want to disband this squad? This cannot be undone.',
          'このスクワッドを解散しますか？この操作は取り消せません。',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lt('解散', 'Disband', '解散')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _viewModel.deleteSquad();
      if (mounted) {
        context.pop();
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('管理小队', 'Manage Squad', 'スクワッド管理'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: Text(
              lt('保存', 'Save', '保存'),
              style: RaverTypography.label(
                size: 15,
                color: theme.accent,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: LoadPhaseBuilder(
        phase: _viewModel.phase,
        onLoading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => _buildForm(theme),
      ),
    );
  }

  Widget _buildForm(RaverThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            lt('小队名称', 'Squad Name', 'スクワッド名'),
            style: RaverTypography.label(
              size: 14,
              color: theme.primaryText,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.cardBorder),
              ),
            ),
            style: RaverTypography.body(size: 15, color: theme.primaryText),
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            lt('简介', 'Description', '説明'),
            style: RaverTypography.label(
              size: 14,
              color: theme.primaryText,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.cardBorder),
              ),
            ),
            style: RaverTypography.body(size: 15, color: theme.primaryText),
          ),

          const SizedBox(height: 24),

          // Members list
          Text(
            lt('成员管理', 'Members', 'メンバー管理'),
            style: RaverTypography.label(
              size: 14,
              color: theme.primaryText,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._viewModel.members.map(
            (member) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.cardBorder,
                    backgroundImage: member.avatarUrl.isNotEmpty
                        ? NetworkImage(member.avatarUrl)
                        : null,
                    child: member.avatarUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 18,
                            color: theme.secondaryText,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: RaverTypography.label(
                            size: 14,
                            color: theme.primaryText,
                          ),
                        ),
                        Text(
                          member.role,
                          style: RaverTypography.caption(
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (member.role != 'owner')
                    GestureDetector(
                      onTap: () => _viewModel.kickMember(member.userId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lt('移除', 'Remove', '削除'),
                          style: RaverTypography.caption(
                            size: 12,
                            color: Colors.red,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Disband button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmDisband,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                lt('解散小队', 'Disband Squad', 'スクワッドを解散'),
                style: RaverTypography.label(
                  size: 15,
                  color: Colors.red,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
