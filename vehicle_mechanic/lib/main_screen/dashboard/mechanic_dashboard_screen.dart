import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vehicle_mechanic/main_screen/bottom_menu.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  late Future<List> dashboardData;

  @override
  void initState() {
    super.initState();

    dashboardData = getDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mechanic Dashboard"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),

      body: FutureBuilder(
        future: dashboardData,

        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData) {
            return const Center(child: Text("No scheduled services"));
          }

          final data = snap.data as List;

          if (data.isEmpty) {
            return const Center(child: Text("No scheduled services"));
          }

          //   final data = snap.data as List;

          return ListView.builder(
            padding: const EdgeInsets.all(16),

            itemCount: data.length,

            itemBuilder: (context, i) {
              final d = data[i];

              return GestureDetector(
                onTap: () {
                  showServicePopup(d);
                },

                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),

                  elevation: 3,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(15),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          (d['users_data'] != null)
                              ? d['users_data']['name']
                              : "-",

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(d['problem'] ?? "-"),

                        const SizedBox(height: 5),

                        Text("Date : ${d['work_date']}"),

                        Text("Time : ${d['start_time']} - ${d['end_time']}"),

                        const SizedBox(height: 5),

                        Text(
                          "Status : ${d['status']}",

                          style: TextStyle(
                            color: d['status'] == "completed"
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),

      bottomNavigationBar: const BottomMenu(selectedIndex: 0),
    );
  }

  /// POPUP
  void showServicePopup(dynamic data) {
    TextEditingController priceController = TextEditingController(
      text: data['status'] == "completed"
          ? (data['amount']?.toString() ?? "")
          : "",
    );
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text("Service Details"),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              Text("Problem : ${data['problem']}"),

              const SizedBox(height: 10),

              TextField(
                controller: priceController,

                keyboardType: TextInputType.number,

                decoration: const InputDecoration(
                  labelText: "Enter Amount",

                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("Close"),
            ),

            ElevatedButton(
              onPressed: () async {
                if (priceController.text.isNotEmpty) {
                  await saveServiceAmount(data, priceController.text);
                }

                await completeService(data);

                Navigator.pop(context);
              },

              child: const Text("Complete"),
            ),
          ],
        );
      },
    );
  }

  Future saveServiceAmount(dynamic data, String price) async {
    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;

    final mech = await supabase
        .from('mechanics')
        .select('id')
        .eq('email', user!.email!)
        .maybeSingle();

    /// check existing price
    final existing = await supabase
        .from('regular_service_price')
        .select('id')
        .eq('user_id', data['user_id'])
        .eq('problem', data['problem'])
        .maybeSingle();

    /// update or insert
    if (existing != null) {
      await supabase
          .from('regular_service_price')
          .update({'price': double.parse(price)})
          .eq('id', existing['id']);
    } else {
      await supabase.from('regular_service_price').insert({
        'mechanic_id': mech!['id'],

        'user_id': data['user_id'],

        'problem': data['problem'],

        'price': double.parse(price),
      });
    }
  }

  /// COMPLETE SERVICE
  Future completeService(dynamic data) async {
    final supabase = Supabase.instance.client;

    /// update service time
    await supabase
        .from('fix_service_time')
        .update({'status': 'completed'})
        .eq('id', data['id']);

    /// update request status to pending payment
    await supabase
        .from('service_requests_new')
        .update({'status': 'pending_payment'})
        .eq('user_id', data['user_id'])
        .eq('problem', data['problem']);

    /// reload list
    setState(() {
      dashboardData = getDashboardData();
    });
  }

  /// FETCH DATA
  Future<List> getDashboardData() async {
    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final mech = await supabase
        .from('mechanics')
        .select('id')
        .eq('email', user.email!)
        .maybeSingle();

    if (mech == null) {
      return [];
    }

    final mechanicId = mech['id'];

    final services = await supabase
        .from('fix_service_time')
        .select('''
id,
problem,
start_time,
end_time,
work_date,
status,
user_id
''')
        .eq('mechanic_id', mechanicId);

    List scheduled = [];
    List completed = [];

    DateTime today = DateTime.now();

    DateTime todayDate = DateTime(today.year, today.month, today.day);

    for (var s in services) {
      DateTime serviceDate = DateTime.parse(s['work_date']);

      DateTime onlyDate = DateTime(
        serviceDate.year,
        serviceDate.month,
        serviceDate.day,
      );

      /// skip old scheduled services
      if (onlyDate.isBefore(todayDate) && s['status'] != "completed") {
        continue;
      }

      /// username
      final userData = await supabase
          .from('users_data')
          .select('name')
          .eq('id', s['user_id'])
          .maybeSingle();

      s['users_data'] = userData;

      /// price
      final priceData = await supabase
          .from('regular_service_price')
          .select('price')
          .eq('user_id', s['user_id'])
          .eq('problem', s['problem'])
          .maybeSingle();

      s['amount'] = priceData?['price'];

      if (s['status'] == "completed") {
        completed.add(s);
      } else {
        scheduled.add(s);
      }
    }

    /// scheduled sort
    scheduled.sort((a, b) {
      DateTime aDate = DateTime.parse("${a['work_date']} ${a['start_time']}");

      DateTime bDate = DateTime.parse("${b['work_date']} ${b['start_time']}");

      return aDate.compareTo(bDate);
    });

    /// completed latest first
    completed.sort((a, b) {
      DateTime aDate = DateTime.parse("${a['work_date']} ${a['end_time']}");

      DateTime bDate = DateTime.parse("${b['work_date']} ${b['end_time']}");

      return bDate.compareTo(aDate);
    });

    List finalList = [];

    finalList.addAll(scheduled);

    finalList.addAll(completed);

    return finalList;
  }
}
