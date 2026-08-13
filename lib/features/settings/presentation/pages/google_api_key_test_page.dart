import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';

/// Minimal in-app test for the Google API key using Geocoding API.
/// Key is loaded from native build config (see ENV_SECRETS.md).
class GoogleApiKeyTestPage extends StatefulWidget {
  const GoogleApiKeyTestPage({super.key});

  @override
  State<GoogleApiKeyTestPage> createState() => _GoogleApiKeyTestPageState();
}

class _GoogleApiKeyTestPageState extends State<GoogleApiKeyTestPage> {
  bool _loading = false;
  String? _message;
  bool? _success;

  Future<void> _testKey() async {
    final apiKey = await GoogleMapsApiKeyProvider.getApiKey();
    if (apiKey.isEmpty) {
      setState(() {
        _success = false;
        _message = 'No API key configured.\n\n'
            'Android: set GOOGLE_MAPS_API_KEY in .env or android/local.properties, then rebuild.\n'
            'iOS: copy ios/Flutter/LocalSecrets.xcconfig.example to LocalSecrets.xcconfig, then rebuild.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _success = null;
    });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=London&key=${Uri.encodeComponent(apiKey)}',
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out'),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;

      if (!mounted) return;

      if (status == 'OK') {
        final results = body['results'] as List<dynamic>?;
        final first = results != null && results.isNotEmpty
            ? results.first as Map<String, dynamic>
            : null;
        final formatted = first?['formatted_address'] as String? ?? 'London';
        setState(() {
          _success = true;
          _message = 'Key OK\n\nSample result: $formatted';
        });
      } else {
        final errorMsg = body['error_message'] as String? ?? status ?? 'Unknown error';
        setState(() {
          _success = false;
          _message = 'API error: $errorMsg';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Google API Key'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Calls Google Geocoding API with your key. Enable "Geocoding API" in Google Cloud Console if needed.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _testKey,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.key),
              label: Text(_loading ? 'Testing…' : 'Test Key'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _success == true
                      ? Colors.green.shade50
                      : _success == false
                          ? Colors.red.shade50
                          : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _success == true
                        ? Colors.green
                        : _success == false
                            ? Colors.red
                            : Colors.grey,
                  ),
                ),
                child: SelectableText(
                  _message!,
                  style: TextStyle(
                    color: _success == true
                        ? Colors.green.shade900
                        : _success == false
                            ? Colors.red.shade900
                            : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
