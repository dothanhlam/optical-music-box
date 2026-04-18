import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../audio/audio_manager.dart';
import '../engine/dot_detector.dart';
import '../engine/note_trigger.dart';
import '../ui/playhead_painter.dart';

class MusicBoxScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MusicBoxScreen({super.key, required this.cameras});

  @override
  State<MusicBoxScreen> createState() => _MusicBoxScreenState();
}

class _MusicBoxScreenState extends State<MusicBoxScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _permissionGranted = false;

  late final AudioManager _audioManager;
  late final NoteTrigger _noteTrigger;
  late final DotDetector _dotDetector;

  // One AnimationController per zone for the glow/pulse effect
  late List<AnimationController> _pulseControllers;
  late List<Animation<double>> _pulseAnimations;

  // Current active zone flags (for painter)
  List<bool> _activeZones = List.filled(5, false);

  // Throttle: process at most 1 frame per 33ms (≈30fps analysis)
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager();
    _dotDetector = DotDetector();
    _noteTrigger = NoteTrigger(audioManager: _audioManager);

    // Set up 5 pulse animations
    _pulseControllers = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
    });
    _pulseAnimations = _pulseControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.55).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();

    _init();
  }

  Future<void> _init() async {
    await _audioManager.init();
    await _requestPermissionAndStartCamera();
  }

  Future<void> _requestPermissionAndStartCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _permissionGranted = false);
      return;
    }
    setState(() => _permissionGranted = true);
    await _startCamera();
  }

  Future<void> _startCamera() async {
    if (widget.cameras.isEmpty) return;

    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      await _controller!.startImageStream(_onFrameReceived);
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera start error: $e');
    }
  }

  void _onFrameReceived(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 33) return;
    _lastFrameTime = now;

    final detected = _dotDetector.detect(image);
    final triggered = _noteTrigger.process(detected);

    // Only rebuild UI if something changed
    if (!_listEqual(detected, _activeZones)) {
      setState(() => _activeZones = detected);
    }

    // Fire pulse animations for newly triggered zones
    for (int i = 0; i < 5; i++) {
      if (triggered[i]) {
        _pulseControllers[i].forward(from: 0.0);
      }
    }
  }

  bool _listEqual(List<bool> a, List<bool> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final c in _pulseControllers) {
      c.dispose();
    }
    _controller?.stopImageStream();
    _controller?.dispose();
    _audioManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_permissionGranted) {
      return _buildPermissionDenied();
    }
    if (!_isInitialized || _controller == null) {
      return _buildLoading();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(),
        _buildPlayheadOverlay(),
        _buildSensorZoneOverlay(),
        _buildHeader(),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final previewAspect = _controller!.value.aspectRatio;
    return OverflowBox(
      maxWidth: size.width,
      maxHeight: size.height,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.width / previewAspect,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildPlayheadOverlay() {
    return CustomPaint(
      painter: PlayheadPainter(activeZones: _activeZones),
    );
  }

  Widget _buildSensorZoneOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      final playheadX = constraints.maxWidth / 2;
      const stripWidth = 70.0;
      final zonePositions =
          DotDetector.computeZoneCenters(constraints.maxHeight);

      return Stack(
        children: List.generate(5, (i) {
          final color = PlayheadPainter.zoneColors[i];
          return AnimatedBuilder(
            animation: _pulseAnimations[i],
            builder: (context, child) {
              final scale = _pulseAnimations[i].value;
              final isActive = _activeZones[i];
              return Positioned(
                left: playheadX - stripWidth / 2 - 2,
                top: zonePositions[i] - 24,
                child: Transform.scale(
                  scale: scale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? color.withValues(alpha: 0.92)
                          : color.withValues(alpha: 0.35),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.85),
                                blurRadius: 22,
                                spreadRadius: 8,
                              ),
                            ]
                          : [],
                      border: Border.all(
                        color: color.withValues(alpha: 0.8),
                        width: 2.5,
                      ),
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 80),
                        style: TextStyle(
                          fontSize: isActive ? 18 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        child: Text(PlayheadPainter.noteNames[i]),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      );
    });
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 6),
              Text(
                'Optical Music Box',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Starting camera…',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_rounded,
                size: 64, color: Colors.white38),
            const SizedBox(height: 24),
            const Text(
              'Camera access is needed\nto detect the dots.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 17),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermissionAndStartCamera,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}
