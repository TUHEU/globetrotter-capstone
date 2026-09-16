import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class TripSharingQRScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final String duration;
  final String estimatedCost;
  final List<String> places;

  const TripSharingQRScreen({
    Key? key,
    required this.tripId,
    required this.tripTitle,
    required this.duration,
    required this.estimatedCost,
    required this.places,
  }) : super(key: key);

  @override
  State<TripSharingQRScreen> createState() => _TripSharingQRScreenState();
}

class _TripSharingQRScreenState extends State<TripSharingQRScreen> {
  late String _shareLink;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _shareLink = 'https://fahglobe.duckdns.org/app/#/trip/${widget.tripId}';
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _shareLink));
    setState(() => _copied = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied! ✓'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Future<void> _shareViaWhatsApp() async {
    final message =
        'Join me for a trip: ${widget.tripTitle}\nDuration: ${widget.duration}\nEstimated Cost: ${widget.estimatedCost}\n\nLink: $_shareLink';

    try {
      await launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  Future<void> _shareViaEmail() async {
    final subject = 'Join my trip: ${widget.tripTitle}';
    final body =
        'I\'m planning a trip to ${widget.tripTitle}!\n\nDuration: ${widget.duration}\nEstimated Cost: ${widget.estimatedCost}\n\nPlaces:\n${widget.places.join('\n')}\n\nView the full trip here: $_shareLink';

    try {
      await launchUrl(
        Uri(
          scheme: 'mailto',
          path: '',
          queryParameters: {'subject': subject, 'body': body},
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open email')));
      }
    }
  }

  Future<void> _shareViaSMS() async {
    final message =
        'Join me for a trip: ${widget.tripTitle}. Duration: ${widget.duration}. Link: $_shareLink';

    try {
      await launchUrl(
        Uri(scheme: 'sms', path: '', queryParameters: {'body': message}),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open SMS')));
      }
    }
  }

  Future<void> _shareSystemShare() async {
    await Share.share(
      'Join me on this trip: ${widget.tripTitle}\nDuration: ${widget.duration}\nEstimated Cost: ${widget.estimatedCost}\n\nLink: $_shareLink',
      subject: 'Join my trip: ${widget.tripTitle}',
    );
  }

  Future<void> _downloadQR() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code download feature coming soon!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Trip'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.flight,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.tripTitle,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Duration: ${widget.duration}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Estimated Cost: ${widget.estimatedCost}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Scan to Join',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 250,
                      width: 250,
                      color: Colors.white,
                      child: QrImageView(data: _shareLink),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _downloadQR,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Download QR Code'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share Link',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shareLink,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _copyToClipboard,
                      child: Text(_copied ? '✓' : 'Copy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Share Via',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              _ShareButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                onTap: _shareViaWhatsApp,
              ),
              const SizedBox(height: 12),
              _ShareButton(
                icon: Icons.email,
                label: 'Email',
                onTap: _shareViaEmail,
              ),
              const SizedBox(height: 12),
              _ShareButton(icon: Icons.sms, label: 'SMS', onTap: _shareViaSMS),
              const SizedBox(height: 12),
              _ShareButton(
                icon: Icons.share,
                label: 'More Options',
                onTap: _shareSystemShare,
              ),
              const SizedBox(height: 24),
              if (widget.places.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Places to Visit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.places.map(
                      (place) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                place,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.green),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
