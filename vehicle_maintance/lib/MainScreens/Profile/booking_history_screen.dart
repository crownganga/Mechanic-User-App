import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> bookings = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  void openEditDialog(Map<String, dynamic> booking) {
    final TextEditingController amountController = TextEditingController(
      text: booking['amount']?.toString() ?? "",
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Update Amount"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// VEHICLE
                Text(
                  "Vehicle: ${safe(booking['vehicle_details']?['vehicle_type'])} - "
                  "${safe(booking['vehicle_details']?['brand'])}",
                ),

                const SizedBox(height: 10),

                /// PROBLEM
                Text("Problem: ${safe(booking['problem'])}"),

                const SizedBox(height: 10),

                /// STATUS
                Text("Status: ${safe(booking['status'])}"),

                const SizedBox(height: 15),

                /// AMOUNT (Editable)
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Amount",
                    border: OutlineInputBorder(),
                    prefixText: "₹ ",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await updateAmount(booking, amountController.text.trim());
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateAmount(
    Map<String, dynamic> booking,
    String newAmount,
  ) async {
    try {
      if (newAmount.isEmpty) return;

      final tableName = booking.containsKey('request_type')
          ? 'service_requests'
          : 'service_requests_new';

      await supabase
          .from(tableName)
          .update({
            'amount': double.parse(newAmount),
            'status': 'Completed', // 🔥 AUTO CHANGE STATUS
          })
          .eq('id', booking['id']);

      Navigator.pop(context);

      await fetchBookings(); // refresh list

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Amount updated & Status changed to Completed"),
        ),
      );
    } catch (e) {
      print("Update Error: $e");
    }
  }

  Future<void> fetchBookings() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      // Fetch bookings
      final emergency = await supabase
          .from('service_requests')
          .select()
          .eq('user_id', user.id);

      final normal = await supabase
          .from('service_requests_new')
          .select()
          .eq('user_id', user.id);

      final allBookings = [
        ...List<Map<String, dynamic>>.from(emergency),
        ...List<Map<String, dynamic>>.from(normal),
      ];

      // 🔥 Fetch all vehicles of this user
      final vehiclesResponse = await supabase
          .from('vehicles')
          .select()
          .eq('user_id', user.id);

      final vehiclesList = List<Map<String, dynamic>>.from(vehiclesResponse);

      // 🔥 Create vehicle map (id -> vehicle data)
      final vehicleMap = {for (var v in vehiclesList) v['id']: v};

      // 🔥 Attach vehicle details to bookings
      for (var booking in allBookings) {
        final vehicleId = booking['vehicle_id'];
        booking['vehicle_details'] = vehicleMap[vehicleId];
      }

      // Sort latest first
      allBookings.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      setState(() {
        bookings = allBookings;
        loading = false;
      });
    } catch (e) {
      print("ERROR: $e");
      setState(() => loading = false);
    }
  }

  String safe(dynamic v) =>
      v == null || v.toString().isEmpty ? "N/A" : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        title: const Text("Booking History"),
        centerTitle: true,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
          ? const Center(
              child: Text(
                "No bookings found",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final status = safe(booking['status']);
                final vehicle = booking['vehicle_details']; // 🔥 ADD THIS LINE

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// HEADER ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          /* Text(
                            "Service ID: ${booking['id'].toString().substring(0, 6)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),*/
                          Text(
                            vehicle != null
                                ? "Vehicle: ${safe(vehicle['vehicle_type'])} - ${safe(vehicle['brand'])}"
                                : "Vehicle: N/A",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Color(0xFF0F4DAB),
                            ),
                            onPressed: () {
                              openEditDialog(booking);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      /// 🔥 VEHICLE DETAILS FIXED
                      /*    Text(
                        vehicle != null
                            ? "Vehicle: ${safe(vehicle['vehicle_type'])} - ${safe(vehicle['brand'])}"
                            : "Vehicle: N/A",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),*/
                      const SizedBox(height: 8),

                      /// PROBLEM
                      Text(
                        "Problem: ${safe(booking['problem'])}",
                        style: const TextStyle(fontSize: 14),
                      ),

                      const SizedBox(height: 8),

                      /// FIX
                      /*      Text(
                        "Fix: ${safe(booking['description'])}",
                        style: const TextStyle(fontSize: 14),
                      ),*/
                      const SizedBox(height: 8),

                      /// AMOUNT
                      Text(
                        "Amount: ₹${safe(booking['amount'])}",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 8),

                      /// DATE
                      Text(
                        booking['created_at'] != null
                            ? DateTime.parse(
                                booking['created_at'],
                              ).toLocal().toString().split('.')[0]
                            : "",
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 10),

                      /// STATUS
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: getStatusColor(
                            safe(booking['status']),
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          safe(booking['status']).toUpperCase(),
                          style: TextStyle(
                            color: getStatusColor(safe(booking['status'])),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
