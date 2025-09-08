import 'dart:async';

import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'AppWriteService.dart';
import 'QRService.dart';
import 'TransactionService.dart';
import 'UsersService.dart';
import 'models/QrCode.dart';
import 'models/Transaction.dart';

class TransactionPageNew extends StatefulWidget {
  final String? filterUserId;
  final String? filterQrCodeId;
  final String? userModeUserid;

  final bool userMode;

  const TransactionPageNew({
    super.key,
    this.filterUserId,
    this.filterQrCodeId,
    this.userModeUserid,
    this.userMode = false,
  });

  @override
  State<TransactionPageNew> createState() => _TransactionPageNewState();
}

class _TransactionPageNewState extends State<TransactionPageNew> {
  final QrCodeService _qrCodeService = QrCodeService();
  String? _jwtToken;

  // List<Transaction> allTransactions = [];
  List<Transaction> transactions = [];

  bool loading = false;
  bool loadingUsers = false;
  bool loadingQr = false;

  List<AppUser> users = [];
  List<QrCode> qrCodes = [];

  String? selectedUserId;
  String? selectedQrCodeId;

  DateTime? selectedFromDate;
  DateTime? selectedToDate;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // PAGINATION
  String? nextCursor;
  bool hasMore = true;
  bool loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  late final TextEditingController _searchController;
  Timer? _debounce;

  String? selectedSearchField;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: searchText);
    selectedUserId = widget.filterUserId;
    selectedQrCodeId = widget.filterQrCodeId;
    _scrollController.addListener(_onScroll); // PAGINATION listener
    loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> getJwtTokenFromAppWriteService() async{
    return await AppWriteService().getJWT();
  }

  Future<void> loadInitialData() async {
    setState(() {
      loading = true;
      _searchController.clear();
      transactions.clear();
      // allTransactions.clear();
      nextCursor = null; // reset for new load
      hasMore = true;
    });

    _jwtToken = await AppWriteService().getJWT();

    if (widget.userMode) {
      if (widget.filterQrCodeId == null) {
        await fetchOnlyUserQrCodes();
      }
    } else {
      if (widget.filterUserId == null && widget.filterQrCodeId == null) {
        await fetchUsersQrCodes();
      }
    }

    if (widget.userMode) {
      await fetchUserTransactions();
    } else {
      await fetchTransactions(firstLoad: true);
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  // Only Fetches User QrCodes in UserMode
  Future<void> fetchOnlyUserQrCodes() async {
    if (mounted) setState(() => loadingQr = true);
    try {
      qrCodes = await _qrCodeService.getUserQrCodes(widget.userModeUserid!);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch User Qr Codes: $e')),
      );
    }
    if (mounted) setState(() => loadingQr = false);
  }

  Future<void> fetchUsersQrCodes() async {
    if (mounted) setState(() => loadingUsers = true);

    try {
      final fetched = await AdminUserService.listUsers(jwtToken: await AppWriteService().getJWT());
      users = fetched.appUsers;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }
    if (mounted) setState(() => loadingUsers = false);

    if (mounted) setState(() => loadingQr = true);
    try {
      qrCodes = await _qrCodeService.getQrCodes(_jwtToken);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Qr Codes: $e')),
      );
    }
    if (mounted) setState(() => loadingQr = false);
  }

  Future<void> fetchTransactions({bool firstLoad = false}) async {
    if ((loadingMore && !firstLoad) || !hasMore) return;

    if (firstLoad) {
      setState(() => loading = true);
    } else {
      setState(() => loadingMore = true);
    }

    final effectiveUserId =
        widget.userMode
            ? widget.userModeUserid
            : (selectedUserId ?? widget.filterUserId);
    final effectiveQrId = selectedQrCodeId ?? widget.filterQrCodeId;

    try {
      final fetched = await TransactionService.fetchTransactions(
        userId: effectiveUserId,
        qrId: effectiveQrId,
        from: selectedFromDate,
        to: selectedToDate,
        cursor: nextCursor,
        searchField: selectedSearchField,
        searchValue: searchText.isEmpty ? null : searchText,
        jwtToken: _jwtToken!,
      );

      if (firstLoad) {
        transactions = fetched.transactions.toList();
        // for(Transaction t in transactions){
        //   print(t.toString());
        // }
      } else {
        final existingIds = transactions.map((t) => t.id).toSet();
        final newOnes = fetched.transactions.where(
          (t) => !existingIds.contains(t.id),
        );
        transactions.addAll(newOnes);
        // transactions.addAll(fetched.transactions);
      }

      nextCursor = fetched.nextCursor;
      hasMore = fetched.nextCursor != null;

      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Transactions: $e')),
      );
    }

    if (firstLoad) {
      setState(() => loading = false);
    } else {
      setState(() => loadingMore = false);
    }
  }

  Future<void> fetchUserTransactions({bool firstLoad = false}) async {
    if ((loadingMore && !firstLoad) || !hasMore) return;

    if (firstLoad) {
      setState(() => loading = true);
    } else {
      setState(() => loadingMore = true);
    }

    final effectiveQrId = selectedQrCodeId ?? widget.filterQrCodeId;

    try {
      final fetched = await TransactionService.fetchUserTransactions(
        userId: widget.userModeUserid!,
        qrId: effectiveQrId,
        from: selectedFromDate,
        to: selectedToDate,
        cursor: nextCursor,
        searchField: selectedSearchField,
        searchValue: searchText.isEmpty ? null : searchText,
        jwtToken: _jwtToken!,
      );

      if (firstLoad) {
        transactions = fetched.transactions;
      } else {
        final existingIds = transactions.map((t) => t.id).toSet();
        final newOnes = fetched.transactions.where(
          (t) => !existingIds.contains(t.id),
        );
        transactions.addAll(newOnes);
        // transactions.addAll(fetched.transactions);
      }

      nextCursor = fetched.nextCursor;
      hasMore = fetched.nextCursor != null;

      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch user Transactions: $e')),
      );
    }

    if (firstLoad) {
      setState(() => loading = false);
    } else {
      setState(() => loadingMore = false);
    }
  }

  Future<void> _refetchWithCurrentFilters() async {
    // reset pagination
    setState(() {
      transactions.clear();
      nextCursor = null;
      hasMore = true;
      loading = true;
    });

    try {
      // Use selected filters first; fall back to widget filters
      final effectiveUserId =
          widget.userMode
              ? widget.userModeUserid
              : (selectedUserId ?? widget.filterUserId);
      final effectiveQrId = selectedQrCodeId ?? widget.filterQrCodeId;

      // Call the right fetch based on userMode
      if (widget.userMode) {
        // If you have a user-specific endpoint
        final fetched = await TransactionService.fetchUserTransactions(
          userId: effectiveUserId!,
          qrId: effectiveQrId,
          from: selectedFromDate,
          to: selectedToDate,
          cursor: null,
          searchField: selectedSearchField,
          searchValue: searchText.isEmpty ? null : searchText,
          jwtToken: _jwtToken!,
        );
        transactions = fetched.transactions.toList();
        nextCursor = fetched.nextCursor;
        hasMore = fetched.nextCursor != null;
      } else {
        final fetched = await TransactionService.fetchTransactions(
          userId: effectiveUserId,
          qrId: effectiveQrId,
          cursor: null,
          from: selectedFromDate,
          to: selectedToDate,
          searchField: selectedSearchField,
          searchValue: searchText.isEmpty ? null : searchText,
          jwtToken: _jwtToken!,
        );
        transactions = fetched.transactions.toList();
        nextCursor = fetched.nextCursor;
        hasMore = fetched.nextCursor != null;
      }

      // Keep your existing filtering pass if you want to still enforce UI-side filters
      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Transactions: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void applyFilters() {
    List<Transaction> filtered = transactions; // PAGINATION: already partial

    if (widget.filterUserId != null) {
      setState(() {
        transactions = filtered.toList();
      });
      return;
    }

    if (selectedUserId != null) {
      final userQrCodeIds =
          qrCodes
              .where((qr) => qr.assignedUserId == selectedUserId)
              .map((qr) => qr.qrId)
              .whereType<String>()
              .toSet();

      if (selectedQrCodeId != null) {
        filtered =
            filtered.where((txn) => txn.qrCodeId == selectedQrCodeId).toList();
      } else {
        filtered =
            filtered
                .where((txn) => userQrCodeIds.contains(txn.qrCodeId))
                .toList();
      }
    } else if (selectedQrCodeId != null) {
      filtered =
          filtered.where((txn) => txn.qrCodeId == selectedQrCodeId).toList();
    }

    setState(() {
      transactions = filtered.toList();
    });
  }

  // PAGINATION scroll listener
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.userMode) {
        fetchUserTransactions();
      } else {
        fetchTransactions();
      }
    }
  }

  List<QrCode> get filteredQrCodes {
    if (selectedUserId == null) return qrCodes;
    return qrCodes.where((qr) => qr.assignedUserId == selectedUserId).toList();
  }

  Future<void> pickFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedFromDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(DateTime.now().year),
    );
    if (picked != null) {
      selectedFromDate = picked;
    }
  }

  Future<void> pickToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedToDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(DateTime.now().year),
    );
    if (picked != null) {
      selectedToDate = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userMode ? 'Transactions' : 'All Transactions'),
          actions: [
            // if (widget.filterUserId == null && widget.filterQrCodeId == null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    () =>
                        !widget.userMode
                            ? loadInitialData()
                            : loadInitialData(),
              ),
          ],
        ),
          body: Column(
            children: [
              // Always show search and filters when no fixed filter applied
              if (widget.filterUserId == null && widget.filterQrCodeId == null) ...[
                _buildSearchArea(), // <-- Always visible
                _buildFilters(userHasQrCodes),
              ],
              const SizedBox(height: 8),

              // Now show loader or list below
              Expanded(
                child: loading
                    ? ListView.builder(
                  itemCount: 8, // shimmer placeholders
                  itemBuilder: (_, __) => const TransactionCardShimmer(),
                )
                    : (transactions.isEmpty
                    ? const Center(child: Text('No transactions found.'))
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: transactions.length + (loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < transactions.length) {
                      return TransactionCard(txn: transactions[index]);
                    }
                    return const TransactionCardShimmer();
                  },
                )
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildSearchArea() {
    const searchFields = [
      'qrCodeId',
      'paymentId',
      'rrnNumber',
      'vpa',
      'amount',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Field',
                ),
                value: selectedSearchField,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select field')),
                  ...searchFields.map((field) => DropdownMenuItem(
                    value: field,
                    child: Text(field),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedSearchField = value;
                    // Clear input if needed
                    if ((value == 'amount' || value == 'rrnNumber') && searchText.isNotEmpty) {
                      searchText = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchController,
                keyboardType: (selectedSearchField == 'amount' || selectedSearchField == 'rrnNumber')
                    ? const TextInputType.numberWithOptions(decimal: false)
                    : TextInputType.text,
                inputFormatters: (selectedSearchField == 'amount' || selectedSearchField == 'rrnNumber')
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Search text',
                ),
                onChanged: (value) {
                  searchText = value;
                },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                // On button tap, execute search
                FocusScope.of(context).unfocus(); // close keyboard
                _refetchWithCurrentFilters();
              },
              child: const Text("Search"),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFilters(bool userHasQrCodes) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.userMode)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Filter User',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      loadingUsers
                          ? const CircularProgressIndicator()
                          : DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedUserId,
                        hint: const Text('Select User'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('--------'),
                          ),
                          ...users.map(
                                (user) => DropdownMenuItem(
                              value: user.id,
                              child: Text('${user.name} (${user.email})'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedUserId = value;
                            selectedQrCodeId = null;
                          });
                          _refetchWithCurrentFilters();
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Filter QR Code',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    loadingQr
                        ? const CircularProgressIndicator()
                        : DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedQrCodeId,
                      hint: const Text('Select QR Code'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('--------'),
                        ),
                        ...filteredQrCodes.map(
                              (qr) => DropdownMenuItem(
                            value: qr.qrId,
                            child: Text('${qr.qrId} (${qr.totalTransactions})'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedQrCodeId = value;
                        });
                        _refetchWithCurrentFilters();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 📅 Date Filters
          const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("From Date", style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedFromDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedFromDate = picked;
                                  });
                                  _refetchWithCurrentFilters();
                                }
                              },
                              child: Text(
                                selectedFromDate == null
                                    ? "Pick Date"
                                    : "${selectedFromDate!.toLocal()}".split(' ')[0],
                              ),
                            ),
                          ),
                          if (selectedFromDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  selectedFromDate = null;
                                });
                                _refetchWithCurrentFilters();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("To Date", style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedToDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedToDate = picked;
                                  });
                                  _refetchWithCurrentFilters();
                                }
                              },
                              child: Text(
                                selectedToDate == null
                                    ? "Pick Date"
                                    : "${selectedToDate!.toLocal()}".split(' ')[0],
                              ),
                            ),
                          ),
                          if (selectedToDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  selectedToDate = null;
                                });
                                _refetchWithCurrentFilters();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🔹 Clear All Dates button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text("Clear All Dates"),
                onPressed: () {
                  setState(() {
                    selectedFromDate = null;
                    selectedToDate = null;
                  });
                  _refetchWithCurrentFilters();
                },
              ),
            ),
          ],
        ),

          if (selectedUserId != null && !userHasQrCodes)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'No QR codes assigned to this user.',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildFilters(bool userHasQrCodes) {
  //   return Padding(
  //     padding: const EdgeInsets.all(8.0),
  //     child: Column(
  //       children: [
  //         Row(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             if (!widget.userMode)
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Padding(
  //                       padding: EdgeInsets.only(bottom: 4),
  //                       child: Text(
  //                         'Filter User',
  //                         style: TextStyle(fontWeight: FontWeight.bold),
  //                       ),
  //                     ),
  //                     loadingUsers
  //                         ? const CircularProgressIndicator()
  //                         : DropdownButtonFormField<String>(
  //                           isExpanded: true,
  //                           value: selectedUserId,
  //                           hint: const Text('Select User'),
  //                           items: [
  //                             const DropdownMenuItem(
  //                               value: null,
  //                               child: Text('--------'),
  //                             ),
  //                             ...users.map(
  //                               (user) => DropdownMenuItem(
  //                                 value: user.id,
  //                                 child: Text(user.name),
  //                               ),
  //                             ),
  //                           ],
  //                           onChanged: (value) {
  //                             setState(() {
  //                               selectedUserId = value;
  //                               selectedQrCodeId = null;
  //                             });
  //                             // applyFilters();
  //                             _refetchWithCurrentFilters();
  //                           },
  //                         ),
  //                   ],
  //                 ),
  //               ),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   const Padding(
  //                     padding: EdgeInsets.only(bottom: 4),
  //                     child: Text(
  //                       'Filter QR Code',
  //                       style: TextStyle(fontWeight: FontWeight.bold),
  //                     ),
  //                   ),
  //                   loadingQr
  //                       ? const CircularProgressIndicator()
  //                       : DropdownButtonFormField<String>(
  //                         isExpanded: true,
  //                         value: selectedQrCodeId,
  //                         hint: const Text('Select QR Code'),
  //                         items: [
  //                           const DropdownMenuItem(
  //                             value: null,
  //                             child: Text('--------'),
  //                           ),
  //                           ...filteredQrCodes.map(
  //                             (qr) => DropdownMenuItem(
  //                               value: qr.qrId,
  //                               child: Text('${qr.qrId} (${qr.totalTransactions})'),
  //                             ),
  //                           ),
  //                         ],
  //                         onChanged: (value) {
  //                           setState(() {
  //                             selectedQrCodeId = value;
  //                           });
  //                           // applyFilters();
  //                           // Server-side refetch for new filters
  //                           _refetchWithCurrentFilters();
  //                         },
  //                       ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //         if (selectedUserId != null && !userHasQrCodes)
  //           const Padding(
  //             padding: EdgeInsets.only(top: 10),
  //             child: Text(
  //               'No QR codes assigned to this user.',
  //               style: TextStyle(color: Colors.red),
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }


}
