import 'dart:async';

import 'package:admin_qr_manager/AppConstants.dart';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:excel/excel.dart' show Excel;
import 'package:flutter/material.dart';
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

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:number_to_indian_words/number_to_indian_words.dart';

import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';  // for date formatting
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

int? selectedMaxTxns = 50;


enum TxnStatus { normal, cyber, refund, chargeback }

extension TxnStatusX on TxnStatus {
  String get label => name; // send this to API as text [19]
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

  late IO.Socket _socket;

  StreamSubscription<Map<String, dynamic>>? _txSub;

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
    // Later, to clean up:
    _txSub?.cancel();
    disposeSocket();
    super.dispose();
  }

  Future<void> initSocket({required List<String> qrIds}) async {
    final jwt = await AppWriteService().getJWT();

    String? firstQrId = qrCodes.isNotEmpty ? qrCodes.first.qrId : null;

    firstQrId = "119188392";

    _socket = IO.io(
      // 'http://localhost:3000',
      'https://kite-pay-api-v1.onrender.com',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': jwt}) // JWT on connect [web:522]
          .enableReconnection() // auto-retry [web:522]
          .enableForceNew() // isolate this connection
          .setQuery({'v': '1'}) // optional versioning
          .build(),
    );

    _socket.onConnect((_) {
      print("Socket Connected :" + firstQrId!);
      // Send the list of qrIds as plain strings, e.g., ['119188392', ...]
      _socket.emit('subscribe:qrs', {'qrIds': [firstQrId]});
    }); // Socket.IO rooms pattern [web:493]

    _socket.onReconnect((_) {
      // Re-emit subscriptions after reconnect
      _socket.emit('subscribe:qrs', {'qrIds': [firstQrId]});
    }); // reconnection flow [web:522]

    _socket.on('txn:new', (data) {
      print(data);
      // Update UI: prepend to list, optional toast
      // Ensure this matches your event payload from server
    }); // event-driven updates [web:522]

    _socket.onError((err) {
      // Log or show a non-blocking error message
    }); // basic error handling [web:522]

    _socket.onDisconnect((_) {
      // Optionally set a flag to show "reconnecting..."
    }); // lifecycle handling [web:522]
  }

  void updateSubscriptions(List<String> qrIds) {
    if (_socket.connected) {
      _socket.emit('unsubscribe:qrs', {'qrIds': []}); // optional: clear old
      _socket.emit('subscribe:qrs', {'qrIds': qrIds});
    }
  } // dynamic room updates [web:493]

  void disposeSocket() {
    try {
      _socket.dispose();
      _socket.close();
    } catch (_) {}
  }

  Future<String> getJwtTokenFromAppWriteService() async {
    return await AppWriteService().getJWT();
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
    await initTts(); // TTS initialize
    // if (!SocketManager.instance.isConnected) {
    //   await SocketManager.instance.connect(
    //     url: 'https://kite-pay-api-v1.onrender.com',
    //     // url: 'http://localhost:3000',
    //     jwt: _jwtToken!,
    //     // qrIds: ["119188392"],
    //     qrIds: ["119188392"],
    //   );
    // } else {
    //   // SocketManager.instance.subscribeQrIds(["119188392"]);
    // }

    _txSub = SocketManager.instance.txStream.listen((event) async {
      // event: { id, qrCodeId, amountPaise, createdAtIso, ... }
      Transaction txn = Transaction.fromJson(event);
      if (mounted) {
        final String? newRrn = txn.rrnNumber; // may be null
        final bool exists = newRrn != null &&
            transactions.any((t) => (t.rrnNumber ?? '').trim() ==
                newRrn.trim());
        if (!exists) {
          // speakAmountReceived(txn.amount);
          // final amt = (txn.amount / 100).toStringAsFixed(0);
          // final message = '₹$amt received in KitePay';
          // await _tts.stop();                // avoid overlap
          // await _tts.speak(message);        // speak it
          if (!mounted) return;
          setState(() {
              transactions.insert(0, txn);
              // print(transactions[0]);
              // After duplicate check and successful insert
              // showDialog(
              //   context: context,
              //   barrierDismissible: true, // tap outside to close [1]
              //   builder: (ctx) =>
              //       AlertDialog(
              //         title: const Text('New Payment Received'),
              //         content: Column(
              //           mainAxisSize: MainAxisSize.min,
              //           children: [
              //             TransactionCard(txn: txn),
              //           ],
              //         ),
              //         actions: [
              //           TextButton(
              //             onPressed: () => Navigator.of(ctx).pop(),
              //             child: const Text('Close'),
              //           ),
              //         ],
              //       ),
              // );
            });
          }

        // setState(() {
        //   transactions.insert(0, txn); // or convert to your model then insert
        //   print(transactions[0]);
        // });

      }
    });
  }

  Future<void> loadInitialData() async {
    if (!mounted) return;

    setState(() {
        loading = true;
        _searchController.clear();
        transactions.clear();
        // allTransactions.clear();
        nextCursor = null; // reset for new load
        hasMore = true;
      });

    userMeta = (await MyMetaApi.getMyMetaData(
      jwtToken: await AppWriteService().getJWT(),
      refresh: true, // set true to force re-fetch
    ))!;

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

    // if(userMeta.role == 'admin'){
    //   socketManagerConnect();
    // }

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
        // allTransactions.clear();
        nextCursor = null; // reset for new load
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
        SnackBar(content: Text('❌ Failed to fetch User Qr Codes: $e')),
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
    _jwtToken = await AppWriteService().getJWT();
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
        // print(transactions[0].toString());
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
      if(mounted)
      setState(() => loading = false);
    } else {
      if(mounted)
      setState(() => loadingMore = false);
    }
  }

  Future<void> fetchUserTransactions({bool firstLoad = false}) async {
    _jwtToken = await AppWriteService().getJWT();
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
      if(mounted)
        setState(() => loading = false);
    } else {
      if(mounted)
        setState(() => loadingMore = false);
    }
  }

  Future<void> _refetchWithCurrentFilters() async {
    _jwtToken = await AppWriteService().getJWT();
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
          status: selectedStatus,
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
      lastDate: DateTime(DateTime
          .now()
          .year),
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
      lastDate: DateTime(DateTime
          .now()
          .year),
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
                      const SnackBar(content: Text('✅ Transaction updated')),
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _refetchWithCurrentFilters();
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('❌ Update failed: $e')),
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
                          if (v == null || v.isEmpty)
                            return 'RRN Number required';
                          if (v.length != 12)
                            return 'RRN Number must be 12 digits';
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
              SizedBox(width: 8),
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting...'),
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
      if (context.mounted) Navigator.of(context, rootNavigator: true)
          .pop(); // dismiss loader [1]

      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Transaction deleted')),
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
          SnackBar(content: Text('❌ Delete failed: $e')),
        ); // feedback
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

    if (confirm != true || selected == null)
      return; // user canceled or nothing chosen

    // Show loading dialog (modal)
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
      const AlertDialog(
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
    ); // loading modal [11][2]

    try {
      // final ok = await changeStatusApi(
      //   txnId: txn.id,
      //   status: selected!.name, // send text form [19]
      // ); // call UPDATE API

      final ok = await TransactionService.editTransactionStatus(
        id: txn.id,
        jwtToken: await AppWriteService().getJWT(),
        status: selected!.name,
      ); // call UPDATE API

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close loader [11]
      }

      if (ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Status changed to ${selected?.label}')),
          ); // success feedback
          _refetchWithCurrentFilters(); // refresh list
        }
      }
    } on TimeoutException {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Please try again.')),
        ); // timeout feedback
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Change failed: $e')),
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

    AppUser? cachedUser = MyMetaApi.cached;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userMode ? 'Transactions' : 'All Transactions'),
          actions: [
            // if (widget.filterUserId == null && widget.filterQrCodeId == null)

            // if(effectiveUserId != null || effectiveQrId != null)
            // ElevatedButton.icon(
            //   icon: const Icon(Icons.download_for_offline_outlined, size: 25,),
            //   // label: const Text('Download Txns'),
            //   label: const Text(''),
            //   onPressed: () {
            //     _showDownloadDialog();
            //     // FocusScope.of(context).unfocus();
            //     // _refetchWithCurrentFilters();
            //   },
            // ),

            // STATEMENT DOWNLOAD BUTTON IS DISABLED
            if((effectiveUserId != null || effectiveQrId != null) && cachedUser?.role == 'admin')
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
              onPressed:
                  () =>
              !widget.userMode
                  ? loadInitialData()
                  : loadInitialData(),
            ),
            // Compact switch + label

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
                    // if(compactMode){
                    //   TransactionCardCompact(txn: transactions[index]);
                    // }else{
                      return (userMeta.role == 'admin' || (userMeta.role == 'employee' && userMeta.labels.contains(AppConstants.editTransactions))) ? TransactionCard(
                          compactMode: compactMode,
                          txn: transactions[index],
                          onEdit: (txn) => editTransaction(context, txn: txn),
                          onDelete: (txn) => deleteTransaction(context, txn: txn),
                          onStatus: (txn) => changeTransactionStatus(context, txn: txn))
                          : TransactionCard(txn: transactions[index], compactMode: compactMode,);
                    // }
                    // return TransactionCard(txn: transactions[index],onEdit: (txn) => editTransaction(context, txn: txn),onDelete: (txn) => deleteTransaction(context, txn: txn),);
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
    // int? dialogMaxTxns;  // Local state for dialog

    // final effectiveUserId =
    // widget.userMode
    //     ? widget.userModeUserid
    //     : (selectedUserId ?? widget.filterUserId);
    // final effectiveQrId = selectedQrCodeId ?? widget.filterQrCodeId;
    //
    // if((effectiveUserId == null || effectiveQrId == null)){
    //   await showDialog(
    //     context: context,
    //     builder: (_) => AlertDialog(
    //       title: const Text('No UserId or QrId Selected'),
    //       content: const Text('PLease Select User'),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.pop(context),
    //           child: const Text('OK'),
    //         ),
    //       ],
    //     ),
    //   );
    //   return;
    // }

    if(transactions.isEmpty){
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
                  // const DropdownMenuItem(value: null, child: Text('All Available')),
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
      if (effectiveUserId != null) queryParams.add('userId=${effectiveUserId}');
      if (effectiveQrId != null) queryParams.add('qrId=$effectiveQrId');  // your qr filter
      if (selectedFromDate != null) queryParams.add('from=${selectedFromDate!.toIso8601String()}');
      if (selectedToDate != null) queryParams.add('to=${selectedToDate!.toIso8601String()}');
      if (selectedStatus != null) queryParams.add('status=$selectedStatus');
      if (selectedSearchField != null && selectedSearchField != null) {
        queryParams.add('searchField=$selectedSearchField');
        queryParams.add('searchValue=$searchText');
      }

      // final fetched = await TransactionService.fetchTransactions(
      //   userId: effectiveUserId,
      //   qrId: effectiveQrId,
      //   from: selectedFromDate,
      //   to: selectedToDate,
      //   cursor: nextCursor,
      //   searchField: selectedSearchField,
      //   searchValue: searchText.isEmpty ? null : searchText,
      //   jwtToken: _jwtToken!,
      // );

      // Add maxTxns
      if (selectedMaxTxns != null) {
        queryParams.add('maxTxns=$selectedMaxTxns');
      }

      final uri = Uri.parse('${AppConstants.exportTransactions}?${queryParams.join('&')}');

      // print(uri.toString());

      var _token = await AppWriteService().getJWT();

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_token',  // your auth token
      });

      if (context.mounted) Navigator.pop(context);  // close loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _generateAndDownloadExcel(data['transactions']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
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

    // Data rows
    // for (final txn in transactions) {
    //   sheet.appendRow([
    //     // DoubleCellValue((txn['amount'] ?? 0) / 100.0),  // ✅ Add .0 for double
    //     IntCellValue(((txn['amount'] ?? 0) / 100).round()),  // ✅ Whole rupees
    //     // DoubleCellValue((txn['amount'] ?? 0) / 100.round()),
    //     TextCellValue(txn['rrnNumber']?.toString() ?? ''),
    //     TextCellValue(txn['vpa']?.toString() ?? ''),
    //     TextCellValue(_formatDateTime(txn['created_at']?.toString() ?? '')),
    //     TextCellValue(txn['qrCodeId']?.toString() ?? ''),
    //     TextCellValue(txn['paymentId']?.toString() ?? ''),
    //     TextCellValue(txn['status']?.toString() ?? 'normal'),
    //     TextCellValue(txn['id']?.toString() ?? ''),
    //   ]);
    // }

    // Data rows
    for (int i = 0; i < transactions.length; i++) {
      final txn = transactions[i];
      sheet.appendRow([
        // IntCellValue(((txn['amount'] ?? 0) / 100).round()),
        // TextCellValue(NumberFormat('#,##0.00').format(((txn['amount'] ?? 0) / 100.0).roundToDouble())),
        DoubleCellValue(((txn['amount'] ?? 0) / 100.0).roundToDouble()),
        // TextCellValue('₹${((txn['amount'] ?? 0) / 100.0).roundToDouble().toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'),
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


  // 3. Generate & download Excel
  // Future<void> _generateAndDownloadExcel(List<dynamic> transactions) async {
  //   final excel = Excel.createExcel();
  //   final sheet = excel['Transaction Statement'];
  //
  //   // Headers
  //   sheet.appendRow([
  //     TextCellValue('ID'),
  //     TextCellValue('Amount (₹)'),
  //     TextCellValue('Status'),
  //     TextCellValue('Date'),
  //     TextCellValue('QR ID'),
  //     TextCellValue('Payment ID'),
  //     TextCellValue('VPA'),
  //     TextCellValue('RRN'),
  //   ]);
  //
  //   // Data rows
  //   for (final txn in transactions) {
  //     sheet.appendRow([
  //       TextCellValue(txn['id'] ?? ''),
  //       DoubleCellValue((txn['amount'] ?? 0) / 100),  // paise to rupees
  //       TextCellValue(txn['status'] ?? 'normal'),
  //       TextCellValue(_formatDateTime(txn['created_at'] ?? '')),
  //       TextCellValue(txn['qrCodeId'] ?? ''),
  //       TextCellValue(txn['paymentId'] ?? ''),
  //       TextCellValue(txn['vpa'] ?? ''),
  //       TextCellValue(txn['rrnNumber'] ?? ''),
  //     ]);
  //   }
  //
  //   // ✅ Downloads ONE file with custom name
  //   excel.save(
  //       fileName: 'txns_statement_${DateTime.now().millisecondsSinceEpoch}.xlsx'
  //   );
  //
  //   // Web download
  //   // final bytes = excel.save()!;
  //   // final blob = html.Blob([bytes]);
  //   // final url = html.Url.createObjectUrlFromBlob(blob);
  //   // final anchor = html.AnchorElement(href: url)
  //   //   ..setAttribute('download', 'txns_statement_${DateTime.now().millisecondsSinceEpoch}.xlsx')
  //   //   ..click();
  //   // html.Url.revokeObjectUrl(url);
  // }
  //
  // String _formatDateTime(String isoString) {
  //   final date = DateTime.parse(isoString);
  //   return DateFormat('MMM dd, yyyy HH:mm').format(date.toLocal());
  // }


  Widget _buildSearchArea() {
    const searchFields = ['qrCodeId', 'paymentId', 'rrnNumber', 'vpa', 'amount'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

            // Status row (optional)
            // buildStatusFilter(),

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
    final statuses = ['normal', 'cyber', 'refund', 'chargeback'];
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
