import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_svg/flutter_svg.dart';
import 'constants.dart';
import 'theme_constants.dart';

class MedicineNameCheck extends StatefulWidget {
  const MedicineNameCheck({Key? key}) : super(key: key);

  @override
  State<MedicineNameCheck> createState() => _MedicineNameReader();
}

class _MedicineNameReader extends State<MedicineNameCheck>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isLoading = false;
  String? _medName;
  String? _error;
  bool _isTapped = false;
  int? bottomHeight = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Size? previewSize;
  double? previewWidth;
  double? previewHeight;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller?.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          previewSize = _controller?.value.previewSize;
          previewWidth = previewSize?.width;
          previewHeight = previewSize?.height;
          bottomHeight = 165;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error initializing camera: $e';
      });
    }
  }

  Future<void> _captureAndCheckExpiry() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _medName = null;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) throw Exception('Failed to decode image');

      final double boxHeight = originalImage.width * 0.9;
      final double boxWidth = originalImage.width * 0.9;
      final double xStart = (originalImage.width - boxWidth) / 2;
      final double yStart = (originalImage.height - boxHeight) / 2;

      final img.Image croppedImage = img.copyCrop(
        originalImage,
        x: xStart.round(),
        y: yStart.round(),
        width: boxWidth.round(),
        height: boxHeight.round(),
      );

      final croppedBytes = Uint8List.fromList(img.encodeJpg(croppedImage));

      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/medicine-name-reader'));
      request.files.add(http.MultipartFile.fromBytes('file', croppedBytes,
          filename: 'image.jpg'));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.statusCode == 200 && jsonData['success']) {
            _medName = jsonData['medicine_name'] ?? 'No medicine name detected';
          } else {
            _error = jsonData['error'] ?? 'Failed to process image';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error processing image: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Medicine Name Reader',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: ThemeConstants.primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildScanningBox(),
          _buildBottomPanel(),
        ],
      ),
    );
  }
Widget _buildCameraError() {
  return Container(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          const Text(
            'Camera Error',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error ?? 'Failed to initialize camera',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _initializeCamera,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConstants.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Go Back',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCameraPreview() {
  return FutureBuilder<void>(
    future: _initializeControllerFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        if (_controller == null || !_controller!.value.isInitialized) {
          return _buildCameraError();
        }

        // Get screen size
        final screenSize = MediaQuery.of(context).size;
        final cameraRatio = _controller!.value.aspectRatio;
        // final screenRatio = screenSize.height / screenSize.width;
        final screenRatio = screenSize.width / screenSize.height;

        return Stack(
          children: [
            // Fullscreen camera preview (may extend beyond screen bounds)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: (cameraRatio > screenRatio 
                      ? screenSize.width * cameraRatio
                      : screenSize.height) - 250,
                  height: cameraRatio > screenRatio
                      ? screenSize.height
                      : screenSize.width / cameraRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
            
            // Darken areas outside the scanning box
            _buildScanningOverlay(),
          ],
        );
      }
      return _buildLoadingIndicator();
    },
  );
}

Widget _buildLoadingIndicator() {
  return Container(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeConstants.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Initializing Camera',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildScanningOverlay() {
  final screenWidth = MediaQuery.of(context).size.width;
  final boxSize = screenWidth * 0.8;
  final boxTop = (MediaQuery.of(context).size.height - boxSize) / 3;
  final boxBottom = (MediaQuery.of(context).size.height - boxSize) / 2;

  return Stack(
    children: [
      // Top dark overlay
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: boxTop,
        child: _buildBlurOverlay(),
      ),
      
      // Bottom dark overlay
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: boxBottom,
        child: _buildBlurOverlay(),
      ),
      
      // Left dark overlay
      Positioned(
        top: boxTop,
        bottom: boxBottom,
        left: 0,
        width: (screenWidth - boxSize) / 2,
        child: _buildBlurOverlay(),
      ),
      
      // Right dark overlay
      Positioned(
        top: boxTop,
        bottom: boxBottom,
        right: 0,
        width: (screenWidth - boxSize) / 2,
        child: _buildBlurOverlay(),
      ),
      
    ],
  );
}

Widget _buildBlurOverlay() {
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: 20.0, // Adjust blur intensity (higher = more blur)
        sigmaY: 20.0,
      ),
      child: Container(
        // color: Colors.black.withOpacity(0.3), // Optional: Add slight darkening
      ),
    ),
  );
}

Widget _buildScanningBox() {
  final screenWidth = MediaQuery.of(context).size.width;
  final boxSize = screenWidth * 0.8;

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTapDown: _isLoading ? null : (details) {
            _animationController.forward();
            setState(() => _isTapped = true);
          },
          onTapUp: _isLoading ? null : (details) {
            _animationController.reverse();
            setState(() => _isTapped = false);
            _captureAndCheckExpiry();
          },
          onTapCancel: () {
            _animationController.reverse();
            setState(() => _isTapped = false);
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: ThemeConstants.primaryColor,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(12),
                // Remove or reduce BoxShadow if it's causing a "double box" effect
                boxShadow: [
                  BoxShadow(
                    color: ThemeConstants.primaryColor.withOpacity(0.1), // Reduced opacity
                    blurRadius: 10, // Reduced blur
                    spreadRadius: 1, // Reduced spread
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner decorations (ensure they don't add extra borders)
                  Positioned(top: 0, left: 0, child: _buildCornerDecoration(true, true)),
                  Positioned(top: 0, right: 0, child: _buildCornerDecoration(true, false)),
                  Positioned(bottom: 0, left: 0, child: _buildCornerDecoration(false, true)),
                  Positioned(bottom: 0, right: 0, child: _buildCornerDecoration(false, false)),
                  
                  // Loading overlay
                  if (_isLoading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reading Medicine Name',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please wait...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Align medicine within the frame',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ensure medicine name is clearly visible',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    ),
  );
}
  Widget _buildCornerDecoration(bool isTop, bool isLeft) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ThemeConstants.primaryColor,
            width: isTop ? 3 : 0,
          ),
          left: BorderSide(
            color: ThemeConstants.primaryColor,
            width: isLeft ? 3 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black,
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? const SizedBox()
              : _error != null
                  ? _buildErrorPanel()
                  : _medName != null
                      ? _buildResultPanel()
                      : _buildInstructionsPanel(),
        ),
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[300]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'An error occurred',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _medName = null;
              });
            },
            child: Text(
              'TRY AGAIN',
              style: TextStyle(color: Colors.red[300]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    String formattedName = _medName!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: ThemeConstants.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'MEDICINE NAME FOUND',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formattedName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _medName = null;
                    });
                  },
                  child: const Text('SCAN AGAIN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _medName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConstants.primaryColor,
                  ),
                  child: const Text(
                    'CONFIRM',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsPanel() {
  final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/tap_gesture.svg',
          height: 40,
          color: Colors.white.withOpacity(0.7),
        ),
        SizedBox(height: 12, width: screenWidth),
        Text(
          'Tap to scan medicine name',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }


}
