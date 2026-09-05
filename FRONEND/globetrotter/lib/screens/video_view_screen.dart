import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Plays a chat video inline instead of just telling the user to go
/// download it manually. The download button still exists for saving it
/// to the device, but tapping the video itself now actually shows it.
class VideoViewScreen extends StatefulWidget {
  final String url;
  const VideoViewScreen({super.key, required this.url});

  @override
  State<VideoViewScreen> createState() => _VideoViewScreenState();
}

class _VideoViewScreenState extends State<VideoViewScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final uri = Uri.parse(widget.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir : ${widget.url}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Vidéo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Télécharger',
            onPressed: _download,
          ),
        ],
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                    const SizedBox(height: 12),
                    const Text('Impossible de lire cette vidéo.',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _download,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Télécharger à la place'),
                    ),
                  ],
                ),
              )
            : !_ready
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio == 0
                        ? 16 / 9
                        : _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller),
                        GestureDetector(
                          onTap: () => _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play(),
                          child: AnimatedOpacity(
                            opacity: _controller.value.isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              color: Colors.black26,
                              child: const Icon(Icons.play_arrow,
                                  color: Colors.white70, size: 64),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: VideoProgressIndicator(_controller, allowScrubbing: true),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
