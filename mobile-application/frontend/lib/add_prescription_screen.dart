import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'theme_constants.dart';
import 'constants.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'expiry-date-check.dart';
import 'medicine-name-reader.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final String username;
  final String password;
  final String userId;

  const AddPrescriptionScreen({
    Key? key,
    required this.username,
    required this.password,
    required this.userId,
  }) : super(key: key);

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _sideEffectsController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  late stt.SpeechToText _speech;
  final bool _isListening = false;
  final String _transcription = '';
  final AudioRecorder audioRecorder = AudioRecorder();
  List<String> _similarMatches = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _sideEffectsController.dispose();
    _frequencyController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<bool> _checkPermission() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  Future<void> _addPrescription() async {
    if (_medicineNameController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _sideEffectsController.text.isEmpty ||
        _frequencyController.text.isEmpty ||
        _expiryDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-prescription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'password': widget.password,
          'user_id': widget.userId,
          'med_name': _medicineNameController.text,
          'recommended_dosage': _dosageController.text,
          'side_effects': _sideEffectsController.text,
          'frequency': int.parse(_frequencyController.text),
          'expiry_date': _expiryDateController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prescription added successfully'),
              backgroundColor: ThemeConstants.primaryColor,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to add prescription: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding prescription: $e')),
        );
      }
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Lottie.asset(
                    'assets/listening.json',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hearing your whispers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Prescription',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: ThemeConstants.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Top section with modern design
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ThemeConstants.primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: ThemeConstants.primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background decoration
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
                  // Content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            size: 50,
                            color: ThemeConstants.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Add New Prescription',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose your preferred method',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom section with options
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.mic,
                    title: 'Voice Input',
                    subtitle: 'Dictate your prescription details',
                    onTap: _showRecordingModal,
                  ),
                  _buildOptionButton(
                    icon: Icons.edit,
                    title: 'Manual Entry',
                    subtitle: 'Type in prescription details',
                    onTap: () => _showPrescriptionForm(
                        isPrefilled: false, similarMatches: []),
                  ),
                  _buildOptionButton(
                      icon: Icons.camera_alt,
                      title: 'Scan Prescription',
                      subtitle: 'Coming Soon',
                      onTap: () {
                        // TODO: Implement camera capture
                        // _showPrescriptionForm(
                        //     isPrefilled: true, similarMatches: []);
                      },
                      enabled: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: ThemeConstants.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrescriptionForm(
      {required bool isPrefilled, List<String>? similarMatches}) {
    // If isPrefilled is true, we would pre-populate the fields with detected/dictated data
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPrefilled ? 'Review Details' : 'Enter Details',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (isPrefilled &&
                          similarMatches != null &&
                          similarMatches.isNotEmpty) ...[
                        const Text(
                          'Similar Medicine Names',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ThemeConstants.primaryColor,
                                  side: const BorderSide(
                                      color: ThemeConstants.primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ), // Keep current name
                                child: const Text('None'),
                              ),
                              const SizedBox(width: 8),
                              ...similarMatches
                                  .map(
                                    (name) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          setState(() {
                                            _medicineNameController.text = name;
                                          });
                                          await _getMedicineDetails(name);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              ThemeConstants.primaryColor,
                                          side: const BorderSide(
                                              color:
                                                  ThemeConstants.primaryColor),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: Text(name),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildInputField(
                        controller: _medicineNameController,
                        label: 'Medicine Name',
                        icon: Icons.medication,
                        suffix: IconButton(
                          icon: const Icon(Icons.document_scanner),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MedicineNameCheck(),
                              ),
                            );
                            final medicine_name =
                                json.decode(result)["medicine_name"];
                            final recommended_dosage =
                                json.decode(result)["recommended_dosage"];
                            final side_effects =
                                json.decode(result)["side_effects"];
                            final List<String> similarMatches = (json.decode(result)['similar-matches'] as List<dynamic>? ?? [])
                                .whereType<String>() // Ensure we only get strings
                                .where((match) => match.isNotEmpty) // Filter out empty matches
                                .toList();
                            
                            if (result != null) {
                              setState(() {
                                _medicineNameController.text = medicine_name;
                                _dosageController.text = recommended_dosage;
                                _sideEffectsController.text = side_effects;
                                _similarMatches = similarMatches;
                              });
                              print(_similarMatches.length);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _dosageController,
                        label: 'Recommended Dosage',
                        icon: Icons.schedule,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _sideEffectsController,
                        label: 'Side Effects',
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _frequencyController,
                        label: 'Frequency (times per day)',
                        icon: Icons.repeat,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _expiryDateController,
                        label: 'Expiry Date',
                        icon: Icons.calendar_today,
                        suffix: IconButton(
                          icon: const Icon(Icons.document_scanner),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ExpiryDateCheck(),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                _expiryDateController.text = result +
                                    " 00:00:00"; // Append time to match expected format
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          _addPrescription();
                          Navigator.pop(
                              context); // Close the bottom sheet first
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add Prescription',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(
                          height: 16), // Add padding for bottom safe area
                      SizedBox(
                          height: MediaQuery.of(context)
                              .viewInsets
                              .bottom), // Handle keyboard
                    ],
                  ),
                ),
              ),
            ));
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: ThemeConstants.primaryColor),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ThemeConstants.primaryColor),
          ),
        ),
      ),
    );
  }

  // Future<void> _handleAudioUpload(String transcription) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/transcribe'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'transcription': transcription,
  //       }),
  //     );
  //     Navigator.of(context).pop(); // Close loading dialog
  //     if (response.statusCode == 200) {
  //       var responseData = await response.body;
  //       _handleVoiceApiResponse(responseData);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to send recording')),
  //       );
  //     }
  //   } catch (e) {
  //     Navigator.of(context).pop(); // Close loading dialog on error
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Error uploading recording')),
  //     );
  //   }
  // }

  void _showRecordingModal() {
    bool localIsRecording = false;
    int remainingSeconds = 30;
    String recognizedText = '';
    final stt.SpeechToText speech = stt.SpeechToText();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    const Column(
                      children: [
                        Text(
                          'Voice Prescription',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeConstants.primaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Speak clearly into your microphone',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Timer and Recording Indicator
                    if (localIsRecording)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle,
                                    size: 12, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text(
                                  'RECORDING',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$remainingSeconds s',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Microphone Button
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: (localIsRecording
                                ? Colors.red
                                : ThemeConstants.primaryColor)
                            .withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (localIsRecording)
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: remainingSeconds / 30,
                                strokeWidth: 4,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.red),
                              ),
                            ),
                          IconButton(
                            iconSize: 48,
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                    scale: animation, child: child);
                              },
                              child: Icon(
                                localIsRecording ? Icons.stop : Icons.mic,
                                key: ValueKey<bool>(localIsRecording),
                                color: localIsRecording
                                    ? Colors.red
                                    : ThemeConstants.primaryColor,
                              ),
                            ),
                            onPressed: () async {
                              if (!localIsRecording) {
                                bool available = await speech.initialize(
                                  onStatus: (status) {
                                    if (status == 'done') {
                                      setDialogState(() {
                                        localIsRecording = false;
                                      });
                                      Navigator.of(context).pop();
                                      _showProcessingDialog();
                                      _handleRecognizedText(recognizedText);
                                    }
                                  },
                                  onError: (error) {
                                    setDialogState(() {
                                      localIsRecording = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $error')),
                                    );
                                  },
                                );

                                if (available) {
                                  setDialogState(() {
                                    localIsRecording = true;
                                    recognizedText = '';
                                    remainingSeconds = 30;
                                  });

                                  speech.listen(
                                    onResult: (result) {
                                      setDialogState(() {
                                        recognizedText = result.recognizedWords;
                                      });
                                    },
                                    listenFor: const Duration(seconds: 30),
                                  );

                                  Timer.periodic(const Duration(seconds: 1),
                                      (timer) {
                                    if (!localIsRecording ||
                                        remainingSeconds <= 0) {
                                      timer.cancel();
                                      if (remainingSeconds <= 0) {
                                        speech.stop();
                                      }
                                      return;
                                    }
                                    setDialogState(() {
                                      remainingSeconds--;
                                    });
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Speech recognition not available')),
                                  );
                                }
                              } else {
                                speech.stop();
                                setDialogState(() {
                                  localIsRecording = false;
                                });
                                Navigator.of(context).pop();
                                _showProcessingDialog();
                                _handleRecognizedText(recognizedText);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Transcription Section
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: recognizedText.isNotEmpty || localIsRecording
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TRANSCRIPTION',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    recognizedText.isNotEmpty
                                        ? recognizedText
                                        : 'Listening for speech...',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (recognizedText.isNotEmpty)
                                    const SizedBox(height: 16),
                                  if (recognizedText.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: const Text('Edit Text'),
                                        onPressed: () {
                                          // Add your edit functionality here
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              ThemeConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRecognizedText(String transcription) async {
    // Validate transcription first
    if (transcription.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No speech was detected. Please try again.')),
        );
      }
      return;
    }

    // Show loading dialog
    if (context.mounted) {
      _showProcessingDialog();
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transcribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'transcription': transcription}),
          )
          .timeout(const Duration(seconds: 30)); // Add timeout

      if (!context.mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200) {
        final responseData = response.body;
        print(responseData);
        _handleVoiceApiResponse(responseData);
      } else {
        final errorMessage = _getErrorMessageFromResponse(response);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process: $errorMessage')),
        );
      }
    } on TimeoutException {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Please try again.')),
        );
      }
    } on http.ClientException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: ${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred')),
        );
        debugPrint('Error in _handleRecognizedText: $e');
      }
    }
  }

// Helper function to extract error message from response
  String _getErrorMessageFromResponse(http.Response response) {
    try {
      final errorResponse = jsonDecode(response.body);
      return errorResponse['message'] ??
          errorResponse['error'] ??
          'Status code: ${response.statusCode}';
    } catch (_) {
      return 'Status code: ${response.statusCode}';
    }
  }

  void _handleVoiceApiResponse(String responseData) {
    try {
      final jsonResponse = jsonDecode(responseData) as Map<String, dynamic>;
      debugPrint('API Response: $jsonResponse');

      // Type-safe extraction with fallbacks
      final medicineName = jsonResponse['med_name']?.toString() ?? '';
      final frequency = jsonResponse['frequency']?.toString() ?? '';
      final dosage = jsonResponse['recommended_dosage']?.toString() ?? '';
      final sideEffects = jsonResponse['side_effects']?.toString() ?? '';

      // Extract similar matches with type safety
      final similarMatches =
          (jsonResponse['similar-matches'] as List<dynamic>? ?? [])
              .whereType<String>() // Ensure we only get strings
              .where((match) => match.isNotEmpty) // Filter out empty matches
              .toList();

      // Update controllers
      _medicineNameController.text = medicineName;
      _frequencyController.text = frequency;
      _dosageController.text = dosage;
      _sideEffectsController.text = sideEffects;

      // Show the form with similar matches
      if (context.mounted) {
        _showPrescriptionForm(
          isPrefilled: true,
          similarMatches: similarMatches,
        );
      }
    } catch (e) {
      debugPrint('Error parsing API response: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing API response')),
        );
      }
    }
  }

// Helper function to parse API error responses
  String _parseApiError(http.Response response) {
    try {
      final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
      return errorResponse['message']?.toString() ??
          errorResponse['error']?.toString() ??
          'Status code: ${response.statusCode}';
    } catch (e) {
      return 'Status code: ${response.statusCode}';
    }
  }

  Future<void> _getMedicineDetails(String medicineName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get-medicine?med_name=$medicineName'),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        setState(() {
          _dosageController.text = jsonResponse['recommended_dosage'] ?? '';
          _sideEffectsController.text = jsonResponse['side_effects'] ?? '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching medicine details')),
      );
    }
  }
}
