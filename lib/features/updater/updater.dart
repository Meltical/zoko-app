import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/env.dart';

class AppRelease {
  const AppRelease({required this.version, required this.apkUrl, this.checksumUrl, this.notes});

  final String version;
  final String apkUrl;
  final String? checksumUrl;
  final String? notes;
}

final currentVersionProvider = FutureProvider<String>((ref) async => (await PackageInfo.fromPlatform()).version);

final availableUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  if (!Updater.isSupported) return null;
  final current = await ref.watch(currentVersionProvider.future);
  final latest = await Updater.fetchLatest();
  if (latest == null || compareVersions(latest.version, current) <= 0) return null;
  return latest;
});

int compareVersions(String a, String b) {
  List<int> parts(String value) => [
    for (final part in value.replaceFirst(RegExp('^v'), '').split('+').first.split('.')) int.tryParse(part) ?? 0,
  ];
  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < 3; i++) {
    final diff = (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (diff != 0) return diff.sign;
  }
  return 0;
}

abstract final class Updater {
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && kReleaseMode;

  static Future<AppRelease?> fetchLatest() async {
    final response = await http.get(
      Uri.https('api.github.com', '/repos/${Env.githubRepository}/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
    String? urlOf(bool Function(String name) test) {
      for (final asset in assets) {
        if (test(asset['name'] as String)) return asset['browser_download_url'] as String;
      }
      return null;
    }

    final apk = urlOf((name) => name.endsWith('.apk'));
    if (apk == null) return null;
    return AppRelease(
      version: json['tag_name'] as String,
      apkUrl: apk,
      checksumUrl: urlOf((name) => name.endsWith('.apk.sha256')),
      notes: json['body'] as String?,
    );
  }

  static Future<Stream<OtaEvent>> install(AppRelease release) async {
    String? checksum;
    if (release.checksumUrl != null) {
      final response = await http.get(Uri.parse(release.checksumUrl!));
      if (response.statusCode == 200) checksum = response.body.trim().split(RegExp(r'\s+')).first;
    }
    return OtaUpdate().execute(release.apkUrl, destinationFilename: 'zoko.apk', sha256checksum: checksum);
  }
}

Future<void> showUpdateDialog(BuildContext context, AppRelease release) => showDialog<void>(
  context: context,
  builder: (_) => _UpdateDialog(release: release),
);

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;
  bool _running = false;

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final events = await Updater.install(widget.release);
      await for (final event in events) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            setState(() => _progress = (double.tryParse(event.value ?? '') ?? 0) / 100);
          case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
            Navigator.of(context).pop();
            return;
          default:
            setState(() {
              _running = false;
              _error = 'Échec de la mise à jour (${event.status.name.toLowerCase()})';
            });
            return;
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = 'Échec de la mise à jour : $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Zoko ${widget.release.version.replaceFirst('v', '')} est disponible'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (widget.release.notes?.trim().isNotEmpty ?? false)
          Text(widget.release.notes!.trim(), maxLines: 8, overflow: TextOverflow.ellipsis),
        if (_running) LinearProgressIndicator(value: _progress),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ),
    actions: [
      TextButton(onPressed: _running ? null : () => Navigator.of(context).pop(), child: const Text('Plus tard')),
      FilledButton(onPressed: _running ? null : _start, child: const Text('Installer')),
    ],
  );
}
