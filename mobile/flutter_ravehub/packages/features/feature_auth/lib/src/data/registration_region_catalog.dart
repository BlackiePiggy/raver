import 'dart:convert';

import 'package:flutter/services.dart';

const _catalogAssetPath =
    'packages/feature_auth/assets/registration-region-catalog.json';

/// Registration home-city catalog shared with the native iOS app.
class RegistrationRegionCatalog {
  const RegistrationRegionCatalog({
    required this.version,
    required this.countries,
  });

  final String version;
  final List<RegistrationCountryRegion> countries;

  static const fallback = RegistrationRegionCatalog(
    version: 'fallback',
    countries: [
      RegistrationCountryRegion(
        code: 'CN',
        name: '中国',
        enName: 'China',
        regionLabel: '省/直辖市',
        cityLabel: '城市',
        children: [
          RegistrationAdministrativeRegion(
            code: '310000',
            name: '上海市',
            children: [
              RegistrationAdministrativeArea(code: '310000', name: '上海市'),
            ],
          ),
        ],
      ),
      RegistrationCountryRegion(
        code: 'JP',
        name: '日本',
        enName: 'Japan',
        regionLabel: '都道府县',
        cityLabel: '市区町村',
        children: [
          RegistrationAdministrativeRegion(
            code: '13',
            name: '東京都',
            enName: 'tokyo',
            children: [
              RegistrationAdministrativeArea(code: '13-0012', name: '港区'),
            ],
          ),
        ],
      ),
    ],
  );

  static Future<RegistrationRegionCatalog> load({
    AssetBundle? bundle,
  }) async {
    try {
      final json = await (bundle ?? rootBundle).loadString(_catalogAssetPath);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final catalog = RegistrationRegionCatalog.fromJson(decoded);
      if (catalog.countries.isEmpty) return fallback;
      return catalog;
    } on Object {
      return fallback;
    }
  }

  factory RegistrationRegionCatalog.fromJson(Map<String, dynamic> json) {
    return RegistrationRegionCatalog(
      version: json['version'] as String? ?? 'unknown',
      countries: (json['countries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RegistrationCountryRegion.fromJson)
          .where((country) => country.children.isNotEmpty)
          .toList(growable: false),
    );
  }

  RegistrationCountryRegion country(String code) {
    return countries.firstWhere(
      (country) => country.code == code,
      orElse: () => countries.first,
    );
  }

  RegistrationAdministrativeRegion region({
    required String countryCode,
    required String regionCode,
  }) {
    final selectedCountry = country(countryCode);
    return selectedCountry.children.firstWhere(
      (region) => region.code == regionCode,
      orElse: () => selectedCountry.children.first,
    );
  }

  RegistrationAdministrativeArea city({
    required String countryCode,
    required String regionCode,
    required String cityCode,
  }) {
    final selectedRegion = region(
      countryCode: countryCode,
      regionCode: regionCode,
    );
    return selectedRegion.children.firstWhere(
      (city) => city.code == cityCode,
      orElse: () => selectedRegion.children.first,
    );
  }
}

class RegistrationCountryRegion {
  const RegistrationCountryRegion({
    required this.code,
    required this.name,
    required this.regionLabel,
    required this.cityLabel,
    required this.children,
    this.enName,
  });

  final String code;
  final String name;
  final String? enName;
  final String regionLabel;
  final String cityLabel;
  final List<RegistrationAdministrativeRegion> children;

  factory RegistrationCountryRegion.fromJson(Map<String, dynamic> json) {
    return RegistrationCountryRegion(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enName: json['enName'] as String?,
      regionLabel: json['regionLabel'] as String? ?? '',
      cityLabel: json['cityLabel'] as String? ?? '',
      children: (json['children'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RegistrationAdministrativeRegion.fromJson)
          .where((region) => region.children.isNotEmpty)
          .toList(growable: false),
    );
  }

  String displayName(String languageCode) {
    return languageCode.startsWith('zh') ? name : (enName ?? name);
  }
}

class RegistrationAdministrativeRegion {
  const RegistrationAdministrativeRegion({
    required this.code,
    required this.name,
    required this.children,
    this.enName,
  });

  final String code;
  final String name;
  final String? enName;
  final List<RegistrationAdministrativeArea> children;

  factory RegistrationAdministrativeRegion.fromJson(
    Map<String, dynamic> json,
  ) {
    return RegistrationAdministrativeRegion(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enName: json['enName'] as String?,
      children: (json['children'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RegistrationAdministrativeArea.fromJson)
          .toList(growable: false),
    );
  }

  String displayName(String languageCode) {
    return languageCode.startsWith('en') ? (enName ?? name) : name;
  }
}

class RegistrationAdministrativeArea {
  const RegistrationAdministrativeArea({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  factory RegistrationAdministrativeArea.fromJson(Map<String, dynamic> json) {
    return RegistrationAdministrativeArea(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
