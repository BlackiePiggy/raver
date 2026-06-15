import 'package:dio/dio.dart';

/// Response model for media upload operations.
class UploadMediaResponse {
  /// Creates an [UploadMediaResponse].
  const UploadMediaResponse({
    required this.url,
    this.originalUrl,
    this.mediumUrl,
    this.smallUrl,
    this.fileName,
    this.mimeType,
    this.size,
    this.width,
    this.height,
  });

  /// Parses an [UploadMediaResponse] from a JSON map returned by the upload API.
  factory UploadMediaResponse.fromJson(Map<String, dynamic> json) {
    return UploadMediaResponse(
      url: json['url'] as String,
      originalUrl: json['originalUrl'] as String?,
      mediumUrl: json['mediumUrl'] as String?,
      smallUrl: json['smallUrl'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      size: json['size'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  /// The primary URL of the uploaded media.
  final String url;

  /// The URL of the original (full-size) variant, if available.
  final String? originalUrl;

  /// The URL of the medium-size variant, if available.
  final String? mediumUrl;

  /// The URL of the small-size variant, if available.
  final String? smallUrl;

  /// The server-assigned file name, if available.
  final String? fileName;

  /// The MIME type of the uploaded file (e.g. `"image/jpeg"`).
  final String? mimeType;

  /// The file size in bytes, if available.
  final int? size;

  /// The image/video width in pixels, if available.
  final int? width;

  /// The image/video height in pixels, if available.
  final int? height;

  @override
  String toString() => 'UploadMediaResponse(url: $url, fileName: $fileName)';
}

/// Service for uploading media files to the RaveHub backend via multipart
/// form-data requests.
///
/// Uses the same [Dio] instance as the rest of the app, so all interceptors
/// (auth, BFF envelope, etc.) apply automatically.
class MultipartUploadService {
  /// Creates a [MultipartUploadService].
  MultipartUploadService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Uploads a single image file.
  ///
  /// Parameters:
  ///  * [path] -- the API endpoint path (e.g. `/v1/media/upload/image`).
  ///  * [filePath] -- the absolute path to the image file on disk.
  ///  * [fieldName] -- the form field name expected by the server (e.g. `"file"`).
  ///  * [extraFields] -- optional additional form fields to include.
  Future<UploadMediaResponse> uploadImage({
    required String path,
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? extraFields,
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(
        filePath,
        filename: _fileNameFromPath(filePath),
      ),
      if (extraFields != null) ...extraFields,
    });

    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return UploadMediaResponse.fromJson(response.data!);
  }

  /// Uploads a single video file.
  ///
  /// Parameters:
  ///  * [path] -- the API endpoint path (e.g. `/v1/media/upload/video`).
  ///  * [filePath] -- the absolute path to the video file on disk.
  ///  * [extraFields] -- optional additional form fields to include.
  Future<UploadMediaResponse> uploadVideo({
    required String path,
    required String filePath,
    Map<String, dynamic>? extraFields,
  }) async {
    return uploadImage(
      path: path,
      filePath: filePath,
      fieldName: 'video',
      extraFields: extraFields,
    );
  }

  /// Extracts the file name from a full file path.
  String _fileNameFromPath(String filePath) {
    return filePath.split('/').last;
  }
}
