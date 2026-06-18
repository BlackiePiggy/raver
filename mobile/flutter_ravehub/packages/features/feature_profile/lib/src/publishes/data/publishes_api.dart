import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class PublishesApi {
  PublishesApi(this._dio);

  final Dio _dio;

  /// Fetch content submissions.
  Future<BFFListPage<ContentSubmissionSummary>> fetchSubmissions({
    required int page,
    int limit = 20,
    String? type,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/content-submissions/mine',
      queryParameters: {'page': page, 'limit': limit},
    );
    final pageData = BFFListPage.fromJson(
      _pageObject(response.data),
      (json) => ContentSubmissionSummary.fromJson(
        _normalizeSummary(json! as Map<String, dynamic>),
      ),
    );
    if (type == null || type.isEmpty) return pageData;

    return BFFListPage(
      items: pageData.items
          .where((item) => item.entityType.toLowerCase() == type.toLowerCase())
          .toList(),
      pagination: pageData.pagination,
    );
  }

  /// Fetch submission detail.
  Future<ContentSubmissionDetail> fetchSubmissionDetail({
    required String id,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/content-submissions/mine/$id',
    );
    return ContentSubmissionDetail.fromJson(
      _normalizeDetail(_detailObject(response.data)),
    );
  }
}

Map<String, dynamic> _pageObject(Object? payload) {
  if (payload is Map<String, dynamic>) {
    final data = payload['data'];
    if (data is Map<String, dynamic> && data['items'] is List<dynamic>) {
      return {
        'items': data['items'],
        if (payload['pagination'] != null) 'pagination': payload['pagination'],
      };
    }
    return payload;
  }
  return const {'items': <dynamic>[]};
}

Map<String, dynamic> _detailObject(Object? payload) {
  if (payload is Map<String, dynamic>) {
    final submission = payload['submission'];
    if (submission is Map<String, dynamic>) return submission;
    final data = payload['data'];
    if (data is Map<String, dynamic>) return data;
    return payload;
  }
  return const {};
}

Map<String, dynamic> _normalizeSummary(Map<String, dynamic> json) {
  final payload = json['payload'] is Map<String, dynamic>
      ? json['payload'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final title = _string(
    json['entityName'] ?? json['title'] ?? payload['title'] ?? payload['name'],
  );
  return {
    ...json,
    'entityName': title.isEmpty ? _string(json['entityType']) : title,
    'status': _string(json['status']),
    'statusLabel': _statusLabel(json),
    'createdAt': _string(json['createdAt']),
    'updatedAt': _string(json['updatedAt'] ?? json['createdAt']),
  };
}

Map<String, dynamic> _normalizeDetail(Map<String, dynamic> json) {
  final normalized = _normalizeSummary(json);
  return {
    ...normalized,
    'versions': _normalizeVersions(json['versions']),
    'reviewNote': _reviewNoteText(json),
  };
}

List<dynamic> _normalizeVersions(Object? versions) {
  if (versions is! List<dynamic>) return const <dynamic>[];
  return versions.map((item) {
    if (item is! Map<String, dynamic>) return item;
    return {
      ...item,
      'status': _string(item['status']),
      'statusLabel': _statusLabel(item),
      'createdAt': _string(item['createdAt']),
    };
  }).toList();
}

String _statusLabel(Map<String, dynamic> json) {
  for (final key in const [
    'statusLabel',
    'reviewStatusLabel',
    'moderationLabel',
  ]) {
    final value = _string(json[key]).trim();
    if (value.isNotEmpty) return value;
  }

  for (final key in const ['metadata', 'reviewNotes', 'reviewNote']) {
    final nested = json[key];
    if (nested is Map<String, dynamic>) {
      final value = _string(nested['statusLabel']).trim();
      if (value.isNotEmpty) return value;

      final decision = nested['reviewDecision'];
      if (decision is Map<String, dynamic>) {
        final decisionLabel = _string(decision['statusLabel']).trim();
        if (decisionLabel.isNotEmpty) return decisionLabel;
      }
    }
  }

  return '';
}

String _reviewNoteText(Map<String, dynamic> json) {
  for (final key in const [
    'reviewNote',
    'rejectionReason',
    'rejectionMessage',
    'reviewMessage',
    'message',
    'reason',
  ]) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }

  final notes = json['reviewNotes'];
  if (notes is Map<String, dynamic>) return _reviewNotesText(notes);

  return '';
}

String _reviewNotesText(Map<String, dynamic> notes) {
  for (final key in const ['message', 'reason', 'note', 'statusLabel']) {
    final value = _string(notes[key]).trim();
    if (value.isNotEmpty) return value;
  }

  final decision = notes['reviewDecision'];
  if (decision is Map<String, dynamic>) {
    for (final key in const ['message', 'reason', 'reasonCode']) {
      final value = _string(decision[key]).trim();
      if (value.isNotEmpty) return value;
    }
  }

  final phaseBFailure = notes['phaseBFailure'];
  if (phaseBFailure is Map<String, dynamic>) {
    for (final key in const ['message', 'reason', 'error']) {
      final value = _string(phaseBFailure[key]).trim();
      if (value.isNotEmpty) return value;
    }
  } else {
    final value = _string(phaseBFailure).trim();
    if (value.isNotEmpty) return value;
  }

  final compliance = notes['compliance'];
  if (compliance is Map<String, dynamic>) {
    final rights = compliance['rights'];
    if (rights is Map<String, dynamic> &&
        rights['required'] == true &&
        rights['confirmed'] == false) {
      return '请确认你拥有发布权利，或确认链接来源合法且可公开引用';
    }
  }

  return '';
}

String _string(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}
