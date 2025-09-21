import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

/// This class demonstrates how to use the AppLogger in different parts of the app
class LoggingExample {
  final AppLogger _logger = getIt<AppLogger>();

  /// Example of logging during app startup
  void logAppStartup() {
    _logger.info('Application started');
    _logger.debug('Debug mode enabled: ${const bool.fromEnvironment('dart.vm.product') == false}');
  }

  /// Example of logging user actions
  void logUserAction(String action, {Map<String, dynamic>? data}) {
    _logger.info('User performed action: $action', data);
  }

  /// Example of logging network requests
  void logNetworkRequest(String url, String method, {Map<String, dynamic>? headers}) {
    _logger.debug('Network request: $method $url', {'headers': headers});
  }

  /// Example of logging network responses
  void logNetworkResponse(String url, int statusCode, dynamic data) {
    if (statusCode >= 200 && statusCode < 300) {
      _logger.info('Network success: $url returned $statusCode');
    } else {
      _logger.warning('Network warning: $url returned $statusCode', data);
    }
  }

  /// Example of logging errors
  void logError(dynamic error, StackTrace? stackTrace) {
    _logger.error('An error occurred', error, stackTrace);
  }

  /// Example of logging critical errors
  void logCriticalError(dynamic error, StackTrace stackTrace) {
    _logger.fatal('Critical error occurred', error, stackTrace);
  }
}

/// Example widget that demonstrates logging in UI components
class LoggingDemoWidget extends StatelessWidget {
  LoggingDemoWidget({Key? key}) : super(key: key);

  final AppLogger _logger = getIt<AppLogger>();

  @override
  Widget build(BuildContext context) {
    _logger.debug('Building LoggingDemoWidget');
    
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            _logger.info('Info button pressed');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Info logged to console')),
            );
          },
          child: const Text('Log Info'),
        ),
        ElevatedButton(
          onPressed: () {
            _logger.warning('Warning button pressed');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning logged to console'),
                backgroundColor: Colors.amber,
              ),
            );
          },
          child: const Text('Log Warning'),
        ),
        ElevatedButton(
          onPressed: () {
            try {
              // Intentionally cause an error
              final list = <int>[];
              // ignore: unused_local_variable
              final item = list[10]; // This will throw an index out of range error
            } catch (e, stackTrace) {
              _logger.error('Error occurred', e, stackTrace);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error logged to console'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Log Error'),
        ),
      ],
    );
  }
}