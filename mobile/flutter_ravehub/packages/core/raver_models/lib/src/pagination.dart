class BFFPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const BFFPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory BFFPagination.fromJson(Map<String, dynamic> json) => BFFPagination(
        page: _intFromJson(json['page']),
        limit: _intFromJson(json['limit']),
        total: _intFromJson(json['total']),
        totalPages: _intFromJson(json['totalPages'] ?? json['total_pages']),
      );

  Map<String, dynamic> toJson() => {
        'page': page,
        'limit': limit,
        'total': total,
        'totalPages': totalPages,
      };

  BFFPagination copyWith({
    int? page,
    int? limit,
    int? total,
    int? totalPages,
  }) =>
      BFFPagination(
        page: page ?? this.page,
        limit: limit ?? this.limit,
        total: total ?? this.total,
        totalPages: totalPages ?? this.totalPages,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BFFPagination &&
        other.page == page &&
        other.limit == limit &&
        other.total == total &&
        other.totalPages == totalPages;
  }

  @override
  int get hashCode => Object.hash(page, limit, total, totalPages);

  @override
  String toString() =>
      'BFFPagination(page: $page, limit: $limit, total: $total, totalPages: $totalPages)';
}

int _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class BFFListPage<T> {
  final List<T> items;
  final BFFPagination? pagination;

  const BFFListPage({
    required this.items,
    this.pagination,
  });

  factory BFFListPage.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return BFFListPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => fromJsonT(e))
          .toList(),
      pagination: json['pagination'] != null
          ? BFFPagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T) toJsonT) => {
        'items': items.map((e) => toJsonT(e)).toList(),
        if (pagination != null) 'pagination': pagination!.toJson(),
      };

  BFFListPage<T> copyWith({
    List<T>? items,
    BFFPagination? pagination,
  }) =>
      BFFListPage<T>(
        items: items ?? this.items,
        pagination: pagination ?? this.pagination,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BFFListPage<T> && other.pagination == pagination;
  }

  @override
  int get hashCode => pagination.hashCode;

  @override
  String toString() =>
      'BFFListPage(items: ${items.length} items, pagination: $pagination)';
}
