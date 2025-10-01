import 'dart:async';
import 'dart:convert';

import 'package:admin_qr_manager/ManualTransactionForm.dart';
import 'package:admin_qr_manager/QRService.dart';
import 'package:admin_qr_manager/SocketTest.dart';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' show User;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:number_to_indian_words/number_to_indian_words.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AppConfig.dart';
import 'AppConstants.dart';
import 'AppWriteService.dart';
import 'ManageUsersScreen.dart';
import 'ManageQrScreen.dart';
import 'ManageWithdrawalsNew.dart';
import 'MemberShipPlansScreen.dart';
import 'MyMetaApi.dart';
import 'SocketManager.dart';
import 'TransactionPageNew.dart';
import 'UserDashboardScreen.dart';
import 'WithdrawalFormPage.dart';
import 'adminLoginPage.dart';
import 'package:http/http.dart' as http;

import 'main.dart';
import 'models/QrCode.dart';
import 'models/Transaction.dart';

class DashboardScreenNew extends StatefulWidget {
  final User user;
  final AppUser userMeta;

  const DashboardScreenNew({super.key, required this.user, required this.userMeta});

  @override
  State<DashboardScreenNew> createState() => _DashboardScreenNewState();
}

// final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class _DashboardScreenNewState extends State<DashboardScreenNew> {
  final AppWriteService _appWriteService = AppWriteService();

  // Paint/interaction state
  bool _sidebarCollapsed = false;
  int _activeIndex = 0;
  final Map<int, bool> _hovering = {};

  // Responsive breakpoint where sidebar becomes a drawer
  static const double kDesktopBreakpoint = 900;

  // Menu definition: label, icon, and builder to return corresponding screen
  late final List<_MenuItem> _allMenuItems;

  // late AppUser userMetaGlobal;

  // @override
  //   // void initState() {
  //   //   super.initState();
  //   //
  //   //   // Do not await in initState. Schedule after first build.
  //   //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //   //     _initialize();
  //   //   });
  //   //
  //   //   // Provide a minimal initial menu or leave empty until loaded
  //   //   _allMenuItems = [];
  //   // }

  final FlutterTts _tts = FlutterTts();

  StreamSubscription<Map<String, dynamic>>? _txSub;

  late StreamSubscription<SocketStatus> _connSub;

  late StreamSubscription<Map<String, dynamic>>? _qrAlertSub;

  bool ttsENABLED = true;

  bool popUpENABLED = true;

  bool socketConnected = false;

  // Minimal Hindi number words (0..99)
  static const _hindiUnits = [
    'शून्य','एक','दो','तीन','चार','पाँच','छह','सात','आठ','नौ',
    'दस','ग्यारह','बारह','तेरह','चौदह','पंद्रह','सोलह','सत्रह','अठारह','उन्नीस',
    'बीस','इक्कीस','बाइस','तेइस','चौबीस','पच्चीस','छब्बीस','सत्ताईस','अट्ठाईस','उनतीस',
    'तीस','इकतीस','बत्तीस','तैंतीस','चौंतीस','पैंतीस','छत्तीस','सैंतीस','अड़तीस','उनतालीस',
    'चालीस','इकतालीस','बयालीस','तैंतालीस','चवालीस','पैंतालीस','छियालीस','सैंतालीस','अड़तालीस','उनचास',
    'पचास','इक्यावन','बावन','तिरेपन','चौवन','पचपन','छप्पन','सत्तावन','अट्ठावन','उनसठ',
    'साठ','इकसठ','बासठ','तिरेसठ','चौंसठ','पैंसठ','छियासठ','सड़सठ','अड़सठ','उनहत्तर',
    'सत्तर','इकहत्तर','बहत्तर','तिहत्तर','चौहत्तर','पचहत्तर','छिहत्तर','सत्तहत्तर','अठहत्तर','उन्नासी',
    'अस्सी','इक्यासी','बयासी','तिरासी','चौरासी','पचासी','छियासी','सत्तासी','अठासी','नवासी',
    'नब्बे','इक्यानबे','बानवे','तििरानवे','चौरानवे','पचानवे','छियानवे','सतानवे','अट्ठानवे','निन्यानवे'
  ];

  @override
  void initState() {

    super.initState();

    // loadUserMeta();
    // print(widget.userMeta);
    loadConfig();
    _activeIndex = 0;
    // if(checkRole("admin")){
    //   _activeIndex = 0;
    // }else if( checkRole("subadmin") && checkLabel("users") ){
    //   _activeIndex = 0;
    // }else if(checkRole("employee")){
    //   _activeIndex = 0;
    // }
    // else{
    //   _activeIndex = 2;
    // }

    _allMenuItems = [
      _MenuItem(
        id: 0,
        label: 'Dashboard',
        icon: Icons.person,
        visibleFor: (_) => true,
        builder: (_) => UserDashboardScreen(),
      ),
      _MenuItem(
        id: 1,
        label: 'Manage Users',
        icon: Icons.person,
        visibleFor: (labels) => checkRole('admin') || (checkRole("subadmin")  && checkLabel("users") || (checkRole("employee") && checkLabel(AppConstants.viewAllUsers))  ),
        builder: (_) => const ManageUsersScreen(),
      ),
      _MenuItem(
        id: 2,
        label: 'Manage All QR Codes',
        icon: Icons.qr_code,
        visibleFor: (labels) => checkRole('admin'),
        builder: (_) => ManageQrScreen(userMeta: widget.userMeta,),
      ),
      _MenuItem(
        id: 3,
        label: 'My QR Codes',
        icon: Icons.qr_code_scanner,
        visibleFor: (_) => !checkRole('employee'),
        builder: (user) => ManageQrScreen(userMode: true, userModeUserid: user.$id, userMeta: widget.userMeta,),
      ),
      _MenuItem(
        id: 4,
        label: 'Manual Transaction',
        icon: Icons.add_box_outlined,
        visibleFor: (labels) => checkRole('admin') || (checkRole('employee') && checkLabel(AppConstants.manualTransactions)),
        builder: (_) => ManualTransactionForm(),
      ),
      _MenuItem(
        id: 5,
        label: 'View All Transactions',
        icon: Icons.receipt_long,
        visibleFor: (labels) => checkRole('admin') || (checkRole('employee') && checkLabel(AppConstants.viewAllTransactions) ),
        builder: (_) => const TransactionPageNew(),
      ),
      _MenuItem(
        id: 6,
        label: 'View My Transactions',
        icon: Icons.receipt,
        visibleFor: (_) => !checkRole('employee'),
        builder: (user) => TransactionPageNew(userMode: true, userModeUserid: user.$id),
      ),
      _MenuItem(
        id: 7,
        label: 'All Withdrawals',
        icon: Icons.account_balance_wallet_outlined,
        visibleFor: (labels) => checkRole('admin') || (checkRole('employee') && checkLabel(AppConstants.viewAllWithdrawals) ),
        builder: (_) => ManageWithdrawalsNew(),
      ),
      _MenuItem(
        id: 8,
        label: 'My Withdrawals',
        icon: Icons.account_balance_wallet,
        visibleFor: (_) => !checkRole('employee'),
        builder: (user) => ManageWithdrawalsNew(userMode: true, userModeUserid: user.$id),
      ),
      // _MenuItem(
      //   id: 8,
      //   label: 'SocketTest',
      //   icon: Icons.settings,
      //   visibleFor: (labels) => true,
      //   builder: (_) => SocketTestApp(),
      // ),
    ];

    // init hovering states
    for (var item in _allMenuItems) {
      _hovering[item.id] = false;
    }

    setupSocketTransactionSpeech();

  }

  @override
  void dispose() {
    _txSub?.cancel();
    _connSub?.cancel();
    _qrAlertSub?.cancel();
    super.dispose();
  }

  bool checkRole(String role){
    if(widget.userMeta.role.toLowerCase() == (role.toLowerCase())) {
      return true;
    }else{
      return false;
    }
  }

  bool checkLabel(String label){
    if(widget.userMeta.labels.contains(label.toLowerCase())) {
      return true;
    }else{
      return false;
    }
  }

  Future<void> setupSocketTransactionSpeech() async {
    final QrCodeService _qrCodeService = QrCodeService();
    String jwtToken = await AppWriteService().getJWT();
    List<QrCode> _qrCodes = await _qrCodeService.getUserAssignedQrCodes(widget.userMeta.id, jwtToken);
    final List<String> qrIds = _qrCodes.map((q) => q.qrId).whereType<String>().toSet().toList();
    socketManagerConnect(qrIds);
  }

  String amountToWordsIndian(int amountPaise) {
    final rupees = amountPaise ~/ 100;
    final words = NumToWords.convertNumberToIndianWords(rupees); // uses lakh/crore style [6]
    return words.toLowerCase();
  }

  String _twoDigitsHindi(int n) => _hindiUnits[n];

  String _segmentHindi(int n) {
    if (n < 100) return _twoDigitsHindi(n);
    if (n < 1000) {
      final h = n ~/ 100, r = n % 100;
      return r == 0 ? '${_hindiUnits[h]} सौ' : '${_hindiUnits[h]} सौ ${_twoDigitsHindi(r)}';
    }
    if (n < 100000) { // thousand
      final th = n ~/ 1000, r = n % 1000;
      final head = th == 1 ? 'एक हज़ार' : '${_segmentHindi(th)} हज़ार';
      return r == 0 ? head : '$head ${_segmentHindi(r)}';
    }
    if (n < 10000000) { // lakh
      final lk = n ~/ 100000, r = n % 100000;
      final head = lk == 1 ? 'एक लाख' : '${_segmentHindi(lk)} लाख';
      return r == 0 ? head : '$head ${_segmentHindi(r)}';
    }
    // crore
    final cr = n ~/ 10000000, r = n % 10000000;
    final head = cr == 1 ? 'एक करोड़' : '${_segmentHindi(cr)} करोड़';
    return r == 0 ? head : '$head ${_segmentHindi(r)}';
  }

  String amountToHindiWords(int amountPaise) {
    final rupees = amountPaise ~/ 100;
    if (rupees == 0) return 'शून्य';
    return _segmentHindi(rupees);
  }

  Future<void> speakAmountReceived(int amountPaise) async {
    // List supported languages (optional, for debugging/install hints)
    final langs = await _tts.getLanguages;
    // print(langs);

    // Prefer Hindi (India)
    const hindiIndia = 'hi-IN';
    if (langs is List && langs.contains(hindiIndia)) {
      await _tts.setLanguage(hindiIndia); // Hindi (India)
      await _tts.setSpeechRate(0.8);
      await _tts.setPitch(1.0);

      final words = amountToHindiWords(amountPaise); // Hindi Indian numbering
      final sentence = 'काइटपे पर $words रुपये प्राप्त हुए'; // natural Hindi announcement
      await _tts.speak(sentence);

    } else {
      // Fallback or show a prompt that Hindi voice is not installed
      await _tts.setLanguage('en-IN'); // fallback

      final words = amountToWordsIndian(amountPaise); // 125.00 INR -> "one hundred twenty five" [9]
      // ₹
      final sentence = '$words rupees received in Kitepay';
      await _tts.speak(sentence); // say full words, not digits [18]
    }

    // await _tts.setSpeechRate(0.9);
    // await _tts.setPitch(1.0);
    //
    // final words = amountToHindiWords(amountPaise); // Hindi Indian numbering
    // final sentence = 'काइटपे में $words रुपये प्राप्त हुए'; // natural Hindi announcement
    // await _tts.speak(sentence);

    // final words = amountToWordsIndian(amountPaise); // 125.00 INR -> "one hundred twenty five" [9]
    // // ₹
    // final sentence = 'KitePay per $words rupees prapt hue';
    // await _tts.speak(sentence); // say full words, not digits [18]
  }

  Future<void> speakQrAlert() async {
    // List supported languages (optional, for debugging/install hints)
    final langs = await _tts.getLanguages;
    // print(langs);

    // Prefer Hindi (India)
    const hindiIndia = 'hi-IN';
    if (langs is List && langs.contains(hindiIndia)) {
      await _tts.setLanguage(hindiIndia); // Hindi (India)
      await _tts.setSpeechRate(0.9);
      await _tts.setPitch(1.0);

      final sentence = 'क्यूआर का काम शुरू हो गया है';
      await _tts.speak(sentence); // say full words, not digits [18]

    } else {
      // Fallback or show a prompt that Hindi voice is not installed
      await _tts.setLanguage('en-IN'); // fallback

      await _tts.setSpeechRate(0.9);
      await _tts.setPitch(1.0);

      final sentence = 'QR ka kaam shuru ho gaya hai';
      await _tts.speak(sentence); // say full words, not digits [18]
    }

    // await _tts.setSpeechRate(0.9);
    // await _tts.setPitch(1.0);
    //
    // // final sentence = 'QR ka kaam shuru ho gaya hai';
    // await _tts.speak(sentence); // say full words, not digits [18]
  }

  Future<void> initTts() async {

    final langs = await _tts.getLanguages;
    // print(langs);

    // Prefer Hindi (India)
    const hindiIndia = 'hi-IN';
    if (langs is List && langs.contains(hindiIndia)) {
      await _tts.setLanguage(hindiIndia); // Hindi (India)
    } else {
      // Fallback or show a prompt that Hindi voice is not installed
      await _tts.setLanguage('en-IN'); // fallback
    }

    // await _tts.setLanguage('en-IN'); // Indian English accent [18]
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);

    // await _tts.setLanguage('en-IN'); // or 'en-US' etc.
    // await _tts.setSpeechRate(0.9); // 0.0–1.0
    // await _tts.setPitch(1.0); // 0.5–2.0
    // Optional handlers
    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(() {});
    _tts.setErrorHandler((msg) {
      /* log */
    });
  }

  void socketManagerConnect(List<String> myQrCodes) async {
    await initTts(); // TTS initialize
    if (!SocketManager.instance.isConnected) {
      await SocketManager.instance.connect(
        url: 'https://kite-pay-api-v1.onrender.com',
        // url: 'http://localhost:3000',
        jwt: await AppWriteService().getJWT(),
        // qrIds: ["119188392"],
        qrIds: myQrCodes,
        userMeta: widget.userMeta,
      );
      if(widget.userMeta.role == 'admin'){
        SocketManager.instance.subscribeQrAlert();
      }
    } else {
      SocketManager.instance.subscribeQrIds(myQrCodes);
      if(widget.userMeta.role == 'admin'){
        SocketManager.instance.subscribeQrAlert();
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Realtime Transactions Connected')),
      );
    }

    _txSub = SocketManager.instance.txStream.listen((event) async {
      // event: { id, qrCodeId, amountPaise, createdAtIso, ... }
      Transaction txn = Transaction.fromJson(event);
      if(ttsENABLED){
        speakAmountReceived(txn.amount);
      }

      if(popUpENABLED){
        await DialogSingleton.showReplacing(
          builder: (ctx) => AlertDialog(
            title: const Text('New Payment Received'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [TransactionCard(txn: txn)]),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
          ),
        );
      }

    });

    _connSub = SocketManager.instance.connectionStream.listen((status) {
      final connected = status == SocketStatus.connected || status == SocketStatus.reconnected;
      if (socketConnected != connected && mounted) {
        setState(() => socketConnected = connected);
      }

      if(status == SocketStatus.connected){
        print("Connected");
        // speakQrAlert('रीयल-टाइम ट्रांज़ैक्शन्स सर्वर कनेक्ट हो गया है');
      }

    });

      _qrAlertSub = SocketManager.instance.qrAlertController.listen((event) async {
      // event: { id, qrCodeId, amountPaise, createdAtIso, ... }
      QrCode qr = QrCode.fromJson(event);

      if(ttsENABLED){
        speakQrAlert();
      }

      if(popUpENABLED){
        await DialogSingleton.showReplacing(
          builder: (ctx) => AlertDialog(
            title: const Text('Qr Work Started'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [Text(qr.qrId)]),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
          ),
        );
      }

    });

  }

  // Future<void> loadUserMeta() async {
  //   String jwtToken = await AppWriteService().getJWT();
  //   userMetaGlobal = (await MyMetaApi.getMyMetaData(
  //     jwtToken: jwtToken,
  //     refresh: false, // set true to force re-fetch
  //   ))!;
  // }

  Future<void> loadConfig() async {
    try{
      final response = await http.get(Uri.parse('${AppConstants.baseApiUrl}/user/config')).timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          AppConfig().loadFromJson(data['config']);
        }
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      print('❌ Exception in Fetching App Config: $e');
      throw Exception('Exception in Fetching App Config: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _appWriteService.account.deleteSession(sessionId: 'current');
        final prefs = await SharedPreferences.getInstance(); await prefs.clear();
        if (!mounted) return;
        // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              (route) => false,
        );

      } catch (e) {
        print(e);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logout failed: ${e.toString()}')));
      }
    }
  }

  List<_MenuItem> get _visibleMenuItems {
    final labels = widget.userMeta.labels.map((e) => e.toString()).toList();
    return _allMenuItems.where((m) => m.visibleFor(labels)).toList();
  }

  void _onSelectMenu(_MenuItem item, bool isDesktop) {
    setState(() {
      _activeIndex = item.id;
    });
    if (!isDesktop) Navigator.pop(context); // close drawer on mobile
  }

  // Build sidebar item widget
  Widget _buildSidebarItem(_MenuItem item, bool isActive, bool collapsed, bool isDesktop) {
    final hovering = _hovering[item.id] ?? false;
    final bg = isActive
        ? Colors.blue.shade700
        : (hovering ? Colors.grey.shade200 : Colors.transparent);
    final fg = isActive ? Colors.white : Colors.black87;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering[item.id] = true),
      onExit: (_) => setState(() => _hovering[item.id] = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _onSelectMenu(item, isDesktop),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: collapsed ? 8 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                // active left indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.yellow.shade700 : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(item.icon, color: isActive ? Colors.white : Colors.black54),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      overflow: TextOverflow.ellipsis, // no overflow
                      item.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (isActive && !collapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool collapsed, bool isDesktop) {
    final items = _visibleMenuItems;
    return Container(
      width: collapsed ? 110 : 260,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView(
          children: [
            Column(
              children: [
                // header (profile + collapse)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade700,
                        child: Text(
                          (widget.userMeta.name?.isNotEmpty ?? false)
                              ? widget.userMeta.name!.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.userMeta.name ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(widget.userMeta.email ?? '',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        if(isDesktop)
                        IconButton(
                          tooltip: _sidebarCollapsed ? 'Expand' : 'Collapse',
                          onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                          icon: Icon(_sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left),
                        )
                      ] else
                        IconButton(
                          onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                          icon: const Icon(Icons.menu),
                          tooltip: 'Expand',
                        )
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                // menu list
                // Expanded(
                //   child: SingleChildScrollView(
                //     child: Column(
                //       children: items.map((mi) {
                //         final isActive = _activeIndex == mi.id;
                //         return _buildSidebarItem(mi, isActive, collapsed, isDesktop);
                //       }).toList(),
                //     ),
                //   ),
                // ),

                // menu list (rendered inline so it scrolls with the rest)
                ...items.map((mi) {
                  final isActive = _activeIndex == mi.id;
                  return _buildSidebarItem(mi, isActive, collapsed, isDesktop);
                }),

                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Expanded(
                          child: Text('Transactions Server', style: TextStyle(fontSize: 16)),
                        ),
                        _statusChip(socketConnected), // read-only visual status
                      ],
                    ),
                  ),

                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('PopUp transactions'),
                            value: popUpENABLED,
                            onChanged: (v) => setState(() => popUpENABLED = v),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Speak transactions'),
                            value: ttsENABLED,
                            onChanged: (v) => setState(() => ttsENABLED = v),
                          ),
                        ),
                      ],
                    ),
                  ),

                // bottom quick actions
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Logout'),
                            onPressed: () => _logout(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),


          ],
        ),
    );
  }

  // Colors
  Color _statusColor(bool connected) =>
      connected ? const Color(0xFF2E7D32) /*green*/ : const Color(0xFFC62828) /*red*/;

  Widget _statusChip(bool connected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(connected).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor(connected)),
      ),
      child: Text(
        connected ? 'Connected' : 'Disconnected',
        style: TextStyle(
          color: _statusColor(connected),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (ctx) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                );
              }
            ),
          const SizedBox(width: 8),
          Text(
            '${widget.userMeta.name ?? "Dashboard"}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // small profile + quick logout
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.userMeta.name ?? ''),
                  Text(widget.userMeta.email ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Logout',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build content area; uses AnimatedSwitcher for smooth transitions
  Widget _buildContent() {
    final menuItem = _allMenuItems.firstWhere((m) => m.id == _activeIndex, orElse: () => _allMenuItems.first);
    final Widget page = menuItem.builder(widget.user);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) {
        final offsetAnim = Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(anim);
        return SlideTransition(position: offsetAnim, child: FadeTransition(opacity: anim, child: child));
      },
      child: SizedBox(
        key: ValueKey<int>(_activeIndex),
        width: double.infinity,
        height: double.infinity,
        child: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(_sidebarCollapsed, false)),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar for desktop
            if (isDesktop) _buildSidebar(_sidebarCollapsed, true),

            // Main area (topbar + content)
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(isDesktop),
                  Expanded(
                    child: Container(
                      color: Theme.of(context).colorScheme.background,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small helper class for menu metadata
class _MenuItem {
  final int id;
  final String label;
  final IconData icon;
  final bool Function(List<String> userLabels) visibleFor;
  final Widget Function(User user) builder;

  _MenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.visibleFor,
    required this.builder,
  });
}

class DialogSingleton {
  static Completer<void>? _active;

  static Future<void> showReplacing({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    // Close active dialog if any
    if (_active != null && !_active!.isCompleted && navigator.canPop()) {
      navigator.pop();
      await _active!.future.catchError((_) {});
    }

    final c = Completer<void>();
    _active = c;

    try {
      // Ensure called in a frame owned by the root navigator
      await Future.microtask(() {}); // yield to event loop
      await showDialog(
        context: rootNavigatorKey.currentContext!,
        barrierDismissible: barrierDismissible,
        builder: builder,
      ); // always uses a valid, top-level context [1][2]
    } finally {
      if (!c.isCompleted) c.complete();
      if (identical(_active, c)) _active = null;
    }
  }

  static void closeIfAny() {
    final nav = rootNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }
}

