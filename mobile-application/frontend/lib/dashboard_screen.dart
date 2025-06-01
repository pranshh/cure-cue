// filepath: e:\expiry-date-checker-adherence-assistant\frontend\lib\success_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'theme_constants.dart';
import 'constants.dart';
import 'add_prescription_screen.dart';
import 'package:frontend/services/noti_serve.dart';

class DashboardScreen extends StatefulWidget {
  final String username;
  final String password;

  const DashboardScreen({
    Key? key,
    required this.username,
    required this.password,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> _upcomingReminders = [];
  List<Map<String, dynamic>> _allReminders = [];
  final GlobalKey _notificationKey = GlobalKey();
  bool _showNotificationsDropdown = false;
  List<Map<String, dynamic>> _completedReminders = [];
  bool isLoading = true;
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _sideEffectsController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchReminders();
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _sideEffectsController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  Future<void> _fetchReminders() async {
    setState(() => isLoading = true);
    try {
      final reminders = await NotiService().getRemainingRemindersForToday();
      final allReminders = await NotiService().getAllRemindersForToday();
      final now = tz.TZDateTime.now(tz.local);
      setState(() {
        _upcomingReminders = reminders;
        _allReminders = allReminders;
        _completedReminders = allReminders.where((reminder) {
          final scheduledTime = reminder['scheduledTime'] as tz.TZDateTime;
          return scheduledTime.isBefore(now);
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reminders: $e')),
      );
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchReminders();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-user-data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'password': widget.password,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          userData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  DateTime _parseExpiryDate(String date) {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        const months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };
        return DateTime(
          int.parse(parts[2]), // year
          months[parts[1]] ?? 1, // month
          int.parse(parts[0]), // day
        );
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return DateTime(1900); // Default date for invalid formats
  }

  @override
  Widget build(BuildContext context) {
    // Sort prescriptions by expiry date
    // if (userData?['prescriptions'] != null) {
    //   (userData!['prescriptions'] as List).sort((a, b) {
    //     try {
    //       final aDate = _parseExpiryDate(a['expiry_date']);
    //       final bDate = _parseExpiryDate(b['expiry_date']);
    //       return aDate.compareTo(bDate);
    //     } catch (e) {
    //       print('Error during sorting: $e');
    //       return 0;
    //     }
    //   });
    // }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Patient Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: ThemeConstants.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined,
                color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/expiry-check');
            },
          ),
          IconButton(
            key: _notificationKey,
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white),
                if (_completedReminders.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_completedReminders.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              if (_showNotificationsDropdown) {
                setState(() => _showNotificationsDropdown = false);
              } else {
                await _fetchReminders();
                setState(() => _showNotificationsDropdown = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Enhanced Profile Section
                      Container(
                        decoration: const BoxDecoration(
                          color: ThemeConstants.primaryColor,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Decorative circles
                            Positioned(
                              right: -30,
                              top: -20,
                              child: Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              left: -50,
                              bottom: -30,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            // Existing content
                            Column(
                              children: [
                                const SizedBox(height: 20),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Background circle
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    // Profile picture container
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 4),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const CircleAvatar(
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.person,
                                          size: 60,
                                          color: ThemeConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                    // Edit button
                                    Positioned(
                                      bottom: 0,
                                      right: MediaQuery.of(context).size.width *
                                          0.28,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: ThemeConstants.primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 20,
                                          color: ThemeConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // User info with icons
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Column(
                                    children: [
                                      Text(
                                        userData?['name'] ?? widget.username,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.email_outlined,
                                            color: Colors.white70,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            userData?['email'] ?? 'Loading...',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      // Quick stats
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 15,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildQuickStat(
                                              'Total',
                                              '${_allReminders.length}',
                                              Icons.medication_outlined,
                                            ),
                                            _buildQuickStat(
                                              'Completed %',
                                              '${_allReminders.isEmpty ? 0 : ((_allReminders.length - _upcomingReminders.length) / _allReminders.length * 100).toStringAsFixed(0)}%',
                                              Icons.check_circle_outline,
                                            ),
                                            _buildQuickStat(
                                              'Upcoming',
                                              '${_upcomingReminders.length}',
                                              Icons.upcoming_outlined,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // User Information Cards
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard(
                              icon: Icons.phone,
                              title: 'Phone',
                              value: userData?['phone'] ?? 'Not provided',
                            ),
                            _buildInfoCard(
                              icon: Icons.calendar_today,
                              title: 'Date of Birth',
                              value: userData?['dob'] ?? 'Not provided',
                            ),
                            _buildInfoCard(
                              icon: Icons.wc,
                              title: 'Gender',
                              value: userData?['gender'] ?? 'Not provided',
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Prescription Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    _fetchUserData();
                                    _fetchReminders();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (userData?['prescriptions'] != null &&
                                (userData!['prescriptions'] as List).isNotEmpty)
                              ...((userData!['prescriptions'] as List)
                                  .map(
                                    (prescription) => _buildPrescriptionCard(
                                      medicineName:
                                          prescription['medicine_name'],
                                      presId: prescription['pres_id'],
                                      recommendedDosage:
                                          prescription['recommended_dosage'],
                                      sideEffects: prescription['side_effects'],
                                      frequency: prescription['frequency'],
                                      expiryDate: prescription['expiry_date'],
                                    ),
                                  )
                                  .toList())
                            else
                              const Center(
                                child: Text(
                                  'No prescriptions found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
          if (_showNotificationsDropdown) _buildNotificationsDropdown(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPrescriptionScreen(
                username: widget.username,
                password: widget.password,
                userId: userData?['user_id'] ?? '',
              ),
            ),
          );
          if (result == true) {
            _fetchUserData();
          }
        },
        backgroundColor: ThemeConstants.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Prescription',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: ThemeConstants.primaryColor, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsDropdown() {
    return Positioned(
      right: 16,
      top: kToolbarHeight - 50,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ThemeConstants.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeConstants.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications,
                        color: ThemeConstants.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Completed Reminders',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ThemeConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Reminders list
              if (_completedReminders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No completed reminders yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _completedReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _completedReminders[index];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  ThemeConstants.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: ThemeConstants.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            reminder['medicine'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Taken at ${reminder['time'].format(context)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _completedReminders.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard({
    required String medicineName,
    required String presId,
    required String recommendedDosage,
    required String sideEffects,
    required int frequency,
    required String expiryDate,
  }) {
    // Check if medicine is expired
    bool isExpired = false;
    try {
      final parts = expiryDate.split(' ');
      if (parts.length == 3) {
        const months = {
          'Jan': 1,
          'Feb': 2,
          'Mar': 3,
          'Apr': 4,
          'May': 5,
          'Jun': 6,
          'Jul': 7,
          'Aug': 8,
          'Sep': 9,
          'Oct': 10,
          'Nov': 11,
          'Dec': 12
        };
        final expiryDateTime = DateTime(
          int.parse(parts[0]), // year
          months[parts[1]] ?? 1, // month
          int.parse(parts[2]), // day
        );
        final today = DateTime.now();
        isExpired = expiryDateTime
            .isBefore(DateTime(today.year, today.month, today.day));
        print(isExpired ? 'Medicine is expired' : 'Medicine is not expired');
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isExpired ? Colors.red[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isExpired
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red
                            .withOpacity(0.2) // Increased opacity for red
                        : ThemeConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: isExpired
                        ? Colors.red[700]
                        : ThemeConstants.primaryColor, // Darker red
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? Colors.red[700]
                              : Colors.black, // Darker red
                          decoration: isExpired
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withOpacity(0.2) // Increased opacity
                        : ThemeConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$frequency times/day',
                    style: TextStyle(
                      color: isExpired
                          ? Colors.red[700]
                          : ThemeConstants.primaryColor, // Darker red
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPrescriptionDetail(
              icon: Icons.schedule,
              title: 'Dosage',
              value: recommendedDosage,
              isExpired: isExpired, // Pass the isExpired flag
            ),
            const SizedBox(height: 8),
            _buildPrescriptionDetail(
              icon: Icons.warning_amber_rounded,
              title: 'Side Effects',
              value: sideEffects,
              isExpired: isExpired, // Pass the isExpired flag
            ),
            const SizedBox(height: 8),
            _buildPrescriptionDetail(
              icon: Icons.event_available,
              title: 'Expiry Date',
              value: expiryDate,
              isExpired: isExpired, // Pass the isExpired flag
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (isExpired) {
                    // Keep existing delete logic
                    try {
                      final response = await http.delete(
                        Uri.parse('$baseUrl/delete-prescriptions'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'user_id': userData?['user_id'],
                          'pres_id': presId,
                        }),
                      );
                      // ... (keep existing delete handling code)
                    } catch (e) {
                      // ... (keep existing error handling)
                    }
                  } else {
                    int selectedHour = TimeOfDay.now().hour;
                    int selectedMinute = TimeOfDay.now().minute;
                    bool isPM = TimeOfDay.now().period == DayPeriod.pm;
                    final existingReminders = await NotiService()
                        .getScheduledTimesForMedicine(medicineName);
                    List<TimeOfDay> scheduledTimes = [...existingReminders];
                    List<int> notificationIds = existingReminders
                        .map((time) =>
                            '$presId-${time.hour}-${time.minute}'.hashCode)
                        .toList();

                    await showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Set Reminder Times',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: ThemeConstants.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Display scheduled times
                                    if (scheduledTimes.isNotEmpty) ...[
                                      const Text(
                                        'Current Reminders:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Column(
                                        children: scheduledTimes.map((time) {
                                          final index =
                                              scheduledTimes.indexOf(time);
                                          return ListTile(
                                            leading: const Icon(
                                                Icons.notifications,
                                                color: ThemeConstants
                                                    .primaryColor),
                                            title: Text(time.format(context)),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.cancel,
                                                  color: Colors.red),
                                              onPressed: () async {
                                                await NotiService()
                                                    .cancelNotification(
                                                        notificationIds[index]);
                                                setState(() {
                                                  scheduledTimes
                                                      .removeAt(index);
                                                  notificationIds
                                                      .removeAt(index);
                                                });
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const Divider(),
                                    ],
                                    // Add Time button - opens time picker modal
                                    ElevatedButton(
                                      onPressed: () async {
                                        final time =
                                            await showDialog<TimeOfDay>(
                                          context: context,
                                          builder: (context) {
                                            int tempHour = selectedHour;
                                            int tempMinute = selectedMinute;
                                            bool tempIsPM = isPM;

                                            return Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(24),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Text(
                                                      'Select Time',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),

                                                    // Your custom time picker UI
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[50],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: ThemeConstants
                                                                .primaryColor
                                                                .withOpacity(
                                                                    0.05),
                                                            blurRadius: 10,
                                                            spreadRadius: 2,
                                                          ),
                                                        ],
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 16),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          // Hour picker
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                'Hour',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 8),
                                                              SizedBox(
                                                                height: 150,
                                                                width: 80,
                                                                child: // Hour Picker
// HOUR PICKER
                                                                    ListWheelScrollView
                                                                        .useDelegate(
                                                                  itemExtent:
                                                                      60,
                                                                  perspective:
                                                                      0.003,
                                                                  diameterRatio:
                                                                      2.0, // Makes the wheel appear flatter
                                                                  physics:
                                                                      const FixedExtentScrollPhysics(),
                                                                  onSelectedItemChanged:
                                                                      (index) {
                                                                    setState(() =>
                                                                        tempHour =
                                                                            index +
                                                                                1);
                                                                  },
                                                                  childDelegate:
                                                                      ListWheelChildBuilderDelegate(
                                                                    childCount:
                                                                        12,
                                                                    builder:
                                                                        (context,
                                                                            index) {
                                                                      final isCentered =
                                                                          tempHour ==
                                                                              index + 1;
                                                                      return Container(
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          // color: isCentered
                                                                          //     ? ThemeConstants.primaryColor.withOpacity(0.1)
                                                                          //     : Colors.transparent,
                                                                          borderRadius:
                                                                              BorderRadius.circular(12),
                                                                          // border: isCentered
                                                                          //     ? Border.all(
                                                                          //         color: ThemeConstants.primaryColor,
                                                                          //         width: 2,
                                                                          //       )
                                                                          //     : null,
                                                                        ),
                                                                        child:
                                                                            Center(
                                                                          child:
                                                                              Text(
                                                                            '${index + 1}'.padLeft(2,
                                                                                '0'),
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 24,
                                                                              fontWeight: FontWeight.normal,
                                                                              color: Colors.grey.shade600,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Container(
                                                            height: 100,
                                                            width: 1,
                                                            color: Colors
                                                                .grey[300],
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          // Minute picker
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                'Minute',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 8),
                                                              SizedBox(
                                                                  height: 150,
                                                                  width: 80,
                                                                  child: ListWheelScrollView
                                                                      .useDelegate(
                                                                    itemExtent:
                                                                        60,
                                                                    diameterRatio:
                                                                        2.0,
                                                                    physics:
                                                                        const FixedExtentScrollPhysics(),
                                                                    onSelectedItemChanged:
                                                                        (index) {
                                                                      setState(() =>
                                                                          tempMinute =
                                                                              index * 5);
                                                                    },
                                                                    childDelegate:
                                                                        ListWheelChildBuilderDelegate(
                                                                      childCount:
                                                                          12,
                                                                      builder:
                                                                          (context,
                                                                              index) {
                                                                        final minuteValue =
                                                                            index *
                                                                                5;
                                                                        final isCentered =
                                                                            tempMinute ==
                                                                                minuteValue;
                                                                        return Container(
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            // color: isCentered
                                                                            //     ? ThemeConstants.primaryColor.withOpacity(0.1)
                                                                            //     : Colors.transparent,
                                                                            borderRadius:
                                                                                BorderRadius.circular(12),
                                                                            // border: isCentered
                                                                            //     ? Border.all(
                                                                            //         color: ThemeConstants.primaryColor,
                                                                            //         width: 2,
                                                                            //       )
                                                                            //     : null,
                                                                          ),
                                                                          child:
                                                                              Center(
                                                                            child:
                                                                                Text(
                                                                              minuteValue.toString().padLeft(2, '0'),
                                                                              style: TextStyle(
                                                                                fontSize: 24,
                                                                                fontWeight: FontWeight.normal,
                                                                                color: Colors.grey.shade600,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                    ),
                                                                  )),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    // AM/PM selector
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[100],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          _buildPeriodButton(
                                                            label: 'AM',
                                                            isSelected:
                                                                !tempIsPM,
                                                            onTap: () =>
                                                                setState(() =>
                                                                    tempIsPM =
                                                                        false),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _buildPeriodButton(
                                                            label: 'PM',
                                                            isSelected:
                                                                tempIsPM,
                                                            onTap: () =>
                                                                setState(() =>
                                                                    tempIsPM =
                                                                        true),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child: const Text(
                                                              'Cancel'),
                                                        ),
                                                        const SizedBox(
                                                            width: 16),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            final hour = tempIsPM
                                                                ? (tempHour ==
                                                                        12
                                                                    ? 12
                                                                    : tempHour +
                                                                        12)
                                                                : (tempHour ==
                                                                        12
                                                                    ? 0
                                                                    : tempHour);
                                                            Navigator.pop(
                                                                context,
                                                                TimeOfDay(
                                                                  hour: hour,
                                                                  minute:
                                                                      tempMinute,
                                                                ));
                                                          },
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                ThemeConstants
                                                                    .primaryColor,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            'Confirm',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );

                                        if (time != null &&
                                            !scheduledTimes.contains(time)) {
                                          setState(() {
                                            scheduledTimes.add(time);
                                            notificationIds.add(
                                                '$presId-${time.hour}-${time.minute}'
                                                    .hashCode);
                                          });
                                        }
                                      },
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty
                                            .resolveWith<Color>((states) {
                                          if (states
                                              .contains(WidgetState.pressed)) {
                                            return ThemeConstants.primaryColor
                                                .withOpacity(
                                                    0.2); // 20% darker when pressed
                                          }
                                          return ThemeConstants.primaryColor
                                              .withOpacity(
                                                  0.1); // Default 10% opacity
                                        }),
                                        foregroundColor:
                                            WidgetStateProperty.all(
                                                ThemeConstants.primaryColor),
                                        elevation: WidgetStateProperty.all(
                                            0), // No shadow ever
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 14),
                                        ),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: BorderSide(
                                              color: ThemeConstants.primaryColor
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        overlayColor: WidgetStateProperty.all(Colors
                                            .transparent), // Disable ripple effect
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 20),
                                          SizedBox(width: 10),
                                          Text(
                                            'Add Time',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Action buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        const SizedBox(width: 16),
                                        ElevatedButton(
                                          onPressed: () async {
                                            if (scheduledTimes.isNotEmpty) {
                                              for (int i = 0;
                                                  i < scheduledTimes.length;
                                                  i++) {
                                                await NotiService()
                                                    .scheduleNotification(
                                                  id: notificationIds[i],
                                                  title: 'Medicine Reminder',
                                                  body:
                                                      'Time to take $medicineName',
                                                  hour: scheduledTimes[i].hour,
                                                  minute:
                                                      scheduledTimes[i].minute,
                                                );
                                              }
                                              Navigator.pop(
                                                  context, scheduledTimes);
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Please add at least one time'),
                                                ),
                                              );
                                            }
                                            _fetchReminders();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                ThemeConstants.primaryColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Save',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor:
                      isExpired ? Colors.red : ThemeConstants.primaryColor,
                ),
                child: Text(
                  isExpired ? 'Delete Prescription' : 'Set Reminders',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionDetail({
    required IconData icon,
    required String title,
    required String value,
    required bool isExpired, // Add this parameter
  }) {
    String displayValue = value;
    String daysRemaining = '';
    Color? textColor =
        isExpired ? Colors.red[700] : Colors.grey[600]; // Modified
    Color? iconColor =
        isExpired ? Colors.red[700] : Colors.grey[600]; // Modified

    if (title == 'Expiry Date' && value.isNotEmpty) {
      try {
        final parts = value.split(' ');
        if (parts.length == 3) {
          const months = {
            'Jan': 1,
            'Feb': 2,
            'Mar': 3,
            'Apr': 4,
            'May': 5,
            'Jun': 6,
            'Jul': 7,
            'Aug': 8,
            'Sep': 9,
            'Oct': 10,
            'Nov': 11,
            'Dec': 12
          };
          displayValue = value; // Keep original format

          final expiryDateTime = DateTime(
            int.parse(parts[2]),
            months[parts[1]] ?? 1,
            int.parse(parts[0]),
          );
          final daysLeft = expiryDateTime.difference(DateTime.now()).inDays;

          if (daysLeft < 0) {
            daysRemaining = 'EXPIRED';
            textColor = Colors.red;
          } else {
            daysRemaining = '$daysLeft days remaining';
            textColor = isExpired
                ? Colors.red[700]
                : (daysLeft < 30 ? Colors.orange : Colors.grey[600]);
          }
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor, // Use the modified icon color
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired
                      ? Colors.red[600]
                      : Colors.grey[600], // Modified
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: title == 'Expiry Date' ? FontWeight.w500 : null,
                ),
              ),
              if (daysRemaining.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  daysRemaining,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: ThemeConstants.primaryColor,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? ThemeConstants.primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : ThemeConstants.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
