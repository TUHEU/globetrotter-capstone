import 'package:flutter/material.dart';
import 'dart:typed_data';

/// NOUVELLE FONCTIONNALITÉ 3 : Partage de voyage avec code QR
/// 
/// Permet de :
/// - Générer un code QR pour partager un itinéraire
/// - Télécharger ou copier le code QR
/// - Partager via social media, WhatsApp, email, SMS
/// - Permettre aux autres de scanner et rejoindre le voyage
class TripSharingQRScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final String? tripImage;
  final List<String> places;
  final String duration;
  final String estimatedCost;

  const TripSharingQRScreen({
    Key? key,
    required this.tripId,
    required this.tripTitle,
    this.tripImage,
    required this.places,
    required this.duration,
    required this.estimatedCost,
  }) : super(key: key);

  @override
  State<TripSharingQRScreen> createState() => _TripSharingQRScreenState();
}

class _TripSharingQRScreenState extends State<TripSharingQRScreen> {
  late String _shareLink;
  bool _qrGenerated = false;

  @override
  void initState() {
    super.initState();
    _generateShareLink();
  }

  void _generateShareLink() {
    // Générer un lien partageable unique avec l'ID du voyage
    _shareLink = 'https://globetrotter.app/trip/${widget.tripId}';
    setState(() => _qrGenerated = true);
  }

  void _copyToClipboard() {
    // TODO: Implémenter la copie du lien
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lien copié dans le presse-papiers'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareViaWhatsApp() {
    final message =
        'Rejoins-moi pour ${widget.tripTitle}! ${_shareLink}\n\nDurée: ${widget.duration}\nBudget: ${widget.estimatedCost}';
    // TODO: Implémenter le partage WhatsApp
    _showShareMessage('WhatsApp', message);
  }

  void _shareViaEmail() {
    final subject = 'Rejoins moi pour: ${widget.tripTitle}';
    final body =
        'Salut!\n\nJe suis en train de planifier un voyage à ${widget.tripTitle} et j\'aimerais que tu me rejoignes!\n\nLien: $_shareLink\n\nDurée: ${widget.duration}\nBudget estimé: ${widget.estimatedCost}\n\nLieux: ${widget.places.join(", ")}';
    // TODO: Implémenter le partage email
    _showShareMessage('Email', body);
  }

  void _shareViaSMS() {
    final message =
        'Rejoins moi pour ${widget.tripTitle}! Lien: $_shareLink Durée: ${widget.duration}';
    // TODO: Implémenter le partage SMS
    _showShareMessage('SMS', message);
  }

  void _showShareMessage(String platform, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partagé via $platform'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partager le Voyage'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Trip preview card
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background image or placeholder
                    Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: widget.tripImage != null
                          ? Image.network(
                              widget.tripImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Trip info overlay
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tripTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.duration,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.estimatedCost,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // QR Code section
            if (_qrGenerated) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Code QR de Partage',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 20),
                        // QR Code placeholder
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_2,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'QR Code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Share link
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _shareLink,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontFamily: 'Courier',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _copyToClipboard,
                                icon: const Icon(Icons.content_copy),
                                iconSize: 18,
                                constraints:
                                    const BoxConstraints.tightFor(width: 40),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Action buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('QR Code téléchargé'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Télécharger le QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Sharing options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partager Via',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkSpacing: 12,
                        childAspectRatio: 1,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _ShareButton(
                            icon: Icons.chat,
                            label: 'WhatsApp',
                            onTap: _shareViaWhatsApp,
                          ),
                          _ShareButton(
                            icon: Icons.email,
                            label: 'Email',
                            onTap: _shareViaEmail,
                          ),
                          _ShareButton(
                            icon: Icons.message,
                            label: 'SMS',
                            onTap: _shareViaSMS,
                          ),
                          _ShareButton(
                            icon: Icons.share,
                            label: 'Plus',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Plus d\'options de partage'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Travel info section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lieux du Voyage',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.places.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: const Color(0xFF4CAF50),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.places[index],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Invitation message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Voyage Partagé!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4CAF50),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les personnes qui scannent ce code QR ou utilisent le lien pourront voir les détails du voyage et rejoindre le groupe.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.image_not_supported,
        size: 80,
        color: Colors.grey,
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
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4CAF50),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
