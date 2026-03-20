import 'dart:async';

import 'package:admin_qr_manager/AppConstants.dart';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:admin_qr_manager/widget/TransactionImageDialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'AppWriteService.dart';
import 'MyMetaApi.dart';
import 'QRService.dart';
import 'SocketManager.dart';
import 'TransactionService.dart';
import 'UsersService.dart';
import 'models/QrCode.dart';
import 'models/Transaction.dart';

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:number_to_indian_words/number_to_indian_words.dart';

import 'package:excel/excel.dart';
// for date formatting
import 'package:http/http.dart' as http;
import 'dart:convert';

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

extension TxnStatusX on TxnStatus {
  String get label => name;
}

class _TransactionPageNewState extends State<TransactionPageNew> {
  final QrCodeService _qrCodeService = QrCodeService();

  List<Transaction> transactions = [];

  int? selectedMaxTxns = 50;

  bool loading = false;
  bool loadingUsers = false;
  bool loadingQr = false;

  List<AppUser> users = [];
  List<QrCode> qrCodes = [];

  String? selectedUserId;
  String? selectedQrCodeId;

  DateTime? selectedFromDate;
  DateTime? selectedToDate;

  String? selectedStatus;

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

  late AppUser userMeta;

  StreamSubscription<Map<String, dynamic>>? _txSub;
  StreamSubscription<Map<String, dynamic>>? _txStatusChangeSub;

  final AudioPlayer _sfx = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  final FlutterTts _tts = FlutterTts();

  bool showingFilters = false;
  bool compactMode = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: searchText);
    selectedUserId = widget.filterUserId;
    selectedQrCodeId = widget.filterQrCodeId;
    _scrollController.addListener(_onScroll); // PAGINATION listener
    loadInitialData();
  }

  Future<void> initTts() async {
    await _tts.setLanguage('en-IN'); // or 'en-US' etc.
    await _tts.setSpeechRate(0.9); // 0.0–1.0
    await _tts.setPitch(1.0); // 0.5–2.0
    // Optional handlers
    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(() {});
    _tts.setErrorHandler((msg) {
      /* log */
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    _txSub?.cancel();
    _txStatusChangeSub?.cancel();
    super.dispose();
  }

  Future<void> _playNewTxnSound() async {
    try {
      await _sfx.play(
          AssetSource('sounds/ding.mp3')); // looks under assets/ [2]
    } catch (e) {
      // ignore or log
    }
  }

  String amountToWordsIndian(int amountPaise) {
    final rupees = amountPaise ~/ 100;
    final words = NumToWords.convertNumberToIndianWords(
        rupees); // uses lakh/crore style [6]
    return words.toLowerCase();
  }

  Future<void> speakAmountReceived(int amountPaise) async {
    await _tts.setLanguage('en-IN'); // Indian English accent [18]
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);

    final words = amountToWordsIndian(
        amountPaise); // 125.00 INR -> "one hundred twenty five" [9]
    final sentence = '₹$words received in KitePay';
    await _tts.speak(sentence); // say full words, not digits [18]
  }

  void socketManagerConnect() async {
    await initTts();

    _txSub = SocketManager.instance.txStream.listen((event) async {
      Transaction txn = Transaction.fromJson(event);
      if (!mounted) return;
      final String newRrn = txn.rrnNumber;
      final bool exists = transactions.any((t) => (t.rrnNumber ?? '').trim() == newRrn.trim());
      if (!exists) {
        if (!mounted) return;
        setState(() {
          transactions.insert(0, txn);
        });
      }
    });

    _txStatusChangeSub = SocketManager.instance.txStatusChangeStream.listen((event) async {
      if (!mounted) return;
      final txnId = (event['txnId'] ?? '') as String;
      final newStatus = (event['newStatus'] ?? '') as String;
      if (txnId.isEmpty) return;
      final idx = transactions.indexWhere((t) => t.id == txnId);
      if (idx != -1) {
        final old = transactions[idx];
        setState(() {
          transactions[idx] = Transaction(
            id: old.id,
            qrCodeId: old.qrCodeId,
            paymentId: old.paymentId,
            rrnNumber: old.rrnNumber,
            vpa: old.vpa,
            createdAt: old.createdAt,
            amount: old.amount,
            status: newStatus,
            imageUrl: old.imageUrl,
          );
        });
      }
    });
  }

  Future<void> loadInitialData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      _searchController.clear();
      transactions.clear();
      nextCursor = null;
      hasMore = true;
    });

    final meta = await MyMetaApi.getMyMetaData(
      jwtToken: await AppWriteService().getJWT(),
      refresh: true,
    );
    if (meta == null) throw Exception('Failed to load user metadata');
    userMeta = meta;

    if (widget.userMode) {
      if (widget.filterQrCodeId == null) {
        await fetchOnlyUserQrCodes();
      }
    } else {
      if (widget.filterUserId == null && widget.filterQrCodeId == null) {
        await fetchUsersQrCodes();
      }
    }

    socketManagerConnect();

    if (widget.userMode) {
      await fetchUserTransactions();
    } else {
      await fetchTransactions(firstLoad: true);
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> refreshTransactionsOnly() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      _searchController.clear();
      transactions.clear();
      nextCursor = null;
      hasMore = true;
    });

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
      qrCodes = await _qrCodeService.getUserQrCodes(
          widget.userModeUserid!, await AppWriteService().getJWT());
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch user QR codes: $e')),
      );
    }
    if (mounted) setState(() => loadingQr = false);
  }

  Future<void> fetchUsersQrCodes() async {
    if (mounted) setState(() => loadingUsers = true);

    try {
      final fetched = await UsersService.listUsers(
          jwtToken: await AppWriteService().getJWT());
      users = fetched.appUsers;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch users: $e')),
      );
    }
    if (mounted) setState(() => loadingUsers = false);

    if (mounted) setState(() => loadingQr = true);
    try {
      qrCodes = await _qrCodeService.getQrCodes(await AppWriteService().getJWT());
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch QR codes: $e')),
      );
    }
    if (mounted) setState(() => loadingQr = false);
  }

  Future<void> fetchTransactions({bool firstLoad = false}) async {
    if ((loadingMore && !firstLoad) || !hasMore) return;
    final jwt = await AppWriteService().getJWT();

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
        jwtToken: jwt,
      );

      if (firstLoad) {
        transactions = fetched.transactions.toList();
      } else {
        final existingIds = transactions.map((t) => t.id).toSet();
        final newOnes = fetched.transactions.where(
              (t) => !existingIds.contains(t.id),
        );
        transactions.addAll(newOnes);
      }

      nextCursor = fetched.nextCursor;
      hasMore = fetched.nextCursor != null;

      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch transactions: $e')),
      );
    }

    if (firstLoad) {
      if (mounted) setState(() => loading = false);
    } else {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> fetchUserTransactions({bool firstLoad = false}) async {
    if ((loadingMore && !firstLoad) || !hasMore) return;
    final jwt = await AppWriteService().getJWT();

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
        jwtToken: jwt,
      );

      if (firstLoad) {
        transactions = fetched.transactions;
      } else {
        final existingIds = transactions.map((t) => t.id).toSet();
        final newOnes = fetched.transactions.where(
              (t) => !existingIds.contains(t.id),
        );
        transactions.addAll(newOnes);
      }

      nextCursor = fetched.nextCursor;
      hasMore = fetched.nextCursor != null;

      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch user transactions: $e')),
      );
    }

    if (firstLoad) {
      if (mounted) setState(() => loading = false);
    } else {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _refetchWithCurrentFilters() async {
    final jwt = await AppWriteService().getJWT();
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
          status: selectedStatus,
          cursor: null,
          searchField: selectedSearchField,
          searchValue: searchText.isEmpty ? null : searchText,
          jwtToken: jwt,
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
          status: selectedStatus,
          searchField: selectedSearchField,
          searchValue: searchText.isEmpty ? null : searchText,
          jwtToken: jwt,
        );
        transactions = fetched.transactions.toList();
        nextCursor = fetched.nextCursor;
        hasMore = fetched.nextCursor != null;
      }

      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch transactions: $e')),
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
      lastDate: DateTime.now(),
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
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      selectedToDate = picked;
    }
  }

  Future<void> editTransaction(BuildContext context, {
    required Transaction txn,
  }) async {
    final formKey = GlobalKey<FormState>();

    // Local state
    String? selectedUserId;
    String? selectedQrCodeId = txn
        .qrCodeId; // UI selection; may temporarily become null
    final qrIdController = TextEditingController(
        text: txn.qrCodeId); // actual value used in payload
    final rrnController = TextEditingController(text: txn.rrnNumber);
    final amountController = TextEditingController(
      text: (txn.amount / 100).toStringAsFixed(0),
    );
    final isoDateController = TextEditingController(
      text: DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt.toLocal()),
    );

    String isoUtcValue = txn.createdAt.toUtc().toIso8601String();
    bool loading = false;

    List<QrCode> filteredQrCodes() {
      if (selectedUserId == null) return qrCodes;
      return qrCodes.where((qr) => qr.assignedUserId == selectedUserId)
          .toList();
    }

    List<String> filteredUniqueQrIds() {
      // unique, non-empty ids for dropdown items
      return filteredQrCodes()
          .map((qr) => qr.qrId ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    }

    Future<void> pickDateTime() async {
      final initialLocal = txn.createdAt.toLocal();
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: initialLocal,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialLocal),
      );
      if (pickedTime == null) return;

      final local = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      final utc = local.toUtc();
      isoUtcValue = utc.toIso8601String();
      isoDateController.text = DateFormat('dd MMM yyyy, hh:mm a').format(local);
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // Ensure dropdown value is valid against current filter
            final ids = filteredUniqueQrIds();
            final effectiveSelectedQr =
            (selectedQrCodeId != null && ids.contains(selectedQrCodeId))
                ? selectedQrCodeId
                : null; // reset dropdown only [1][2]

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setState(() => loading = true);

              final payload = <String, dynamic>{};

              final newQrId = qrIdController.text.trim();
              if (newQrId.isNotEmpty && newQrId != txn.qrCodeId) {
                payload['qrCodeId'] = newQrId;
              }

              final newRrn = rrnController.text.trim();
              if (newRrn.isNotEmpty && newRrn != txn.rrnNumber) {
                payload['rrnNumber'] = newRrn;
              }

              final amountStr = amountController.text.trim();
              final parsedAmount = double.tryParse(amountStr);
              if (parsedAmount != null &&
                  parsedAmount >= 0 &&
                  parsedAmount.toStringAsFixed(2) !=
                      (txn.amount / 100).toStringAsFixed(2)) {
                payload['amount'] =
                    parsedAmount; // rupees; backend converts [6]
              }

              if (isoUtcValue != txn.createdAt.toUtc().toIso8601String()) {
                payload['isoDate'] = isoUtcValue; // ISO-8601 UTC [6]
              }

              if (payload.isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }

              try {
                final ok = await TransactionService.editTransaction(
                  id: txn.id,
                  qrCodeId: payload['qrCodeId'],
                  rrnNumber: payload['rrnNumber'],
                  amount: payload['amount'],
                  isoDate: payload['isoDate'],
                  jwtToken: await AppWriteService().getJWT(),
                );
                if (ok) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Transaction updated')),
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _refetchWithCurrentFilters();
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Update failed: $e')),
                  );
                }
              } finally {
                if (ctx.mounted) setState(() => loading = false);
              }
            }

            return AlertDialog(
              title: const Text('Edit Transaction'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Filter Qr Codes by User'),
                      // Optional user filter
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedUserId,
                        hint: const Text('Filter by User (optional)'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('--------'),
                          ),
                          ...users.map(
                                (u) =>
                                DropdownMenuItem<String>(
                                  value: u.id,
                                  child: Text('${u.name} (${u.email})'),
                                ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            selectedUserId = v;
                            // Re-validate selection against new filter; do not change controller
                            final newIds = filteredUniqueQrIds();
                            if (selectedQrCodeId != null &&
                                !newIds.contains(selectedQrCodeId)) {
                              selectedQrCodeId = null; // UI resets [3][4]
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // QR select
                      Text('Select QR Code'),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: effectiveSelectedQr,
                        // may be null -> shows '--------' [1]
                        hint: const Text('Select QR Code'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('--------'),
                          ),
                          ...ids.map(
                                (id) =>
                                DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(id),
                                ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            selectedQrCodeId = v; // UI selection
                            if (v != null && v.isNotEmpty) {
                              qrIdController.text =
                                  v; // update actual field only on explicit select [1]
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: qrIdController,
                        decoration:
                        const InputDecoration(labelText: 'QR Code ID'),
                        readOnly: true,
                        enableInteractiveSelection: false,
                        showCursor: false,
                        validator: (v) =>
                        (v == null || v.isEmpty)
                            ? 'QR Code ID required'
                            : null,
                        onTap: () => FocusScope.of(ctx).unfocus(),
                      ),
                      TextFormField(
                        controller: rrnController,
                        decoration:
                        const InputDecoration(labelText: 'RRN Number'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'RRN Number required';
                          }
                          if (v.length != 12) {
                            return 'RRN Number must be 12 digits';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: amountController,
                        decoration:
                        const InputDecoration(labelText: 'Amount (₹)'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Amount required';
                          final n = double.tryParse(v);
                          if (n == null || n < 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: isoDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Transaction Date & Time',
                          hintText: 'Select date & time',
                        ),
                        validator: (v) =>
                        (v == null || v.isEmpty)
                            ? 'Date & Time required'
                            : null,
                        onTap: pickDateTime,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: loading ? null : submit,
                  icon: const Icon(Icons.save),
                  label: loading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> deleteTransaction(BuildContext context, {
    required Transaction txn,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Delete transaction?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TransactionCard(txn: txn,compactMode: false,),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Yes, delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
    ); // confirm dialog [1][2]

    if (confirm != true) return; // user canceled

    // Show loading dialog (modal)
    showDialog<void>(
      context: context,
      barrierDismissible: false, // block touches while deleting
      builder: (ctx) =>
      const AlertDialog(
        content: SizedBox(
          height: 56,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Text('Deleting...'),
            ],
          ),
        ),
      ),
    ); // loading dialog

    try {
      final ok = await TransactionService.deleteTransaction(
        id: txn.id,
        jwtToken: await AppWriteService().getJWT(),
      ); // call DELETE API [3]

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
          .pop(); // dismiss loader [1]
      }

      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        ); // feedback [3]
        _refetchWithCurrentFilters(); // refresh list
      }
    } on TimeoutException {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pop(); // ensure loader is closed [1]
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Please try again.')),
        ); // feedback [3]
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pop(); // ensure loader is closed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        ); // feedback
      }
    }
  }

  Future<void> viewTransactionImage(
      BuildContext context, {
        required Transaction txn,
        required Widget headerWidget, // your custom widget passed from outside
      }) async {
    final String? imageLink = txn.imageUrl;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (ctx) => TransactionImageDialog(
        imageUrl: imageLink,
        headerWidget: headerWidget,
      ),
    );
  }

  Future<void> onTransactionImageDelete(BuildContext context, {
    required Transaction txn,
  }) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent dismissing during operation
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deleting image...', style: Theme.of(context).textTheme.titleMedium),
                Text('Please wait', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );

    try {
      final success = await TransactionService.deleteTransactionImage(
        txnId: txn.id,
        jwtToken: await AppWriteService().getJWT(),
      );

      // Always dismiss progress dialog first
      Navigator.of(context).pop();  // Close progress dialog

      if (success) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
        setState(() {});  // Refresh UI
      } else {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Failed to delete transaction image')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();  // Ensure dialog closes on error
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally{
      _refetchWithCurrentFilters();
    }
  }

  Future<void> onTransactionImageUpload(BuildContext context, {
    required Transaction txn,
  }) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );

    if (result != null) {
      PlatformFile file = result.files.first;

      // 2. Show progress during entire operation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.95),
                borderRadius: BorderRadius.circular(24),
                border: material.Border.all(
                  color: Colors.white.withValues(alpha:0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.1),
                    blurRadius: 40,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Uploading Txn Image File',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Processing your file upload...',
                    style: TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: null,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      String txnId = txn.id;

      try {
        final jwt = await AppWriteService().getJWT();
        bool success = await TransactionService.uploadTransactionImage(
            file, txnId, jwt);
        Navigator.pop(context); // Close loader
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction Image uploaded successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload Transaction Image.')),
          );
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        _refetchWithCurrentFilters();
      }
    }
  }

  Future<void> changeTransactionStatus(BuildContext context, {
    required Transaction txn,
  }) async {
    // Local selection defaulted from txn.status String? (case-insensitive).
    TxnStatus? selected = _parseStatusOrNull(
        txn.status); // 'normal' -> TxnStatus.normal

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Change status?'), //
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TransactionCard(txn: txn, compactMode: false,), // existing preview
                  const SizedBox(height: 12),
                  DropdownButton<TxnStatus>(
                    value: selected,
                    hint: const Text('Select new status'),
                    isExpanded: true,
                    items: TxnStatus.values
                        .map((s) =>
                        DropdownMenuItem<TxnStatus>(
                          value: s,
                          child: Text(s.label),
                        ))
                        .toList(),
                    // enum -> dropdown items [15]
                    onChanged: (v) => setState(() => selected = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Change'),
                  onPressed: selected == null
                      ? null
                      : () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        );
      },
    ); // confirm with dropdown

    if (confirm != true || selected == null) {
      return; // user canceled or nothing chosen
    }

    // Show loading dialog (modal) and capture its navigator for reliable dismissal
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: SizedBox(
          height: 56,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8),
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating status...'),
            ],
          ),
        ),
      ),
    );
    final rootNav = Navigator.of(context, rootNavigator: true);
    rootNav.push(dialogRoute);

    void closeLoader() {
      if (dialogRoute.isActive) rootNav.removeRoute(dialogRoute);
    }

    try {
      final ok = await TransactionService.editTransactionStatus(
        id: txn.id,
        jwtToken: await AppWriteService().getJWT(),
        status: selected!.name,
      ); // call UPDATE API

      closeLoader();

      if (ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status changed to ${selected?.label}')),
          ); // success feedback
          _refetchWithCurrentFilters(); // refresh list
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status update failed.')),
          );
        }
      }
    } on TimeoutException {
      closeLoader();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Please try again.')),
        ); // timeout feedback
      }
    } catch (e) {
      closeLoader();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Change failed: $e')),
        ); // error feedback
      }
    }
  }

  // Case-insensitive parse from String? to enum, returns null when unknown.
  TxnStatus? _parseStatusOrNull(String? raw) {
    if (raw == null) return null;
    final lower = raw.toLowerCase();
    for (final s in TxnStatus.values) {
      if (s.name == lower) return s;
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    final effectiveUserId =
    widget.userMode
        ? widget.userModeUserid
        : (selectedUserId ?? widget.filterUserId);
    final effectiveQrId = selectedQrCodeId ?? widget.filterQrCodeId;

    AppUser? cachedUser = MyMetaApi.current;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userMode ? 'Transactions' : 'All Transactions'),
          actions: [
            // if((effectiveUserId != null || effectiveQrId != null) && cachedUser?.role == 'admin')
              if((effectiveUserId != null || effectiveQrId != null))
            IconButton(onPressed: loading ? null : _showDownloadDialog, icon: const Icon(Icons.download, size: 35,),),

            const SizedBox(width: 8),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filters: '),
                Switch.adaptive(
                  value: showingFilters,
                  onChanged: (val) => setState(() => showingFilters = val),
                ),
              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Compact: '),
                Switch.adaptive(
                  value: compactMode,
                  onChanged: (val) => setState(() => compactMode = val),
                ),
              ],
            ),

            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadInitialData,
            ),
          ],
        ),
        body: Column(
          children: [
            // Always show search and filters when no fixed filter applied
            if (widget.filterUserId == null &&
                widget.filterQrCodeId == null) ...[
              if(showingFilters)
              _buildSearchArea(), // <-- Always visible
              if(showingFilters)
              _buildFilters(userHasQrCodes),
            ],
            if(showingFilters)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: buildStatusFilter(),
            ),
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
                      return (userMeta.role == 'admin' || (userMeta.role == 'employee' && userMeta.labels.contains(AppConstants.editTransactions))) ?
                      TransactionCard(
                          compactMode: compactMode,
                          txn: transactions[index],
                          onEdit: (txn) => editTransaction(context, txn: txn),
                          onDelete: (txn) => deleteTransaction(context, txn: txn),
                          onStatus: (txn) => changeTransactionStatus(context, txn: txn),
                          onViewProof: (txn) => viewTransactionImage(context, txn: txn, headerWidget: TransactionCard( compactMode: compactMode,
                            txn: transactions[index],)),
                          onUploadImage: userMeta.role == 'admin'
                            ? (txn) => onTransactionImageUpload(context, txn: txn)
                            : null,  // Null disables the action in TransactionCard
                          onDeleteImage: (userMeta.role == 'admin' && transactions[index].imageUrl != '')
                            ? (txn) => onTransactionImageDelete(context, txn: txn)
                            : null,
                          )
                          : TransactionCard(txn: transactions[index], compactMode: compactMode, onViewProof: (txn) => viewTransactionImage(context, txn: txn, headerWidget: TransactionCard( compactMode: compactMode,
                        txn: transactions[index],)),);
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

  Future<void> _showDownloadDialog() async {
    if (transactions.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Transactions'),
          content: const Text('No transactions match your current filters.\nTry adjusting date range or other filters.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(  // ← ADD THIS
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Download Statement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select maximum transactions:'),
              DropdownButton<int?>(
                value: selectedMaxTxns,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: 50, child: Text('Last 50')),
                  const DropdownMenuItem(value: 100, child: Text('Last 100')),
                  const DropdownMenuItem(value: 200, child: Text('Last 200')),
                  const DropdownMenuItem(value: 500, child: Text('Last 500')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedMaxTxns = value);  // ← Local setState
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedMaxTxns != null ? () {
                Navigator.pop(ctx);
                _downloadExcel();  // Pass selected value
              } : null,
              child: const Text('Download Excel'),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Call your existing API with current filters + maxTxns
  Future<void> _downloadExcel() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Generating Excel...'),
        ]),
      ),
    );

    try {
      final queryParams = <String>[];

      final effectiveUserId =
      widget.userMode
          ? widget.userModeUserid
          : (selectedUserId ?? widget.filterUserId);
      final effectiveQrId = selectedQrCodeId ?? widget.filterQrCodeId;

      // ADD YOUR EXISTING FILTERS HERE (reuse current state)
      if (effectiveUserId != null) queryParams.add('userId=$effectiveUserId');
      if (effectiveQrId != null) queryParams.add('qrId=$effectiveQrId');  // your qr filter
      if (selectedFromDate != null) queryParams.add('from=${selectedFromDate!.toIso8601String()}');
      if (selectedToDate != null) queryParams.add('to=${selectedToDate!.toIso8601String()}');
      if (selectedStatus != null) queryParams.add('status=$selectedStatus');
      if (selectedSearchField != null && searchText.isNotEmpty) {
        queryParams.add('searchField=$selectedSearchField');
        queryParams.add('searchValue=$searchText');
      }

      // Add maxTxns
      if (selectedMaxTxns != null) {
        queryParams.add('maxTxns=$selectedMaxTxns');
      }

      final uri = Uri.parse('${AppConstants.exportTransactions}?${queryParams.join('&')}');
      var token = await AppWriteService().getJWT();

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',  // your auth token
      });

      if (context.mounted) Navigator.pop(context);  // close loading

      print(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _generateAndDownloadExcel(data['transactions']);
      } else {
        String errorMsg = 'Export failed';
        try {
          final body = jsonDecode(response.body);
          errorMsg = body['error'] ?? errorMsg;
        } catch (_) {}
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
              title: const Text('Export Failed'),
              content: Text(errorMsg),
              actions: [
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
            title: const Text('Download Failed'),
            content: Text(e.toString()),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  // 3. Generate & download Excel
  Future<void> _generateAndDownloadExcel(List<dynamic> transactions) async {
    final excel = Excel.createExcel();

    final sheet = excel['Transaction Statement'];

    // ✅ Remove default Sheet1
    excel.delete('Sheet1');

    // Headers
    sheet.appendRow([
      TextCellValue('Amount (₹)'),
      TextCellValue('RRN'),
      TextCellValue('VPA'),
      TextCellValue('Date'),
      TextCellValue('QR ID'),
      TextCellValue('Payment ID'),
      TextCellValue('Status'),
      TextCellValue('Txn ID'),
    ]);

    // Style headers - right align + bold
    for (int col = 0; col < 8; col++) {
      final headerCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      headerCell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Right,
        bold: true,
        fontSize: 12,
      );
    }

    for (int i = 0; i < transactions.length; i++) {
      final txn = transactions[i];
      sheet.appendRow([
        DoubleCellValue(((txn['amount'] ?? 0) / 100.0).roundToDouble()),
        TextCellValue(txn['rrnNumber']?.toString() ?? ''),
        TextCellValue(txn['vpa']?.toString() ?? ''),
        TextCellValue(_formatDateTime(txn['created_at']?.toString() ?? '')),
        TextCellValue(txn['qrCodeId']?.toString() ?? ''),
        TextCellValue(txn['paymentId']?.toString() ?? ''),
        TextCellValue(txn['status']?.toString() ?? 'normal'),
        TextCellValue(txn['id']?.toString() ?? ''),
      ]);

      // Right align all data cells (Row i+1)
      for (int col = 0; col < 8; col++) {
        final dataCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1));
        dataCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Right);
      }
    }

    // ✅ Single download
    excel.save(
        fileName: 'txns_statement_${DateTime.now().millisecondsSinceEpoch}.xlsx'
    );
  }

// ✅ Add this helper method if missing
  String _formatDateTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('MMM dd, yyyy hh:mm a').format(date.toLocal());  // ✅ AM/PM
    } catch (e) {
      return isoString;
    }
  }


  Widget _buildSearchArea() {
    const searchFields = ['qrCodeId', 'paymentId', 'rrnNumber', 'vpa', 'amount'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.search, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Field',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: selectedSearchField,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select field')),
                      ...searchFields.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedSearchField = value;
                        if ((value == 'amount' || value == 'rrnNumber') && searchText.isNotEmpty) {
                          searchText = '';
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    keyboardType: (selectedSearchField == 'amount' || selectedSearchField == 'rrnNumber')
                        ? const TextInputType.numberWithOptions(decimal: false)
                        : TextInputType.text,
                    inputFormatters: (selectedSearchField == 'amount' || selectedSearchField == 'rrnNumber')
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Search text',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: searchText.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            searchText = '';
                            _searchController.clear();
                          });
                          _refetchWithCurrentFilters();
                        },
                      )
                          : null,
                    ),
                    onChanged: (value) => searchText = value,
                    onSubmitted: (_) => _refetchWithCurrentFilters(),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search'),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _refetchWithCurrentFilters();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool userHasQrCodes) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.filter_alt_outlined, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),

            // Top row: User + QR
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!widget.userMode)
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Filter User', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        loadingUsers
                            ? const LinearProgressIndicator(minHeight: 2)
                            : DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedUserId,
                          hint: const Text('Select User'),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('--------')),
                            ...users.map(
                                  (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.name} (${u.email})', overflow: TextOverflow.ellipsis),
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
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('Filter QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      loadingQr
                          ? const LinearProgressIndicator(minHeight: 2)
                          : DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedQrCodeId,
                        hint: const Text('Select QR Code'),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('--------')),
                          ...filteredQrCodes.map(
                                (qr) => DropdownMenuItem(
                              value: qr.qrId,
                              child: Text('${qr.qrId} (${qr.totalTransactions})', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedQrCodeId = value);
                          _refetchWithCurrentFilters();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date range row
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _datePickerChip(
                    label: 'From',
                    date: selectedFromDate,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedFromDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedFromDate = picked);
                        _refetchWithCurrentFilters();
                      }
                    },
                    onClear: () {
                      setState(() => selectedFromDate = null);
                      _refetchWithCurrentFilters();
                    },
                  ),
                  _datePickerChip(
                    label: 'To',
                    date: selectedToDate,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedToDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedToDate = picked);
                        _refetchWithCurrentFilters();
                      }
                    },
                    onClear: () {
                      setState(() => selectedToDate = null);
                      _refetchWithCurrentFilters();
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear Dates'),
                    onPressed: () {
                      setState(() {
                        selectedFromDate = null;
                        selectedToDate = null;
                      });
                      _refetchWithCurrentFilters();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (selectedUserId != null && !userHasQrCodes)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No QR codes assigned to this user.', style: TextStyle(color: Colors.red)),
                ),
              ),

            const SizedBox(height: 10),
            // Footer actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      selectedUserId = null;
                      selectedQrCodeId = null;
                      selectedFromDate = null;
                      selectedToDate = null;
                      selectedStatus = null;
                      selectedSearchField = null;
                      searchText = '';
                      _searchController.clear();
                    });
                    _refetchWithCurrentFilters();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply'),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _refetchWithCurrentFilters();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerChip({
    required String label,
    required DateTime? date,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final text = date == null ? 'Pick $label' : DateFormat('yyyy-MM-dd').format(date.toLocal());
    return InputChip(
      label: Text('$label: $text'),
      avatar: const Icon(Icons.date_range, size: 18),
      onPressed: onPick,
      onDeleted: date != null ? onClear : null,
    );
  }

  Widget buildStatusFilter() {
    final statuses = ['normal', 'cyber', 'refund', 'chargeback', 'failed'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Text('Filter Status', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ChoiceChip(
          label: const Text('ALL'),
          selected: selectedStatus == null,
          onSelected: (_) => setState(() {
            selectedStatus = null;
            _refetchWithCurrentFilters();
          }),
        ),
        ...statuses.map((s) => ChoiceChip(
          label: Text(s),
          selected: selectedStatus == s,
          onSelected: (_) => setState(() {
            selectedStatus = s;
            _refetchWithCurrentFilters();
          }),
        )),
      ],
    );
  }

}
