/// Core configuration, constants, errors, and extensions for RaveHub.
///
/// This is the barrel export for the `raver_core` package. Import it with:
///
/// ```dart
/// import 'package:raver_core/raver_core.dart';
/// ```
library raver_core;

// Config
export 'src/config/app_config.dart';
export 'src/config/regional_compliance.dart';

// Errors
export 'src/errors/load_phase.dart';
export 'src/errors/service_error.dart';

// Extensions
export 'src/extensions/date_formatting.dart';
