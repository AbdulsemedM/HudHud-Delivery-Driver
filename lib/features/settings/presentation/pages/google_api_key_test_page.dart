import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';

/// Minimal in-app test for the Google web-services key, using the Geocoding API.
///
/// It checks GOOGLE_MAPS_WEB_KEY, not GOOGLE_MAPS_API_KEY, and that distinction
/// is the whole point of the page. Geocoding runs over maps.googleapis.com, and
/// Google does not apply Android application restrictions to those endpoints —
/// so probing it with the Maps SDK key (which IS restricted to our package) is
/// guaranteed to come back REQUEST_DENIED even when the SDK key is perfectly
/// healthy and the map is drawing fine. A diagnostic that reports a working key
/// as broken is worse than no diagnostic.
///
/// The SDK key cannot be probed this way at all; the only honest test of it is
/// whether map tiles render. Keys are loaded from native build config (see
/// ENV_SECRETS.md).
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
    final apiKey = await GoogleMapsApiKeyProvider.getWebKey();
    if (apiKey.isEmpty) {
      setState(() {
        _success = false;
        _message = 'No web-services key configured.\n\n'
            'Set GOOGLE_MAPS_WEB_KEY in .env or android/local.properties, then rebuild.\n\n'
            'This is a different key from GOOGLE_MAPS_API_KEY: that one draws the '
            'map and is restricted to this app, which Google only honours for the '
            'Maps SDK. Places, Geocoding and Directions need a key with no app '
            'restriction.';
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
        // REQUEST_DENIED here almost always means one specific mistake, and the
        // raw message from Google ("This IP, site or mobile application is not
        // authorized to use this API key") does not point at it.
        final hint = status == 'REQUEST_DENIED'
            ? '\n\nMost likely GOOGLE_MAPS_WEB_KEY is unset and the app fell '
                'back to the Maps SDK key, which is restricted to this Android '
                'app. Google applies that restriction to the Maps SDK only and '
                'rejects it here. Check the key in Google Cloud Console: its '
                'Application restriction must be None, and its API restriction '
                'must include Geocoding API.'
            : '';
        setState(() {
          _success = false;
          _message = 'API error: $errorMsg$hint';
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
