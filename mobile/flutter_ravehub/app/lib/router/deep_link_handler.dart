/// Converts custom-scheme and HTTPS deep link URIs into GoRouter paths.
///
/// The app registers the `raver://` URL scheme (iOS universal links and
/// Android App Links are handled separately via the `https://ravehub.top`
/// domain). This class converts incoming deep-link URIs into the
/// corresponding GoRouter path so navigation can proceed normally.
///
/// ## Supported mappings
///
/// | Deep link                          | GoRouter path                   |
/// |------------------------------------|---------------------------------|
/// | `raver://event/{id}`               | `/events/{id}`                  |
/// | `raver://dj/{id}`                  | `/djs/{id}`                     |
/// | `raver://set/{id}`                 | `/sets/{id}`                    |
/// | `raver://post/{id}`                | `/circle/post/{id}`             |
/// | `raver://user/{id}`                | `/users/{id}`                   |
/// | `raver://squad/{id}`               | `/circle/squads/{id}`           |
/// | `raver://news/{id}`                | `/news/{id}`                    |
/// | `raver://label/{id}`               | `/labels/{id}`                  |
/// | `raver://festival/{id}`            | `/festivals/{id}`               |
/// | `raver://ranking/{id}`             | `/rankings/{id}`                |
/// | `raver://genre/{id}`               | `/genres/{id}`                  |
/// | `raver://search?q=x`              | `/search?q=x`                   |
/// | `https://ravehub.top/events/123`   | `/events/123`                   |
class DeepLinkHandler {
  const DeepLinkHandler._();

  /// The custom URL scheme registered for the RaveHub app.
  static const String scheme = 'raver';

  /// The host for HTTPS universal links.
  static const String universalLinkHost = 'ravehub.top';

  /// Mapping from custom-scheme resource names (singular) to GoRouter path
  /// prefixes (may be plural or include section prefixes).
  static const Map<String, String> _resourceToPath = {
    'event': '/events',
    'dj': '/djs',
    'set': '/sets',
    'post': '/circle/post',
    'user': '/users',
    'squad': '/circle/squads',
    'news': '/news',
    'label': '/labels',
    'festival': '/festivals',
    'ranking': '/rankings',
    'genre': '/genres',
  };

  /// Primary entry point: converts a deep-link [Uri] to a GoRouter path.
  ///
  /// Returns `null` if the URI does not match any known deep link pattern,
  /// allowing the caller to fall through to default routing behaviour.
  static String? toAppPath(Uri uri) {
    if (uri.scheme == scheme) {
      return _resolveCustomScheme(uri);
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.endsWith(universalLinkHost)) {
      return _resolveUniversalLink(uri);
    }
    return null;
  }

  /// Alias kept for backward compatibility.
  static String? resolve(Uri uri) => toAppPath(uri);

  // ---- Custom scheme: raver://resource/id -----------------------------------

  static String? _resolveCustomScheme(Uri uri) {
    // `raver://` URIs use the host as the resource type.
    // e.g. `raver://event/123` has host="event", pathSegments=["123"].
    // However some URI parsers treat `raver://event/123` as
    // host="" + pathSegments=["event","123"]. Handle both layouts.

    String resource;
    List<String> rest;

    if (uri.host.isNotEmpty) {
      // `raver://event/123` parsed as host="event", path="/123"
      resource = uri.host;
      rest = uri.pathSegments;
    } else if (uri.pathSegments.isNotEmpty) {
      // `raver:///event/123` parsed as host="", path="/event/123"
      resource = uri.pathSegments.first;
      rest = uri.pathSegments.skip(1).toList();
    } else {
      return null;
    }

    // Special case: search has no resource ID, only query parameters.
    if (resource == 'search') {
      final queryString = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return '/search$queryString';
    }

    final prefix = _resourceToPath[resource];
    if (prefix == null) return null;

    // We require at least a resource ID.
    if (rest.isEmpty) return null;

    final id = rest.first;
    return '$prefix/$id';
  }

  // ---- HTTPS universal link: https://ravehub.top/path -----------------------

  static String? _resolveUniversalLink(Uri uri) {
    final path = uri.path;
    if (path.isEmpty || path == '/') return null;

    // The website path structure mirrors GoRouter paths
    // (e.g. https://ravehub.top/events/abc123 -> /events/abc123).
    final queryString = uri.query.isNotEmpty ? '?${uri.query}' : '';
    return '$path$queryString';
  }
}
