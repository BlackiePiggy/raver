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
/// | `raver://community/post/{id}`      | `/circle/post/{id}`             |
/// | `raver://circle/id/{id}`           | `/circle/id/{id}`               |
/// | `raver://user/{id}`                | `/users/{id}`                   |
/// | `raver://profile/{id}`             | `/users/{id}`                   |
/// | `raver://profile/quiz`             | `/profile/quiz`                 |
/// | `raver://messages/followed-events` | `/inbox/followed-events`        |
/// | `raver://squad/{id}`               | `/circle/squads/{id}`           |
/// | `raver://news/{id}`                | `/news/{id}`                    |
/// | `raver://label/{id}`               | `/labels/{id}`                  |
/// | `raver://festival/{id}`            | `/festivals/{id}`               |
/// | `raver://ranking/{id}`             | `/rankings/{id}`                |
/// | `raver://ranking-board/{id}`       | `/rankings/{id}`                |
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
    'profile': '/users',
    'squad': '/circle/squads',
    'news': '/news',
    'label': '/labels',
    'festival': '/festivals',
    'ranking': '/rankings',
    'ranking-board': '/rankings',
    'genre': '/genres',
    'rating-event': '/circle/ratings',
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
        _isAllowedUniversalLinkHost(uri.host)) {
      return _resolveUniversalLink(uri);
    }
    return null;
  }

  /// Alias kept for backward compatibility.
  static String? resolve(Uri uri) => toAppPath(uri);

  static bool _isAllowedUniversalLinkHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == universalLinkHost ||
        normalized == 'www.$universalLinkHost';
  }

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

    if (resource == 'messages') {
      final messagesPath = _messagesPath(rest);
      if (messagesPath != null) return messagesPath;
    }

    if (resource == 'profile') {
      final profilePath = _profilePath(rest);
      if (profilePath != null) return profilePath;
    }

    if (resource == 'circle' &&
        rest.length >= 2 &&
        (rest.first == 'id' || rest.first == 'ids')) {
      return '/circle/id/${rest[1]}';
    }

    if (resource == 'circle' &&
        rest.length >= 4 &&
        rest.first == 'ratings' &&
        rest[2] == 'units') {
      return '/circle/ratings/${rest[1]}/units/${rest[3]}';
    }

    if (resource == 'circle' && rest.length >= 2 && rest.first == 'ratings') {
      return '/circle/ratings/${rest[1]}';
    }

    if (resource == 'circle' &&
        rest.length >= 2 &&
        rest.first == 'rating-event') {
      return '/circle/ratings/${rest[1]}';
    }

    if (resource == 'community' && rest.length >= 2 && rest.first == 'post') {
      final queryString = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return '/circle/post/${rest[1]}$queryString';
    }

    final prefix = _resourceToPath[resource];
    if (prefix == null) return null;

    // We require at least a resource ID.
    if (rest.isEmpty) return null;

    final id = rest.first;
    final queryString = uri.query.isNotEmpty ? '?${uri.query}' : '';
    return '$prefix/$id$queryString';
  }

  // ---- HTTPS universal link: https://ravehub.top/path -----------------------

  static String? _resolveUniversalLink(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    if (segments.first.toLowerCase() == 's') return null;

    final appPath = _canonicalUniversalPath(segments);
    if (appPath != null) {
      final queryString = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return '$appPath$queryString';
    }

    // The website path structure mirrors GoRouter paths
    // (e.g. https://ravehub.top/events/abc123 -> /events/abc123).
    final path = uri.path;
    if (path.isEmpty || path == '/') return null;
    final queryString = uri.query.isNotEmpty ? '?${uri.query}' : '';
    return '$path$queryString';
  }

  static String? _canonicalUniversalPath(List<String> segments) {
    if (segments.length < 2) return null;
    final kind = segments[0].toLowerCase();
    final id = segments[1];
    switch (kind) {
      case 'p':
      case 'posts':
        return '/circle/post/$id';
      case 'e':
      case 'event':
      case 'events':
        return '/events/$id';
      case 'n':
      case 'news':
        return '/news/$id';
      case 'dj':
      case 'djs':
        return '/djs/$id';
      case 'set':
      case 'sets':
        return '/sets/$id';
      case 'label':
      case 'labels':
        return '/labels/$id';
      case 'festival':
      case 'festivals':
        return '/festivals/$id';
      case 'ranking-board':
      case 'rankings':
        return '/rankings/$id';
      case 'rating-event':
      case 'rating-events':
        return '/circle/ratings/$id';
      case 'u':
      case 'user':
      case 'users':
        return '/users/$id';
      case 'profile':
        final profilePath = _profilePath(segments.skip(1).toList());
        if (profilePath != null) return profilePath;
        return '/users/$id';
      case 'messages':
        return _messagesPath(segments.skip(1).toList());
      case 'g':
      case 'squad':
      case 'squads':
        return '/circle/squads/$id';
      case 'circle':
        if (segments.length >= 3 && segments[1].toLowerCase() == 'id') {
          return '/circle/id/${segments[2]}';
        }
        if (segments.length >= 3 &&
            segments[1].toLowerCase() == 'rating-event') {
          return '/circle/ratings/${segments[2]}';
        }
        if (segments.length >= 3 && segments[1].toLowerCase() == 'ratings') {
          if (segments.length >= 5 && segments[3].toLowerCase() == 'units') {
            return '/circle/ratings/${segments[2]}/units/${segments[4]}';
          }
          return '/circle/ratings/${segments[2]}';
        }
    }
    return null;
  }

  static String? _profilePath(List<String> segments) {
    if (segments.isEmpty) return '/profile';
    switch (segments.first.toLowerCase()) {
      case 'me':
        return '/profile';
      case 'edit':
        return '/profile/edit';
      case 'checkins':
        return '/profile/checkins';
      case 'publishes':
        if (segments.length >= 2) return '/profile/publishes/${segments[1]}';
        return '/profile/publishes';
      case 'contributions':
        return '/profile/contributions';
      case 'quiz':
        return '/profile/quiz';
      case 'personality':
        return '/profile/personality';
      case 'settings':
        if (segments.length >= 2) {
          return '/profile/settings/${segments[1]}';
        }
        return '/profile/settings';
      case 'follow-list':
        if (segments.length >= 2) return '/profile/follow-list/${segments[1]}';
        return null;
      case 'saves':
        return '/profile/saves';
      case 'virtual-assets':
      case 'virtual_assets':
        return '/profile/virtual-assets';
      case 'tools':
        if (segments.length >= 2) {
          return '/profile/tools/${segments.skip(1).join('/')}';
        }
        return null;
    }
    return null;
  }

  static String? _messagesPath(List<String> segments) {
    if (segments.isEmpty) return '/inbox';
    switch (segments.first.toLowerCase()) {
      case 'followed-events':
        return '/inbox/followed-events';
      case 'followed-djs':
        return '/inbox/followed-djs';
      case 'followed-brands':
        return '/inbox/followed-brands';
      case 'content-reviews':
        return '/inbox/content-reviews';
      case 'alerts':
        if (segments.length >= 2) return '/inbox/alerts/${segments[1]}';
        return null;
    }
    return null;
  }
}
