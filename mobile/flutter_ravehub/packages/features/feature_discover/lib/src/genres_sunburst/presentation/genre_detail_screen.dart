import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/genre_api.dart';
import 'genre_theme_palette.dart';

class GenreDetailState {
  const GenreDetailState({this.genre, this.isLoading = false, this.error});

  final LearnGenreNode? genre;
  final bool isLoading;
  final String? error;
}

class GenreDetailNotifier extends StateNotifier<GenreDetailState> {
  GenreDetailNotifier(this._api, this._genreId)
      : super(const GenreDetailState()) {
    _load();
  }

  final GenreApi _api;
  final String _genreId;

  Future<void> _load() async {
    state = const GenreDetailState(isLoading: true);
    try {
      final genre = await _api.fetchGenreDetail(_genreId);
      state = GenreDetailState(genre: genre);
    } catch (e) {
      state = GenreDetailState(error: e.toString());
    }
  }

  Future<void> retry() => _load();
}

final genreDetailProvider = StateNotifierProvider.autoDispose
    .family<GenreDetailNotifier, GenreDetailState, String>(
  (ref, genreId) {
    final api = ref.watch(genreApiProvider);
    return GenreDetailNotifier(api, genreId);
  },
);

class GenreDetailScreen extends ConsumerWidget {
  const GenreDetailScreen({super.key, required this.genreId});

  final String genreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(genreDetailProvider(genreId));

    return Scaffold(
      appBar: AppBar(
        title: Text(state.genre?.name ?? lt('流派详情', 'Genre Detail', 'ジャンル詳細')),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GenreDetailState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null) {
      return ErrorStateView(
        title: lt('加载失败', 'Failed to load', 'ロードに失敗しました'),
        description: state.error,
        onRetry: () => ref.read(genreDetailProvider(genreId).notifier).retry(),
      );
    }

    final genre = state.genre;
    if (genre == null) {
      return EmptyStateView(
        icon: Icons.music_note_outlined,
        title: lt('流派未找到', 'Genre not found', 'ジャンルが見つかりません'),
      );
    }

    final themeColor = LearnGenreThemePalette.colorForGenre(genre.name);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GenreHeader(genre: genre, themeColor: themeColor),
        const SizedBox(height: 24),
        _InfoSection(
          title: lt('简介', 'Description', '説明'),
          content: genre.description,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoChip(
                label: lt('起源', 'Origin', '起源'),
                value: genre.origin,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoChip(
                label: lt('年代', 'Era', '年代'),
                value: genre.era,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoChip(
                label: 'BPM',
                value: genre.bpmRange,
              ),
            ),
          ],
        ),
        if (genre.soundCueTracks != null &&
            genre.soundCueTracks!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            lt('代表曲目', 'Sound Cues', 'サウンドキュー'),
            style: RaverTypography.title(),
          ),
          const SizedBox(height: 12),
          ...genre.soundCueTracks!.map(
            (track) => _SoundCueTrackTile(track: track, themeColor: themeColor),
          ),
        ],
        if (genre.children != null && genre.children!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            lt('子流派', 'Sub-genres', 'サブジャンル'),
            style: RaverTypography.title(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genre.children!
                .map((child) => ActionChip(
                      label: Text(child.name),
                      backgroundColor: LearnGenreThemePalette.colorForGenre(
                        child.name,
                      ).withValues(alpha: 0.15),
                      onPressed: () {},
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _GenreHeader extends StatelessWidget {
  const _GenreHeader({required this.genre, required this.themeColor});
  final LearnGenreNode genre;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  themeColor,
                  LearnGenreThemePalette.lighten(themeColor, 0.2),
                ],
              ),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            genre.name,
            style: RaverTypography.headline(),
            textAlign: TextAlign.center,
          ),
          if (genre.path.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              genre.path.replaceAll('/', ' › '),
              style: RaverTypography.caption(),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: RaverTypography.title()),
        const SizedBox(height: 8),
        Text(content, style: RaverTypography.body()),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 12,
      child: Column(
        children: [
          Text(label, style: RaverTypography.caption()),
          const SizedBox(height: 4),
          Text(
            value,
            style: RaverTypography.label(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SoundCueTrackTile extends StatelessWidget {
  const _SoundCueTrackTile({required this.track, required this.themeColor});
  final LearnGenreSoundCueTrack track;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: themeColor.withValues(alpha: 0.2),
              ),
              child: Icon(Icons.play_arrow_rounded, color: themeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: RaverTypography.label()),
                  Text(track.artist, style: RaverTypography.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
