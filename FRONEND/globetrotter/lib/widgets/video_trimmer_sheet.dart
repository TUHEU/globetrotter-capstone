import 'package:flutter/material.dart';
import 'dart:io';

/// Feuille de sélection pour couper/éditer vidéo avant envoi dans le chat.
/// Inspirée de WhatsApp : permettre de garder la vidéo entière ou de la couper.
class VideoTrimmerSheet extends StatefulWidget {
  final String videoPath;
  final Function(String trimmedPath, bool sendFull) onConfirm;
  final VoidCallback onCancel;

  const VideoTrimmerSheet({
    Key? key,
    required this.videoPath,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<VideoTrimmerSheet> createState() => _VideoTrimmerSheetState();
}

class _VideoTrimmerSheetState extends State<VideoTrimmerSheet> {
  bool _sendFullVideo = true;
  double _startTrim = 0.0;
  double _endTrim = 100.0;
  bool _isTrimming = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Éditer vidéo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Video preview / thumbnail
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(
                          File(widget.videoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.videocam,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_outline,
                          size: 60,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),

                // Option 1: Send full video
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _sendFullVideo
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sendFullVideo
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _sendFullVideo = true),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: _sendFullVideo,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _sendFullVideo = val);
                                }
                              },
                              activeColor: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Envoyer la vidéo complète',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _sendFullVideo
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Envoyer toute la vidéo sans modifications',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Option 2: Trim video
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_sendFullVideo
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_sendFullVideo
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _sendFullVideo = false),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: false,
                              groupValue: _sendFullVideo,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _sendFullVideo = val);
                                }
                              },
                              activeColor: const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Couper la vidéo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: !_sendFullVideo
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sélectionner une partie de la vidéo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Trim slider (visible only if not sending full video)
                if (!_sendFullVideo) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sélectionner la durée',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 16),
                        // Start trim slider
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Début',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${_startTrim.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _startTrim,
                              min: 0,
                              max: _endTrim - 5,
                              onChanged: (val) {
                                setState(() => _startTrim = val);
                              },
                              activeColor: const Color(0xFF4CAF50),
                              inactiveColor: Colors.grey[300],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // End trim slider
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Fin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${_endTrim.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _endTrim,
                              min: _startTrim + 5,
                              max: 100,
                              onChanged: (val) {
                                setState(() => _endTrim = val);
                              },
                              activeColor: const Color(0xFF4CAF50),
                              inactiveColor: Colors.grey[300],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onCancel,
                          icon: const Icon(Icons.close),
                          label: const Text('Annuler'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Send button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTrimming
                              ? null
                              : () {
                                  setState(() => _isTrimming = true);
                                  // Simuler le traitement du trimming
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    widget.onConfirm(
                                      widget.videoPath,
                                      _sendFullVideo,
                                    );
                                    Navigator.pop(context);
                                  });
                                },
                          icon: _isTrimming
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_isTrimming ? 'Traitement...' : 'Envoyer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
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
}
