import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_mechanic/main_screen/booking/tracking_screen.dart';
import 'package:vehicle_mechanic/main_screen/bottom_menu.dart';
import 'package:vehicle_mechanic/main_screen/history/price_details.dart';
import 'package:vehicle_mechanic/main_screen/history/problems_prices.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final supabase = Supabase.instance.client;

  String? mechanicId;
  List<Map<String, dynamic>> historyRequests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  // 🔹 STATUS CHIP
  Widget _statusChip(String status) {
    if (status == 'paid') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "Completed",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    if (status == 'pending_payment') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "Pending Payment",
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "In Progress",
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // 🔹 LOAD HISTORY
  Future<void> loadHistory() async {
    final mech = await supabase
        .from('mechanics')
        .select('id')
        .eq('email', supabase.auth.currentUser!.email!)
        .single();

    mechanicId = mech['id'];
    if (mechanicId == null) return;

    final emergency = await supabase
        .from('service_requests')
        .select('''
      id, problem, description, address, status, created_at,
      users_data!service_requests_user_id_fkey ( name )
    ''')
        .eq('mechanic_id', mechanicId!)
        .or('status.eq.accepted,status.eq.paid')
        .order('created_at', ascending: false);

    final regular = await supabase
        .from('service_requests_new')
        .select('''
      id, problem, description, status, created_at,
      users_data!service_requests_new_user_id_fkey ( name )
    ''')
        .eq('mechanic_id', mechanicId!)
        .or('status.eq.time_fixed,status.eq.pending_payment,status.eq.paid')
        .order('created_at', ascending: false);

    if (!mounted) return;

    List<Map<String, dynamic>> combined = [
      ...emergency.map((e) => {...e, '_type': 'emergency'}),

      ...regular.map((e) => {...e, '_type': 'regular'}),
    ];

    /// sort newest first
    combined.sort((a, b) {
      final aTime = DateTime.parse(a['created_at']);
      final bTime = DateTime.parse(b['created_at']);

      return bTime.compareTo(aTime);
    });

    setState(() {
      historyRequests = combined;

      loading = false;
    });
  }

  // 🔹 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service History"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // TOP CARD
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProblemPrizePage(),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F4DAB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Vehicle Problem & Price",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // HISTORY LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: historyRequests.length,
                    itemBuilder: (_, i) {
                      final req = historyRequests[i];
                      final user = req['users_data'];

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),

                        onTap: () {
                          if (req['status'] == 'paid') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PriceDetailsPage(
                                  requestId: req['id'],
                                  isEmergency: req['_type'] == 'emergency',
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrackingScreen(
                                  requestId: req['id'],
                                  isEmergency: req['_type'] == 'emergency',
                                ),
                              ),
                            );
                          }
                        },

                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      req['_type'] == 'emergency'
                                          ? "🚨 Emergency Service"
                                          : "🔧 Regular Service",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _statusChip(req['status']),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text("Customer: ${user?['name'] ?? '-'}"),
                                Text("Problem: ${req['problem']}"),
                                if (req['_type'] == 'emergency')
                                  Text("Location: ${req['address'] ?? '-'}"),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const BottomMenu(selectedIndex: 2),
    );
  }
}
