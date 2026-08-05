import 'package:smartKitchen/Styles/my_font.dart';
import 'package:smartKitchen/features/zomato/services/imagekit_settings.dart';
import 'package:flutter/material.dart';

const _navy = Color(0xFF1A3A5C);
const _orange = Color(0xFFf57c35);

class ImageKitSettingsPage extends StatefulWidget {
  const ImageKitSettingsPage({super.key});

  @override
  State<ImageKitSettingsPage> createState() => _ImageKitSettingsPageState();
}

class _ImageKitSettingsPageState extends State<ImageKitSettingsPage> {
  final _publicKeyController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _urlEndpointController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _resetting = false;
  bool _showPrivateKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await ImageKitSettings.load();
    if (!mounted) return;
    setState(() {
      _publicKeyController.text = config.publicKey;
      _privateKeyController.text = config.privateKey;
      _urlEndpointController.text = config.urlEndpoint.isNotEmpty
          ? config.urlEndpoint
          : 'https://ik.imagekit.io/tet01w2tu';
      _loading = false;
    });
  }

  Future<void> _resetToDefaults() async {
    setState(() => _resetting = true);
    try {
      await ImageKitSettings.resetToDefaults();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Default ImageKit keys restored. Try uploading a Zomato screenshot again.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restore defaults: $e')),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = ImageKitConfig(
        publicKey: _publicKeyController.text,
        privateKey: _privateKeyController.text,
        urlEndpoint: _urlEndpointController.text,
      ).normalized();

      if (!config.isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid keys: ${config.missingFields.join(', ')}. '
              'Use the Copy buttons in ImageKit dashboard — do not type from the table view.',
            ),
          ),
        );
        return;
      }

      await ImageKitSettings.save(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ImageKit settings saved on this device. You can add Zomato orders now.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _publicKeyController.dispose();
    _privateKeyController.dispose();
    _urlEndpointController.dispose();
    super.dispose();
  }

  bool get _looksConfigured {
    final config = ImageKitConfig(
      publicKey: _publicKeyController.text,
      privateKey: _privateKeyController.text,
      urlEndpoint: _urlEndpointController.text,
    ).normalized();
    return config.isValid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          'ImageKit Settings',
          style: MyFont.bold(18, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From your ImageKit dashboard',
                          style: MyFont.semiBold(14, color: _navy),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ImagekitID: tet01w2tu',
                          style: MyFont.regular(13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Important: use the Copy icon next to each field in ImageKit. '
                          'The table view hides part of the keys — typing manually often fails. '
                          'Web uploads use the same keys saved here.',
                          style: MyFont.regular(13, color: Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _looksConfigured
                      ? 'Status: configured'
                      : 'Status: not configured — paste all three values and tap Save',
                  style: MyFont.regular(
                    13,
                    color: _looksConfigured
                        ? const Color(0xFF2E7D32)
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlEndpointController,
                  decoration: const InputDecoration(
                    labelText: 'URL endpoint',
                    hintText: 'https://ik.imagekit.io/tet01w2tu',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _publicKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Public key',
                    hintText: 'public_… (copy full key from ImageKit)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _privateKeyController,
                  obscureText: !_showPrivateKey,
                  decoration: InputDecoration(
                    labelText: 'Private key',
                    hintText: 'private_… (click eye icon in ImageKit, then copy)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPrivateKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPrivateKey = !_showPrivateKey),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontFamily: fontMulishBold),
                        ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: (_saving || _resetting) ? null : _resetToDefaults,
                  child: _resetting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Use default keys'),
                ),
              ],
            ),
    );
  }
}
