enum AccountEnforcementScope {
  login,
  postCreate,
  commentCreate,
  eventCreate,
  djCreate,
  setCreate,
  squadCreate,
  checkinCreate,
  ratingCreate,
  locationShare;

  static final _snakeCaseMap = <String, AccountEnforcementScope>{
    'login': login,
    'post_create': postCreate,
    'comment_create': commentCreate,
    'event_create': eventCreate,
    'dj_create': djCreate,
    'set_create': setCreate,
    'squad_create': squadCreate,
    'checkin_create': checkinCreate,
    'rating_create': ratingCreate,
    'location_share': locationShare,
  };

  static final _toSnakeCase = <AccountEnforcementScope, String>{
    for (final entry in _snakeCaseMap.entries) entry.value: entry.key,
  };

  static AccountEnforcementScope fromJson(String v) =>
      _snakeCaseMap[v] ?? AccountEnforcementScope.login;

  String toJson() => _toSnakeCase[this] ?? name;
}

enum AccountEnforcementType {
  warning,
  restriction,
  suspension,
  ban;

  static final _snakeCaseMap = <String, AccountEnforcementType>{
    'warning': warning,
    'restriction': restriction,
    'suspension': suspension,
    'ban': ban,
  };

  static final _toSnakeCase = <AccountEnforcementType, String>{
    for (final entry in _snakeCaseMap.entries) entry.value: entry.key,
  };

  static AccountEnforcementType fromJson(String v) =>
      _snakeCaseMap[v] ?? AccountEnforcementType.warning;

  String toJson() => _toSnakeCase[this] ?? name;
}

class AccountEnforcementStatus {
  final List<AccountEnforcementRestriction> restrictions;
  final bool isRestricted;

  const AccountEnforcementStatus({
    required this.restrictions,
    required this.isRestricted,
  });

  factory AccountEnforcementStatus.fromJson(Map<String, dynamic> json) =>
      AccountEnforcementStatus(
        restrictions: (json['restrictions'] as List<dynamic>? ?? [])
            .map((e) => AccountEnforcementRestriction.fromJson(
                e as Map<String, dynamic>))
            .toList(),
        isRestricted: json['isRestricted'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'restrictions': restrictions.map((e) => e.toJson()).toList(),
        'isRestricted': isRestricted,
      };

  AccountEnforcementStatus copyWith({
    List<AccountEnforcementRestriction>? restrictions,
    bool? isRestricted,
  }) =>
      AccountEnforcementStatus(
        restrictions: restrictions ?? this.restrictions,
        isRestricted: isRestricted ?? this.isRestricted,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountEnforcementStatus &&
        other.isRestricted == isRestricted;
  }

  @override
  int get hashCode => isRestricted.hashCode;

  @override
  String toString() =>
      'AccountEnforcementStatus(isRestricted: $isRestricted, restrictions: ${restrictions.length})';
}

class AccountEnforcementRestriction {
  final String scope;
  final String type;
  final String reason;
  final String? expiresAt;

  const AccountEnforcementRestriction({
    required this.scope,
    required this.type,
    required this.reason,
    this.expiresAt,
  });

  factory AccountEnforcementRestriction.fromJson(
    Map<String, dynamic> json,
  ) =>
      AccountEnforcementRestriction(
        scope: json['scope'] as String,
        type: json['type'] as String,
        reason: json['reason'] as String,
        expiresAt: json['expiresAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'type': type,
        'reason': reason,
        if (expiresAt != null) 'expiresAt': expiresAt,
      };

  AccountEnforcementRestriction copyWith({
    String? scope,
    String? type,
    String? reason,
    String? expiresAt,
  }) =>
      AccountEnforcementRestriction(
        scope: scope ?? this.scope,
        type: type ?? this.type,
        reason: reason ?? this.reason,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountEnforcementRestriction &&
        other.scope == scope &&
        other.type == type &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(scope, type, reason);

  @override
  String toString() =>
      'AccountEnforcementRestriction(scope: $scope, type: $type, reason: $reason)';
}
