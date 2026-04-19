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
  bool _showTuning = false;

  late final AudioManager _audioManager;
  late final NoteTrigger _noteTrigger;
  late final DotDetector _dotDetector;

  // ── Tuning State ──────────────────────────────────────────────────────────
  double _threshold = 0.35; // 0.0 (black) to 1.0 (white)
  double _spacing = 0.7;   // 0.1 to 1.0
  double _offset = 0.0;    // -1.0 to 1.0
  double _playheadYOffset = 0.5; // 0.1 to 0.9

  // ── Pulse Animations ──────────────────────────────────────────────────────
  late List<AnimationController> _pulseControllers;
  late List<Animation<double>> _pulseAnimations;

  // Current detection results
  List<bool> _activeZones = List.filled(5, false);
  List<double> _luminanceLevels = List.filled(5, 1.0);

  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager();
    _dotDetector = DotDetector();
    _noteTrigger = NoteTrigger(audioManager: _audioManager);

    _pulseControllers = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
    });
    _pulseAnimations = _pulseControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.5).animate(
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
    if (now.difference(_lastFrameTime).inMilliseconds < 40) return; // ~25fps analysis
    _lastFrameTime = now;

    final result = _dotDetector.detect(
      image,
      threshold: _threshold,
      spacing: _spacing,
      offset: _offset,
      sensorOrientation: _controller!.description.sensorOrientation,
      playheadFraction: _playheadYOffset,
    );

    final triggered = _noteTrigger.process(result.detected);

    // Update UI state
    setState(() {
      _activeZones = result.detected;
      _luminanceLevels = result.luminance;
    });

    for (int i = 0; i < 5; i++) {
      if (triggered[i]) {
        _pulseControllers[i].forward(from: 0.0);
      }
    }
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
    if (!_permissionGranted) return _buildPermissionDenied();
    if (!_isInitialized || _controller == null) return _buildLoading();

    final aspect = _controller!.value.aspectRatio;
    // CameraPreview defaults to landscape ratio on some devices. 
    // We force a portrait aspect ratio for the container to avoid stretching.
    final portraitAspect = aspect > 1 ? 1 / aspect : aspect;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: portraitAspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                _buildPlayheadOverlay(),
                _buildSensorHighlights(),
              ],
            ),
          ),
        ),
        _buildUI(),
      ],
    );
  }

  Widget _buildPlayheadOverlay() {
    return CustomPaint(
      painter: PlayheadPainter(
        activeZones: _activeZones,
        luminanceLevels: _luminanceLevels,
        spacing: _spacing,
        offset: _offset,
        threshold: _threshold,
        playheadYOffset: _playheadYOffset,
      ),
    );
  }

  Widget _buildSensorHighlights() {
    return LayoutBuilder(builder: (context, constraints) {
      final playheadY = constraints.maxHeight * _playheadYOffset;
      final zonePositions = DotDetector.computeZoneCenters(
        constraints.maxWidth,
        _spacing,
        _offset,
      );

      return Stack(
        children: List.generate(5, (i) {
          final color = PlayheadPainter.zoneColors[i];
          final isActive = _activeZones[i];
          
          return AnimatedBuilder(
            animation: _pulseAnimations[i],
            builder: (context, child) {
              final scale = _pulseAnimations[i].value;
              return Positioned(
                left: zonePositions[i] - 21,
                top: playheadY - 21,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? color.withValues(alpha: 0.8) : Colors.transparent,
                      boxShadow: isActive ? [
                        BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 6),
                      ] : [],
                      border: Border.all(
                        color: isActive ? color : color.withValues(alpha: 0.3),
                        width: isActive ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        PlayheadPainter.noteNames[i],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isActive ? 16 : 12,
                        ),
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

  Widget _buildUI() {
    return Stack(
      children: [
        _buildHeader(),
        _buildTuningButton(),
        if (_showTuning) _buildTuningTray(),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Optical Music Box',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTuningButton() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton(
        onPressed: () => setState(() => _showTuning = !_showTuning),
        backgroundColor: Colors.white24,
        child: Icon(_showTuning ? Icons.close : Icons.tune, color: Colors.white),
      ),
    );
  }

  Widget _buildTuningTray() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        width: 280,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tuning Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            _buildSlider('Sensitivity', _threshold, (v) => setState(() => _threshold = v)),
            _buildSlider('Spacing', _spacing, (v) => setState(() => _spacing = v)),
            _buildSlider('Horizontal Pos', _offset, (v) => setState(() => _offset = v), min: -1, max: 1),
            _buildSlider('Playhead Height', _playheadYOffset, (v) => setState(() => _playheadYOffset = v), min: 0.1, max: 0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double val, ValueChanged<double> onChanged, {double min = 0, double max = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(value: val, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: ElevatedButton(
        onPressed: _requestPermissionAndStartCamera,
        child: const Text('Grant Camera Permission'),
      ),
    );
  }
}
