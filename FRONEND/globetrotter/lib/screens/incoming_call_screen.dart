import 'package:flutter/material.dart';
import 'dart:async';

/// Écran d'appel entrant inspiré de WhatsApp/FaceTime avec animation
/// et boutons d'acceptation/rejet.
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerAvatar;
  final String callerId;
  final String callType; // 'voice' ou 'video'
  final Function onAccept;
  final Function onReject;

  const IncomingCallScreen({
    Key? key,
    required this.callerName,
    this.callerAvatar,
    required this.callerId,
    required this.callType,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringingAnimation;
  bool _isAutoRejectingIncoming = false;
  late Timer _autoRejectTimer;

  @override
  void initState() {
    super.initState();
    
    // Animation de pulsation pour les boutons
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation de vibration pour l'écran
    _ringingController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _ringingAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _ringingController, curve: Curves.easeInOut),
    );

    // Auto-reject après 30 secondes d'inactivité
    _autoRejectTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isAutoRejectingIncoming) {
        _rejectCall();
      }
    });

    // Play ringtone (implémentation simplifiée)
    _playRingtone();
  }

  void _playRingtone() {
    // TODO: Implémenter la lecture du son d'appel
    // Utiliser audioplayers pour jouer un fichier audio
  }

  void _acceptCall() {
    _stopAnimations();
    widget.onAccept();
    Navigator.pop(context);
  }

  void _rejectCall() {
    if (mounted) {
      setState(() => _isAutoRejectingIncoming = true);
      _stopAnimations();
      widget.onReject();
      Navigator.pop(context);
    }
  }

  void _stopAnimations() {
    _pulseController.stop();
    _ringingController.stop();
    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
    }
  }

  @override
  void dispose() {
    _stopAnimations();
    _pulseController.dispose();
    _ringingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => false, // Empêche le back button
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF0F2418)
            : const Color(0xFF1B5E20),
        body: AnimatedBuilder(
          animation: _ringingAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_ringingAnimation.value, 0),
              child: child,
            );
          },
          child: SafeArea(
            child: Stack(
              children: [
                // Gradient background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1B5E20),
                        const Color(0xFF0F2418),
                      ],
                    ),
                  ),
                ),

                // Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Caller avatar or icon
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: widget.callerAvatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.callerAvatar!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildDefaultAvatar(),
                                  ),
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Caller name
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Call type
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.callType == 'video'
                              ? 'Appel vidéo entrant...'
                              : 'Appel vocal entrant...',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Accept/Reject buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Reject button
                          GestureDetector(
                            onTap: _rejectCall,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF5252),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFFFF5252).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                          const SizedBox(width: 60),

                          // Accept button
                          GestureDetector(
                            onTap: _acceptCall,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF4CAF50),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFF4CAF50).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Ringing indicator text
                      const Text(
                        'Sonnerie...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                // Call info badge (top-left)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Appel entrant',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF0F2418),
      alignment: Alignment.center,
      child: Icon(
        widget.callType == 'video' ? Icons.videocam : Icons.call,
        color: Colors.white70,
        size: 60,
      ),
    );
  }
}

/// Helper function pour afficher l'appel entrant comme bottom sheet modal
void showIncomingCallModal(
  BuildContext context, {
  required String callerName,
  String? callerAvatar,
  required String callerId,
  required String callType,
  required Function onAccept,
  required Function onReject,
}) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => IncomingCallScreen(
      callerName: callerName,
      callerAvatar: callerAvatar,
      callerId: callerId,
      callType: callType,
      onAccept: onAccept,
      onReject: onReject,
    ),
  );
}
