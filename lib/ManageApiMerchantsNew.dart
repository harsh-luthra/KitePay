import 'package:admin_qr_manager/AppConfig.dart';
import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/widget/ApiMerchantCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'ApiMerchantsService.dart';  // Your service with CRUD methods
import 'models/ApiMerchant.dart';  // Your ApiApiMerchant model
// import 'ApiApiMerchantsFormPage.dart';  // New form page (defined below)

// Generic page state (same as withdrawals)
class PageState<T> {
  List<T> items;
  String? nextCursor;
  bool hasMore;
  bool loadingMore;

  PageState({
    List<T>? items,
    this.nextCursor,
    this.hasMore = true,
    this.loadingMore = false,
  }) : items = items ?? [];
}

class ManageApiMerchantsNew extends StatefulWidget {
  const ManageApiMerchantsNew({super.key});

  @override
  State<ManageApiMerchantsNew> createState() => _ManageApiMerchantsNewState();
}

class _ManageApiMerchantsNewState extends State<ManageApiMerchantsNew> {
  // Filter states
  String filter = 'active';
  String? searchQuery;

  // Pagination state
  final PageState<ApiMerchant> pageState = PageState<ApiMerchant>();
  bool inFlight = false;

  // Global loading
  bool loading = false;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchInitial() async {
    setState(() => loading = true);
    try {
      await fetchPage(firstLoad: true);
    } catch (e) {
      _showSnackBar('❌ Failed to load ApiMerchants: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> fetchPage({bool firstLoad = false}) async {
    if (inFlight || !pageState.hasMore) return;
    if (firstLoad) {
      pageState.items.clear();
      pageState.nextCursor = null;
      pageState.hasMore = true;
    }

    inFlight = true;
    final wasEmpty = pageState.items.isEmpty;
    if (wasEmpty) setState(() => loading = true);
    else setState(() => pageState.loadingMore = true);

    try {
      final resp = await ApiMerchantsService.fetchApiMerchantsPaginated(
        jwtToken: await AppWriteService().getJWT(),
        status: filter == 'all' ? null : filter,
        search: searchQuery?.isNotEmpty == true ? searchQuery : null,
        cursor: pageState.nextCursor,
      );

      // Dedupe by ID
      final existingIds = pageState.items.map((m) => m.id).whereType<String>().toSet();
      final newApiMerchants = resp.merchants.where((m) => m.id != null && !existingIds.contains(m.id));

      if (firstLoad || pageState.items.isEmpty) {
        pageState.items = newApiMerchants.toList();
      } else {
        pageState.items.addAll(newApiMerchants);
      }

      pageState.nextCursor = resp.nextCursor;
      pageState.hasMore = resp.nextCursor != null;
    } catch (e) {
      _showSnackBar('❌ Failed to fetch ApiMerchants: $e');
    } finally {
      inFlight = false;
      if (mounted) {
        setState(() {
          if (loading) loading = false;
          pageState.loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await fetchPage(firstLoad: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      fetchPage();
    }
  }

  void _onFilterChanged(String newFilter) {
    if (filter == newFilter) return;
    setState(() => filter = newFilter);
    fetchPage(firstLoad: true);
  }

  void _onSearchChanged(String? query) {
    searchQuery = query?.trim().isEmpty != true ? query?.trim() : null;
    fetchPage(firstLoad: true);
  }

  Map<String, int> get counts {
    return {
      'all': pageState.items.length,
      'active': pageState.items.where((m) => m.status == 'active').length,
      'suspended': pageState.items.where((m) => m.status == 'suspended').length,
      'pending': pageState.items.where((m) => m.status == 'pending').length,
    };
  }

  // Widget buildFilterChip(String label, String value) {
  //   final count = counts[value] ?? 0;
  //   final selected = filter == value;
  //   return ChoiceChip(
  //     label: Text('$label (${count.toString()})'),
  //     selected: selected,
  //     labelStyle: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
  //     selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
  //     surfaceTintColor: Colors.transparent,
  //     side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
  //     onSelected: (_) => _onFilterChanged(value),
  //   );
  // }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green.shade500;
      case 'suspended': return Colors.red.shade500;
      case 'pending_kyc': return Colors.orange.shade500;
      default: return Colors.grey.shade600;
    }
  }

  Widget _buildInfoRow(String label, String? value, {bool copyable = false}) {
    final text = value?.trim().isNotEmpty == true ? value!.trim() : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          copyable
              ? SelectableText('$label: ', style: const TextStyle(fontWeight: FontWeight.w600))
              : Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: copyable
                ? SelectableText(text, style: const TextStyle(color: Colors.black87))
                : Text(text, style: const TextStyle(color: Colors.black87), overflow: TextOverflow.ellipsis),
          ),
          if (copyable && text != '-') ...[
            IconButton(
              tooltip: 'Copy $label',
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => _copyToClipboard(text, label),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
      );
    }
  }

  Widget buildApiMerchantCard(ApiMerchant apiMerchant) {
    // final statusColor = getStatusColor(ApiMerchant.status ?? 'unknown');
    final statusColor = apiMerchant.status ? Colors.green : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    apiMerchant.name ?? 'Unnamed ApiMerchant',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (apiMerchant.status ? "Active" : "InActive").toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details grid (responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth > 600;
                final details = [
                  _buildInfoRow('ID', apiMerchant.merchantId, copyable: true),
                  _buildInfoRow('Api', apiMerchant.apiSecret, copyable: true),
                  _buildInfoRow('Email', apiMerchant.email),
                  _buildInfoRow('VPA', apiMerchant.vpa, copyable: true),
                  _buildInfoRow('Daily Limit', '${apiMerchant.dailyLimit?.toString() ?? 'N/A'} QRs'),
                  _buildInfoRow('Created', apiMerchant.createdAt != null
                      ? DateFormat('dd MMM yyyy').format(DateTime.parse(apiMerchant.createdAt!))
                      : null),
                ];

                if (!twoCols) return Column(children: details);
                return Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: details.map((w) => SizedBox(width: (constraints.maxWidth - 24) / 2, child: w)).toList(),
                );
              },
            ),

            const SizedBox(height: 16),
            // Actions
            Row(
              children: [
                // Expanded(
                //   child: FilledButton.icon(
                //     onPressed: () => _showEditDialog(apiMerchant),
                //     icon: const Icon(Icons.edit, size: 16),
                //     label: const Text('Edit'),
                //   ),
                // ),
                // Text(""),
                const SizedBox(width: 12),
                apiMerchant.status ?
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showToggleDialog(apiMerchant),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Suspend'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                  ),
                ) : Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showToggleDialog(apiMerchant),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Activate'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(ApiMerchant apiMerchant) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ApiMerchantsFormPage(apiMerchant: apiMerchant)),
    );
    if (result == true && mounted) {
      _showSnackBar('✅ ApiMerchant updated successfully');
      await fetchPage(firstLoad: true);
    }
  }

  Future<void> _showToggleDialog(ApiMerchant merchant) async {  // ✅ Renamed
    final isActive = merchant.status;  // ✅ Current status
    final willSuspend = isActive;     // ✅ New status

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willSuspend ? 'Suspend Merchant' : 'Reactivate Merchant'),  // ✅ Dynamic
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant: ${merchant.name}'),
            Text('ID: ${merchant.merchantId}'),
            const SizedBox(height: 8),
            Text(willSuspend
                ? 'This will suspend the merchant and block new QR requests.'
                : 'This will reactivate the merchant and restore QR generation access.'),  // ✅ Dynamic
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: willSuspend
                  ? Colors.red.shade600
                  : Colors.green.shade600,  // ✅ Dynamic color
            ),
            onPressed: () async {
              Navigator.pop(context, true);
              await _toggleMerchant(merchant);  // ✅ Toggle call
            },
            child: Text(willSuspend ? 'Suspend' : 'Reactivate'),  // ✅ Dynamic text
          ),
        ],
      ),
    );
    }

    Future<void> _toggleMerchant(ApiMerchant merchant) async {
      try {
      await _showBlockingProgress(
          context: context,
          message: merchant.status ? 'Suspending merchant...' : 'Reactivating merchant...',  // ✅ Dynamic
          future: ApiMerchantsService.toggleMerchantStatus(  // ✅ Your toggle endpoint
          jwtToken: await AppWriteService().getJWT(),
          merchantId: merchant.merchantId!,
        ),
      );

      if (mounted) {
          _showSnackBar('✅ Merchant ${merchant.status ? 'suspended' : 'reactivated'} successfully');
          await fetchPage(firstLoad: true);  // Refresh list
        }
      } catch (e) {
        if (mounted) _showSnackBar('❌ Failed: $e');
      }
    }

  // Future<void> _deleteApiMerchant(ApiMerchant merchant) async {
  //   try {
  //     await _showBlockingProgress(
  //       context: context,
  //       message: 'Suspending ApiMerchant...',
  //       future: ApiMerchantsService.deleteApiMerchant(
  //         jwtToken: await AppWriteService().getJWT(),
  //         merchantId: merchant.merchantId!,
  //       ),
  //     );
  //     if (mounted) {
  //       _showSnackBar('✅ ApiMerchant suspended successfully');
  //       await fetchPage(firstLoad: true);
  //     }
  //   } catch (e) {
  //     if (mounted) _showSnackBar('❌ Failed to suspend ApiMerchant: $e');
  //   }
  // }

  Future<T> _showBlockingProgress<T>({
    required BuildContext context,
    required String message,
    required Future<T> future,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await future;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return result;
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      rethrow;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ApiMerchants = pageState.items;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ApiMerchants'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New ApiMerchant',
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ApiMerchantsFormPage()),
                );
                if (result == true && mounted) {
                  _showSnackBar('✅ ApiMerchant created successfully');
                  await fetchPage(firstLoad: true);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refresh,
            ),
          ],
        ),
        body: loading
            ? ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 6,
          itemBuilder: (_, __) => const ApiMerchantCardShimmer(),
        )
            : Column(
          children: [
            // Filter + Search
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // child: Row(
                    //   children: [
                    //     buildFilterChip('ALL', 'all'),
                    //     const SizedBox(width: 8),
                    //     buildFilterChip('ACTIVE', 'active'),
                    //     const SizedBox(width: 8),
                    //     buildFilterChip('SUSPENDED', 'suspended'),
                    //     const SizedBox(width: 8),
                    //     buildFilterChip('PENDING', 'pending_kyc'),
                    //   ],
                    // ),
                  ),
                  const SizedBox(height: 12),
                  // Search
                  // TextField(
                  //   decoration: InputDecoration(
                  //     hintText: 'Search ApiMerchants...',
                  //     prefixIcon: const Icon(Icons.search),
                  //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  //     suffixIcon: searchQuery != null && searchQuery!.isNotEmpty
                  //         ? IconButton(
                  //       icon: const Icon(Icons.clear),
                  //       onPressed: () => _onSearchChanged(null),
                  //     )
                  //         : null,
                  //   ),
                  //   onChanged: _onSearchChanged,
                  // ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ApiMerchants.isEmpty
                    ? const Center(child: Text('No ApiMerchants found'))
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: ApiMerchants.length + (pageState.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < ApiMerchants.length) {
                      return buildApiMerchantCard(ApiMerchants[index]);
                    }
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading more ApiMerchants...'),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApiMerchantsFormPage extends StatefulWidget {
  final ApiMerchant? apiMerchant;
  const ApiMerchantsFormPage({super.key, this.apiMerchant});

  @override
  State<ApiMerchantsFormPage> createState() => _ApiMerchantsFormPageState();
}

class _ApiMerchantsFormPageState extends State<ApiMerchantsFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // final _phoneController = TextEditingController();
  final _vpaController = TextEditingController();
  final _dailyLimitController = TextEditingController();

  bool _isLoading = false;
  bool _status = false;

  @override
  void initState() {
    super.initState();
    final m = widget.apiMerchant;
    if (m != null) {
      _nameController.text = m.name ?? '';
      _emailController.text = m.email ?? '';
      _vpaController.text = m.vpa ?? '';
      _dailyLimitController.text = m.dailyLimit?.toString() ?? '';
      _status = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    // _phoneController.dispose();
    _vpaController.dispose();
    _dailyLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.apiMerchant != null;

    // _nameController.text = 'ReddyAnna';
    // _emailController.text = 'reddyanna@kitepay.in';
    // _vpaController.text = 'reddyanna@okhdfc';
    // _dailyLimitController.text = "1000";
    // _status = true;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit ApiMerchant' : 'New ApiMerchant')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name *',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Email required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vpaController,
                  decoration: const InputDecoration(
                    labelText: 'VPA (UPI Handle) *',
                    prefixIcon: Icon(Icons.payment),
                    border: OutlineInputBorder(),
                    helperText: 'e.g., mid123@razorpay',
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'VPA required';
                    if (!RegExp(r'^[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+$').hasMatch(v!)) return 'Invalid VPA format';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dailyLimitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Daily QR Limit *',
                    prefixIcon: Icon(Icons.speed),
                    border: OutlineInputBorder(),
                    helperText: 'Max QR requests per day',
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Limit required';
                    final num = int.tryParse(v!);
                    if (num == null || num < 1 || num > 10000) return '1-10000 range';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                    Switch(
                      value: _status,
                      onChanged: _isLoading ? null : (v) => setState(() => _status = v),
                      activeColor: Colors.green.shade600,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                    Text(_status ? 'Active' : 'InActive', style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _status ? Colors.green.shade700 : Colors.red.shade700,
                    )),
                  ],
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEdit ? 'Update ApiMerchant' : 'Create ApiMerchant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {

    if (!_formKey.currentState!.validate()) return;

    print("TEST 1");

    setState(() => _isLoading = true);
    try {
      final apiMerchant = ApiMerchant(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        vpa: _vpaController.text.trim(),
        status: _status,
        dailyLimit: int.parse(_dailyLimitController.text),
      );
      print("TEST 4");

      // await ApiMerchantsService.createApiMerchant(
      //     jwtToken: await AppWriteService().getJWT(),
      //     merchant: apiMerchant,
      // );

      final result = widget.apiMerchant == null
          ? await ApiMerchantsService.createApiMerchant(
        jwtToken: await AppWriteService().getJWT(),
        merchant: apiMerchant,
      )
        : await ApiMerchantsService.updateApiMerchant(
        jwtToken: await AppWriteService().getJWT(),
        merchantId: widget.apiMerchant!.merchantId!,
        merchant: widget.apiMerchant!,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${widget.apiMerchant == null ? 'Created' : 'Updated'} successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

