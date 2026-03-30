import 'dart:convert';
import 'package:flutter/material.dart';

import 'AppWriteService.dart';
import 'ConfigService.dart';

class ConfigManagerPage extends StatefulWidget {
  const ConfigManagerPage({super.key});

  @override
  State<ConfigManagerPage> createState() => _ConfigManagerPageState();
}

class _ConfigManagerPageState extends State<ConfigManagerPage> {
  final ScrollController _scrollController = ScrollController();
  List<ConfigItem> _configs = [];
  bool _loading = true;
  String _searchQuery = '';

  static const _sensitiveKeywords = ['enabled', 'limit', 'password', 'secret', 'api_key'];

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfigs() async {
    setState(() => _loading = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final configs = await ConfigService.fetchConfigs(jwtToken: jwt);
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }


  bool _isSensitive(String key) {
    final k = key.toLowerCase();
    return _sensitiveKeywords.any((s) => k.contains(s));
  }

  List<ConfigItem> get _filteredConfigs {
    if (_searchQuery.isEmpty) return _configs;
    final q = _searchQuery.toLowerCase();
    return _configs.where((c) => c.key.toLowerCase().contains(q) || c.val.toLowerCase().contains(q)).toList();
  }

  // ── Validation ──

  static String? validateKey(String? key) {
    if (key == null || key.trim().isEmpty) return 'Key is required';
    if (key.trim().contains(' ')) return 'Key must not contain spaces';
    return null;
  }

  static String? validateVal(String? val, String type) {
    if (val == null || val.trim().isEmpty) return 'Value is required';
    final v = val.trim();
    switch (type) {
      case 'integer':
        if (int.tryParse(v) == null) return 'Must be a valid integer (no decimals)';
        break;
      case 'double':
        if (double.tryParse(v) == null) return 'Must be a valid number';
        break;
      case 'boolean':
        if (v != 'true' && v != 'false') return 'Must be true or false';
        break;
      case 'json':
        try {
          json.decode(v);
        } catch (_) {
          return 'Must be valid JSON';
        }
        break;
    }
    return null;
  }

  // ── Loading Dialog Helper ──

  Future<void> _runWithLoadingDialog({
    required String loadingMessage,
    required Future<String> Function() action,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(loadingMessage)),
          ],
        ),
      ),
    );

    try {
      final msg = await action();
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      // Show success dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Success'),
          content: Text(msg),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _fetchConfigs();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      // Show error dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 48),
          title: const Text('Error'),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // ── CRUD Actions ──

  Future<void> _createConfig(String key, String val, String type, String description) async {
    await _runWithLoadingDialog(
      loadingMessage: 'Creating config...',
      action: () async {
        final jwt = await AppWriteService().getJWT();
        return ConfigService.createConfig(
          jwtToken: jwt,
          key: key.trim(),
          val: val.trim(),
          type: type,
          description: description.trim(),
        );
      },
    );
  }

  Future<void> _updateConfig(String key, String val, String description) async {
    await _runWithLoadingDialog(
      loadingMessage: 'Updating config...',
      action: () async {
        final jwt = await AppWriteService().getJWT();
        return ConfigService.updateConfig(
          jwtToken: jwt,
          key: key,
          val: val.trim(),
          description: description.trim(),
        );
      },
    );
  }

  Future<void> _deleteConfig(ConfigItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 36),
        title: const Text('Delete Config'),
        content: Text('Are you sure you want to delete "${item.key}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runWithLoadingDialog(
      loadingMessage: 'Deleting config...',
      action: () async {
        final jwt = await AppWriteService().getJWT();
        return ConfigService.deleteConfig(jwtToken: jwt, key: item.key);
      },
    );
  }

  // ── Dialogs ──

  void _showAddEditDialog({ConfigItem? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _ConfigFormDialog(
        existing: existing,
        onSave: (key, val, type, description) {
          Navigator.pop(ctx);
          if (existing != null) {
            _updateConfig(key, val, description);
          } else {
            _createConfig(key, val, type, description);
          }
        },
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredConfigs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Scroll to top',
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchConfigs,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConfigs,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search configs...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),
                  // Count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        '${filtered.length} config${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // List
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No configs found')),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildConfigCard(filtered[index]),
                        childCount: filtered.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildConfigCard(ConfigItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sensitive = _isSensitive(item.key);
    final isEnabled = item.key.toLowerCase().contains('enabled');
    final isLimit = item.key.toLowerCase().contains('limit') &&
        (item.type == 'integer' || item.type == 'double');

    Color? cardTint;
    if (isEnabled) {
      cardTint = item.val == 'true'
          ? Colors.green.withValues(alpha: isDark ? 0.15 : 0.06)
          : Colors.red.withValues(alpha: isDark ? 0.15 : 0.06);
    } else if (isLimit) {
      cardTint = Colors.orange.withValues(alpha: isDark ? 0.15 : 0.06);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: cardTint,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAddEditDialog(existing: item),
        onLongPress: () => _deleteConfig(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key row
              Row(
                children: [
                  if (sensitive)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                    ),
                  Expanded(
                    child: Text(
                      item.key,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _typeChip(item.type),
                  if (item.type == 'boolean') ...[
                    const SizedBox(width: 6),
                    _boolBadge(item.val == 'true'),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // Value
              Text(
                _displayVal(item),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: item.type == 'json' ? 'monospace' : null,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              // Description
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Timestamps
              if (item.updatedAt != null || item.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(item.updatedAt ?? item.createdAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return 'Updated: ${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  String _displayVal(ConfigItem item) {
    if (item.type == 'boolean') return item.val == 'true' ? 'Enabled' : 'Disabled';
    if (item.val.isEmpty) return '(empty)';
    return item.val;
  }

  Widget _typeChip(String type) {
    Color color;
    switch (type) {
      case 'boolean':
        color = Colors.purple;
        break;
      case 'integer':
        color = Colors.blue;
        break;
      case 'double':
        color = Colors.teal;
        break;
      case 'json':
        color = Colors.deepOrange;
        break;
      default:
        color = Colors.grey;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.3)),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _boolBadge(bool on) {
    final color = on ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        on ? 'ON' : 'OFF',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Add / Edit Dialog
// ══════════════════════════════════════════════════════════

class _ConfigFormDialog extends StatefulWidget {
  final ConfigItem? existing;
  final void Function(String key, String val, String type, String description) onSave;

  const _ConfigFormDialog({this.existing, required this.onSave});

  @override
  State<_ConfigFormDialog> createState() => _ConfigFormDialogState();
}

class _ConfigFormDialogState extends State<_ConfigFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedType;
  bool _boolVal = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static const _validTypes = ['string', 'integer', 'double', 'boolean', 'json'];

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.existing?.key ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _selectedType = widget.existing?.type ?? 'string';
    if (_selectedType == 'boolean') {
      _boolVal = widget.existing?.val == 'true';
      _valCtrl = TextEditingController(text: _boolVal ? 'true' : 'false');
    } else {
      _valCtrl = TextEditingController(text: widget.existing?.val ?? '');
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      if (type == 'boolean') {
        _boolVal = _valCtrl.text.trim() == 'true';
        _valCtrl.text = _boolVal ? 'true' : 'false';
      }
    });
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final val = _selectedType == 'boolean' ? (_boolVal ? 'true' : 'false') : _valCtrl.text.trim();
    widget.onSave(_keyCtrl.text.trim(), val, _selectedType, _descCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Config' : 'Add Config'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Key
                TextFormField(
                  controller: _keyCtrl,
                  readOnly: _isEdit,
                  enabled: !_isEdit,
                  decoration: InputDecoration(
                    labelText: 'Key',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _isEdit ? const Icon(Icons.lock, size: 18) : null,
                  ),
                  validator: _ConfigManagerPageState.validateKey,
                ),
                const SizedBox(height: 14),

                // Type
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _isEdit ? const Icon(Icons.lock, size: 18) : null,
                  ),
                  items: _validTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: _isEdit ? null : _onTypeChanged,
                  validator: (v) => v == null ? 'Select a type' : null,
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'What does this config do?',
                  ),
                ),
                const SizedBox(height: 14),

                // Value
                _buildValField(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _onSubmit,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save, size: 18),
          label: Text(_isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildValField() {
    if (_selectedType == 'boolean') {
      return Row(
        children: [
          const Text('Value:'),
          const Spacer(),
          Text(_boolVal ? 'true' : 'false',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _boolVal ? Colors.green : Colors.red,
              )),
          Switch(
            value: _boolVal,
            onChanged: (v) => setState(() {
              _boolVal = v;
              _valCtrl.text = v ? 'true' : 'false';
            }),
          ),
        ],
      );
    }

    return TextFormField(
      controller: _valCtrl,
      maxLines: _selectedType == 'json' ? 6 : 1,
      keyboardType: _keyboardType,
      style: _selectedType == 'json' ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : null,
      decoration: InputDecoration(
        labelText: 'Value',
        border: const OutlineInputBorder(),
        isDense: true,
        hintText: _hintForType,
      ),
      validator: (v) => _ConfigManagerPageState.validateVal(v, _selectedType),
    );
  }

  TextInputType get _keyboardType {
    switch (_selectedType) {
      case 'integer':
        return TextInputType.number;
      case 'double':
        return const TextInputType.numberWithOptions(decimal: true);
      case 'json':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  String get _hintForType {
    switch (_selectedType) {
      case 'integer':
        return 'e.g. 100';
      case 'double':
        return 'e.g. 10.5';
      case 'json':
        return '{"key": "value"}';
      default:
        return '';
    }
  }
}
