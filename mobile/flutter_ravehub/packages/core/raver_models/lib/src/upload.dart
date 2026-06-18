class UploadMediaResponse {
  final String url;
  final String originalUrl;
  final String mediumUrl;
  final String smallUrl;
  final String fileName;
  final String mimeType;
  final int size;
  final int width;
  final int height;

  const UploadMediaResponse({
    required this.url,
    required this.originalUrl,
    required this.mediumUrl,
    required this.smallUrl,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.width,
    required this.height,
  });

  factory UploadMediaResponse.fromJson(Map<String, dynamic> json) =>
      UploadMediaResponse(
        url: _uploadString(json['url']),
        originalUrl: _uploadString(json['originalUrl']),
        mediumUrl: _uploadString(json['mediumUrl']),
        smallUrl: _uploadString(json['smallUrl']),
        fileName: _uploadString(json['fileName']),
        mimeType: _uploadString(json['mimeType']),
        size: _uploadInt(json['size']),
        width: _uploadInt(json['width']),
        height: _uploadInt(json['height']),
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'originalUrl': originalUrl,
        'mediumUrl': mediumUrl,
        'smallUrl': smallUrl,
        'fileName': fileName,
        'mimeType': mimeType,
        'size': size,
        'width': width,
        'height': height,
      };

  UploadMediaResponse copyWith({
    String? url,
    String? originalUrl,
    String? mediumUrl,
    String? smallUrl,
    String? fileName,
    String? mimeType,
    int? size,
    int? width,
    int? height,
  }) =>
      UploadMediaResponse(
        url: url ?? this.url,
        originalUrl: originalUrl ?? this.originalUrl,
        mediumUrl: mediumUrl ?? this.mediumUrl,
        smallUrl: smallUrl ?? this.smallUrl,
        fileName: fileName ?? this.fileName,
        mimeType: mimeType ?? this.mimeType,
        size: size ?? this.size,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadMediaResponse &&
        other.url == url &&
        other.fileName == fileName;
  }

  @override
  int get hashCode => Object.hash(url, fileName);

  @override
  String toString() =>
      'UploadMediaResponse(url: $url, fileName: $fileName, mimeType: $mimeType, size: $size)';
}

String _uploadString(Object? value) => value?.toString() ?? '';

int _uploadInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
