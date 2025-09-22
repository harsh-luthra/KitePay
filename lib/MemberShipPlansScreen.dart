import 'package:flutter/material.dart';

class MembershipPlansApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Membership Plans',
      home: MembershipPlansScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MembershipPlan {
  final String name;
  final String price;
  final List<Map<String, dynamic>> features;
  MembershipPlan({
    required this.name,
    required this.price,
    required this.features,
  });
}

class MembershipPlansScreen extends StatelessWidget {
  final List<MembershipPlan> plans = [
    MembershipPlan(
      name: 'Retail Starter',
      price: '₹2,500',
      features: [
        {'Free QR Code': '1'},
        {'Add-On QR': '₹3250 each'},
        {'Pay-In Access': true},
        {'Pay-Out Access': false},
        {'Commission Setup': false},
        {'Referral Income': true},
        {'Cashback': true},
        {'Transaction Charges': 'Standard'},
        {'Settlement Time': 'T+1'},
        {'Analytics & Reports': 'Basic'},
        {'Branding Options': false},
        {'Complimentary Features': 'Sound Alerts, Live Notifications, Cyber Enquiry'},
      ],
    ),
    MembershipPlan(
      name: 'Retail Silver',
      price: '₹5,000',
      features: [
        {'Free QR Code': '1'},
        {'Add-On QR': '₹2850 each'},
        {'Pay-In Access': true},
        {'Pay-Out Access': false},
        {'Commission Setup': false},
        {'Referral Income': true},
        {'Cashback': true},
        {'Transaction Charges': 'Lower than Starter'},
        {'Settlement Time': 'T+1 Priority'},
        {'Analytics & Reports': 'Basic'},
        {'Branding Options': false},
        {'Complimentary Features': 'Sound Alerts, Live Notifications, Cyber Enquiry'},
      ],
    ),
    MembershipPlan(
      name: 'Retail Gold',
      price: '₹7,000',
      features: [
        {'Free QR Code': '1'},
        {'Add-On QR': '₹2250 each'},
        {'Pay-In Access': true},
        {'Pay-Out Access': false},
        {'Commission Setup': false},
        {'Referral Income': true},
        {'Cashback': true},
        {'Transaction Charges': 'Discounted'},
        {'Settlement Time': 'T+1'},
        {'Analytics & Reports': 'Advanced (sales & commissions)'},
        {'Branding Options': false},
        {'Complimentary Features': 'Same'},
      ],
    ),
    MembershipPlan(
      name: 'Retail Platinum',
      price: '₹9,000',
      features: [
        {'Free QR Code': '2'},
        {'Add-On QR': '₹2250 each'},
        {'Pay-In Access': true},
        {'Pay-Out Access': true},
        {'Commission Setup': false},
        {'Referral Income': true},
        {'Cashback': true},
        {'Transaction Charges': 'Lower + Bulk payout'},
        {'Settlement Time': 'T+1 + Bulk payouts'},
        {'Analytics & Reports': 'Full premium + API access'},
        {'Branding Options': false},
        {'Complimentary Features': 'Same + merchant-level risk tools'},
      ],
    ),
  ];

  Widget _buildFeatureRow(Map<String, dynamic> feature) {
    final key = feature.keys.first;
    final value = feature.values.first;
    Widget iconOrText;
    if (value is bool) {
      iconOrText = Icon(
        value ? Icons.check : Icons.close,
        color: value ? Colors.green : Colors.red,
        size: 18,
      );
    } else {
      iconOrText = Text(value.toString(),
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconOrText,
          SizedBox(width: 8),
          Expanded(child: Text(key, style: TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget buildPlanCard(MembershipPlan plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // important: let Column grow by content
          children: [
            Text(plan.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: Colors.blue[800])),
            SizedBox(height: 4),
            Text(plan.price,
                style: TextStyle(fontSize: 17, color: Colors.grey[900])),
            Divider(height: 18, thickness: 1.3),
            ...plan.features.map(_buildFeatureRow),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive grid
    final w = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    double pad = 12;
    if (w > 1100) {
      crossAxisCount = 3;
      pad = 60;
    } else if (w > 800) {
      crossAxisCount = 2;
      pad = 30;
    } else if (w > 600) {
      crossAxisCount = 1;
      pad = 16;
    }
    return Scaffold(
      backgroundColor: Color(0xfff7f7fa),
      appBar: AppBar(
        title: Text('Customer Membership Plans'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 1000, // Important: this allows height to expand
            crossAxisSpacing: 20,
            mainAxisSpacing: 18,
          ),
          itemCount: plans.length,
          itemBuilder: (context, i) => buildPlanCard(plans[i]),
        ),
      ),
    );
  }
}
