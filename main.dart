import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CapCutApp());
}

class CapCutApp extends StatelessWidget {
  const CapCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CapCut Clone',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const VideoEditorScreen(),
    );
  }
}

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _controller;
  File? _selectedVideo;
  bool _isProcessing = false;
  double _startCut = 0.0;
  double _endCut = 5.0;
  double _maxDuration = 10.0;

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final file = File(video.path);
      final controller = VideoPlayerController.file(file);

      await controller.initialize();
      setState(() {
        _selectedVideo = file;
        _controller = controller;
        _maxDuration = controller.value.duration.inSeconds.toDouble();
        _startCut = 0.0;
        _endCut = _maxDuration > 5.0 ? 5.0 : _maxDuration;
      });
      _controller?.play();
      _controller?.setLooping(true);
    }
  }

  Future<void> _exportTrimmedVideo() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isProcessing = true;
    });

    final Directory tempDir = await getTemporaryDirectory();
    final String outputPath =
        '${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    double duration = _endCut - _startCut;

    String ffmpegCmd =
        "-ss $_startCut -i '${_selectedVideo!.path}' -t $duration -c copy '$outputPath'";

    await FFmpegKit.execute(ffmpegCmd).then((session) async {
      final returnCode = await session.getReturnCode();
      setState(() {
        _isProcessing = false;
      });

      if (ReturnCode.isSuccess(returnCode)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video Exported Successfully:\n$outputPath')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export video')),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CapCut Clone MVP"),
        actions: [
          if (_selectedVideo != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _isProcessing ? null : _exportTrimmedVideo,
            )
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("FFmpeg Exporting Video..."),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _selectedVideo != null &&
                          _controller != null &&
                          _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : Center(
                          child: ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.video_library),
                            label: const Text("Select Video from Gallery"),
                          ),
                        ),
                ),
                if (_selectedVideo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black26,
                    child: Column(
                      children: [
                        Text(
                          "Trim: ${_startCut.toStringAsFixed(1)}s to ${_endCut.toStringAsFixed(1)}s",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        RangeSlider(
                          values: RangeValues(_startCut, _endCut),
                          min: 0.0,
                          max: _maxDuration,
                          onChanged: (RangeValues values) {
                            setState(() {
                              _startCut = values.start;
                              _endCut = values.end;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickVideo,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Change Video"),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                              ),
                              onPressed: _exportTrimmedVideo,
                              icon: const Icon(Icons.check),
                              label: const Text("Export MP4"),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ]
              ],
            ),
    );
  }
}
