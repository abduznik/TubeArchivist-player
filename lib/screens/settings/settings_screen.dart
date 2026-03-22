import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/preferences_service.dart';
import '../../services/api_service.dart';
import '../../widgets/app_shell.dart'; // To navigate home after login

class SettingsScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const SettingsScreen({super.key, this.isFirstLaunch = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = PreferencesService();
    if (prefs.hasCredentials()) {
      _urlController.text = prefs.getServerUrl() ?? '';
      _tokenController.text = prefs.getApiToken() ?? '';
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // Temporarily save to test, or we could pass params to testConnection
    // But api_service uses singleton prefs. 
    // So we must save to prefs first? Or ApiService could take params.
    // The current ApiService implementation reads from Prefs. 
    // So we must save to prefs to test with ApiService.
    // BUT, if the test fails, we might want to revert? 
    // For this simple app, saving then testing is fine. If it fails, user can fix it.
    
    await PreferencesService().saveCredentials(
      _urlController.text.trim(),
      _tokenController.text.trim(),
    );

    try {
      final success = await ApiService().testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Connection Successful!' : 'Connection Failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success && widget.isFirstLaunch) {
          // Navigate to Home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        }
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.1.100:8000',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter server URL';
                  }
                  if (!value.startsWith('http')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'API Token',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter API Token';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.wifi),
                  label: Text(_isLoading ? 'Testing...' : 'Test Connection & Save'),
                ),
              ),
              if (widget.isFirstLaunch) ...[
                const SizedBox(height: 20),
                const Text(
                  'Enter your TubeArchivist server details to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
