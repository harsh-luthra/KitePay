import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  List<Transaction> allTransactions = [];
  List<Transaction> transactions = [];

  bool loading = false;
  bool loadingUsers = false;
  bool loadingQr = false;

  List<AppUser> users = [];
  List<QrCode> qrCodes = [];

  String? selectedUserId;
  String? selectedQrCodeId;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // PAGINATION
  String? nextCursor;
  bool hasMore = true;
  bool loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedUserId = widget.filterUserId;
    selectedQrCodeId = widget.filterQrCodeId;
    _scrollController.addListener(_onScroll); // PAGINATION listener
    loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    setState(() {
      loading = true;
      transactions.clear();
      allTransactions.clear();
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
      users = await AdminUserService.listUsers(
        await AppWriteService().getJWT(),
      );
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
        cursor: nextCursor,
        jwtToken: _jwtToken!,
      );

      if (firstLoad) {
        transactions = fetched.transactions.toList();
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
        cursor: nextCursor,
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
          cursor: null,
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

  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userMode ? 'Transactions' : 'All Transactions'),
          actions: [
            if (widget.filterUserId == null && widget.filterQrCodeId == null)
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
        body:
            loading
                ? ListView.builder(
                  itemCount: 8, // show a few shimmer placeholders
                  itemBuilder: (_, __) => const TransactionCardShimmer(),
                )
                : Column(
                  children: [
                    if (widget.filterUserId == null &&
                        widget.filterQrCodeId == null)
                      _buildFilters(userHasQrCodes),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          transactions.isEmpty
                              ? const Center(
                                child: Text('No transactions found.'),
                              )
                              : ListView.builder(
                                controller: _scrollController, // PAGINATION
                                itemCount:
                                    transactions.length + (loadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index < transactions.length) {
                                    return TransactionCard(
                                      txn: transactions[index],
                                    );
                                  } else {
                                    // Loader at bottom
                                    return const TransactionCardShimmer();
                                  }
                                },
                              ),
                    ),
                  ],
                ),
      ),
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
                                  child: Text(user.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedUserId = value;
                                selectedQrCodeId = null;
                              });
                              // applyFilters();
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
                                child: Text(qr.qrId ?? qr.assignedUserId ?? ''),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedQrCodeId = value;
                            });
                            // applyFilters();
                            // Server-side refetch for new filters
                            _refetchWithCurrentFilters();
                          },
                        ),
                  ],
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
}
