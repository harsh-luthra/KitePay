import 'dart:async';

import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'AppWriteService.dart';
import 'MyMetaApi.dart';
import 'QRService.dart';
import 'SocketManager.dart';
import 'TransactionService.dart';
import 'AdminUsersService.dart';
import 'models/QrCode.dart';
import 'models/Transaction.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:number_to_indian_words/number_to_indian_words.dart';

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
      final fetched = await AdminUserService.listUsers(
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
                TransactionCard(txn: txn),
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

    if (confirm != true) return; // user canceled [1]

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
    ); // loading dialog [1][2]

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
        _refetchWithCurrentFilters(); // refresh list [3]
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
            .pop(); // ensure loader is closed [1]
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Delete failed: $e')),
        ); // feedback [3]
      }
    }
  }

  Future<void> changeTransactionStatus(BuildContext context, {
    required Transaction txn,
  }) async {
    // Local selection defaulted from txn.status String? (case-insensitive).
    TxnStatus? selected = _parseStatusOrNull(
        txn.status); // 'normal' -> TxnStatus.normal [19]

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Change status?'), // [2]
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TransactionCard(txn: txn), // existing preview [2]
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
    ); // confirm with dropdown [2][15][11]

    if (confirm != true || selected == null)
      return; // user canceled or nothing chosen [11]

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

      final ok = await TransactionService.editTransaction(
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
            if (widget.filterUserId == null &&
                widget.filterQrCodeId == null) ...[
              _buildSearchArea(), // <-- Always visible
              _buildFilters(userHasQrCodes),
            ],
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
                    return userMeta.role == 'admin' ? TransactionCard(
                        txn: transactions[index],
                        onEdit: (txn) => editTransaction(context, txn: txn),
                        onDelete: (txn) => deleteTransaction(context, txn: txn),
                        onStatus: (txn) =>
                            changeTransactionStatus(context, txn: txn))
                        : TransactionCard(txn: transactions[index]);
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
                  const DropdownMenuItem(
                      value: null, child: Text('Select field')),
                  ...searchFields.map((field) =>
                      DropdownMenuItem(
                        value: field,
                        child: Text(field),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedSearchField = value;
                    // Clear input if needed
                    if ((value == 'amount' || value == 'rrnNumber') &&
                        searchText.isNotEmpty) {
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
                keyboardType: (selectedSearchField == 'amount' ||
                    selectedSearchField == 'rrnNumber')
                    ? const TextInputType.numberWithOptions(decimal: false)
                    : TextInputType.text,
                inputFormatters: (selectedSearchField == 'amount' ||
                    selectedSearchField == 'rrnNumber')
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
                                (user) =>
                                DropdownMenuItem(
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
                              (qr) =>
                              DropdownMenuItem(
                                value: qr.qrId,
                                child: Text(
                                    '${qr.qrId} (${qr.totalTransactions})'),
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
                        const Text("From Date",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedFromDate ??
                                        DateTime.now(),
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
                                      : "${selectedFromDate!.toLocal()}".split(
                                      ' ')[0],
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
                        const Text("To Date",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedToDate ??
                                        DateTime.now(),
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
                                      : "${selectedToDate!.toLocal()}".split(
                                      ' ')[0],
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

              // Select Status
              // buildStatusFilter(),

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

  Widget buildStatusFilter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select Status
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'Filter Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        )
        , loading
            ? const CircularProgressIndicator() :
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: selectedStatus,
          hint: const Text('Select Status'),
          items: [
            const DropdownMenuItem<String>(
              value: null, // represents "ALL"
              child: Text('ALL'),
            ),
            ...TxnStatus.values.map(
                  (s) => DropdownMenuItem<String>(
                value: s.name,
                child: Text(s.name), // "normal", "cyber", ...
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => selectedStatus = value);
            print(selectedStatus);
            _refetchWithCurrentFilters();
          },
        ),
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
