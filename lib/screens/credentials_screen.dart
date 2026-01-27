import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 's3_browser_screen.dart';
import '../constants/aws_regions.dart';
import '../controllers/credentials_controller.dart';
import '../services/auth_storage_service.dart';
import '../widgets/cards/cards.dart';
import '../widgets/dialogs/dialogs.dart';

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _customEndpointController = TextEditingController();
  final _bucketPathController = TextEditingController();
  final _controller = CredentialsController();

  bool _obscureSecretKey = true;
  bool _useCustomEndpoint = false;
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    _controller.loadConnections();
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _customEndpointController.dispose();
    _bucketPathController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    if (_formKey.currentState!.validate()) {
      final endpoint = AwsRegions.getEndpointUrl(
        region: _selectedRegion,
        customEndpoint: _useCustomEndpoint ? _customEndpointController.text : null,
      );
      final result = await _controller.connect(
        accessKey: _accessKeyController.text,
        secretKey: _secretKeyController.text,
        endpoint: endpoint,
        bucketPath: _bucketPathController.text,
      );
      await _handleConnectionResult(result);
    }
  }

  Future<void> _handleSavedConnect(SavedConnection connection) async {
    final result = await _controller.connectWithSaved(connection);
    await _handleConnectionResult(result);
  }

  Future<void> _handleConnectionResult(ConnectionResult result) async {
    if (result.success && result.s3Service != null) {
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => S3BrowserScreen(
              s3Service: result.s3Service!,
            ),
          ),
        );
        // Reload connections when returning
        if (mounted) {
          await _controller.loadConnections();
        }
      }
    } else if (result.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _handleClearAll() async {
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Clear All',
      message: 'Remove all saved connections?',
      confirmLabel: 'Clear',
    );
    if (confirm) {
      await _controller.clearAllConnections();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('S3 Browser'),
            backgroundColor: Colors.white,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_controller.hasSavedCredentials) ...[
                        _buildSavedConnectionsHeader(),
                        const SizedBox(height: 12),
                        ..._controller.savedConnections.map((connection) => SavedConnectionCard(
                          connection: connection,
                          isConnecting: _controller.isConnecting,
                          onConnect: () => _handleSavedConnect(connection),
                          onDelete: () => _controller.deleteConnection(connection.id),
                        )),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Or add new connection',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (kIsWeb) _buildCorsWarning(),
                      _buildAccessKeyField(),
                      const SizedBox(height: 16),
                      _buildSecretKeyField(),
                      const SizedBox(height: 16),
                      _buildEndpointSection(),
                      const SizedBox(height: 8),
                      _buildCustomEndpointCheckbox(),
                      const SizedBox(height: 16),
                      _buildBucketNameField(),
                      const SizedBox(height: 32),
                      _buildConnectButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedConnectionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Saved Connections',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _handleClearAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Clear All', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildCorsWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The Web version requires CORS configuration on your S3 buckets. ',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessKeyField() {
    return TextFormField(
      controller: _accessKeyController,
      decoration: const InputDecoration(
        labelText: 'Access Key',
        hintText: 'AKIAIOSFODNN7EXAMPLE',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.key),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your access key';
        }
        return null;
      },
    );
  }

  Widget _buildSecretKeyField() {
    return TextFormField(
      controller: _secretKeyController,
      obscureText: _obscureSecretKey,
      decoration: InputDecoration(
        labelText: 'Secret Key',
        hintText: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureSecretKey ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscureSecretKey = !_obscureSecretKey;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your secret key';
        }
        return null;
      },
    );
  }

  Widget _buildEndpointSection() {
    if (!_useCustomEndpoint) {
      return DropdownButtonFormField<String>(
        value: _selectedRegion,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'AWS Region',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.public),
          helperText: 'Optional',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        hint: const Text('Select AWS region'),
        items: AwsRegions.regions.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(
              '${entry.value} (${entry.key})',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedRegion = value;
          });
        },
      );
    }

    return TextFormField(
      controller: _customEndpointController,
      decoration: const InputDecoration(
        labelText: 'Custom Endpoint',
        hintText: 'https://s3.example.com',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.link),
      ),
    );
  }

  Widget _buildCustomEndpointCheckbox() {
    return CheckboxListTile(
      value: _useCustomEndpoint,
      onChanged: (value) {
        setState(() {
          _useCustomEndpoint = value ?? false;
          if (!_useCustomEndpoint) {
            _customEndpointController.clear();
          } else {
            _selectedRegion = null;
          }
        });
      },
      title: const Text('Use custom endpoint'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildBucketNameField() {
    return TextFormField(
      controller: _bucketPathController,
      decoration: const InputDecoration(
        labelText: 'Bucket Name',
        hintText: 'my-bucket-name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.folder),
        helperText: 'The name of your S3 bucket',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the bucket name';
        }
        return null;
      },
    );
  }

  Widget _buildConnectButton() {
    return ElevatedButton(
      onPressed: _controller.isConnecting ? null : _handleConnect,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _controller.isConnecting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Text(
              'Connect',
              style: TextStyle(fontSize: 16),
            ),
    );
  }
}
