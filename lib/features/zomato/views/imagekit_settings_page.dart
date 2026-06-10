import 'package:demo/Styles/my_font.dart';
import 'package:demo/features/zomato/services/imagekit_settings.dart';
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
      _urlEndpointController.text = config.urlEndpoint;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = ImageKitConfig(
        publicKey: _publicKeyController.text.trim(),
        privateKey: _privateKeyController.text.trim(),
        urlEndpoint: _urlEndpointController.text.trim(),
      );
      if (!config.isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in URL endpoint, public key, and private key.'),
          ),
        );
        return;
      }
      await ImageKitSettings.save(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ImageKit settings saved to cloud. You can add Zomato orders now.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save ImageKit settings: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('ImageKit Settings', style: MyFont.bold(18, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Required for Zomato screenshot uploads.',
                  style: MyFont.regular(14, color: Colors.grey.shade700),
                ),
                if (!_loading) ...[
                  const SizedBox(height: 8),
                  Text(
                    _publicKeyController.text.isNotEmpty &&
                            _privateKeyController.text.isNotEmpty &&
                            _urlEndpointController.text.isNotEmpty
                        ? 'Status: configured'
                        : 'Status: not configured — fill all three fields and tap Save',
                    style: MyFont.regular(
                      13,
                      color: _publicKeyController.text.isNotEmpty &&
                              _privateKeyController.text.isNotEmpty &&
                              _urlEndpointController.text.isNotEmpty
                          ? const Color(0xFF2E7D32)
                          : Colors.orange.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _urlEndpointController,
                  decoration: const InputDecoration(
                    labelText: 'URL endpoint',
                    hintText: 'https://ik.imagekit.io/your_imagekit_id',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _publicKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Public key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _privateKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Private key',
                    border: OutlineInputBorder(),
                  ),
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
                      : const Text('Save', style: TextStyle(fontFamily: fontMulishBold)),
                ),
              ],
            ),
    );
  }
}
