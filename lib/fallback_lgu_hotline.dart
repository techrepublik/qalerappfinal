import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/lgucontact.dart';
import 'services/analytics.dart';

class FallbackLGUSection extends StatelessWidget {
  final List<LGUContact> lguList;
  final String lguCode;
  final double? currentLat;
  final double? currentLon;

  const FallbackLGUSection({
    super.key,
    required this.lguList,
    required this.lguCode,
    this.currentLat,
    this.currentLon,
  });

  // ─── Palette ─────────────────────────────────────────────────────────────────
  // Muted, accessible pastel tones — readable on white, soft on the eye.
  // Each entry is [headerBg, headerText/icon accent, dialButton].

  static const List<_LGUTheme> _palette = [
    _LGUTheme(
      headerBg: Color(0xFFDBEAFE),   // sky-100
      headerText: Color(0xFF1D4ED8), // blue-700
      dial: Color(0xFF2563EB),       // blue-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFD1FAE5),   // emerald-100
      headerText: Color(0xFF065F46), // emerald-800
      dial: Color(0xFF059669),       // emerald-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFEDE9FE),   // violet-100
      headerText: Color(0xFF5B21B6), // violet-800
      dial: Color(0xFF7C3AED),       // violet-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFFEF3C7),   // amber-100
      headerText: Color(0xFF92400E), // amber-800
      dial: Color(0xFFD97706),       // amber-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFFFE4E6),   // rose-100
      headerText: Color(0xFF9F1239), // rose-800
      dial: Color(0xFFE11D48),       // rose-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFCFFAFE),   // cyan-100
      headerText: Color(0xFF155E75), // cyan-800
      dial: Color(0xFF0891B2),       // cyan-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFFCE7F3),   // pink-100
      headerText: Color(0xFF9D174D), // pink-800
      dial: Color(0xFFDB2777),       // pink-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFCCFBF1),   // teal-100
      headerText: Color(0xFF134E4A), // teal-900
      dial: Color(0xFF0D9488),       // teal-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFFFEDD5),   // orange-100
      headerText: Color(0xFF9A3412), // orange-800
      dial: Color(0xFFEA580C),       // orange-600
    ),
    _LGUTheme(
      headerBg: Color(0xFFE0E7FF),   // indigo-100
      headerText: Color(0xFF3730A3), // indigo-800
      dial: Color(0xFF4F46E5),       // indigo-600
    ),
  ];

  _LGUTheme _themeForName(String name) {
    final seed = name.codeUnits.fold(0, (prev, c) => prev + c);
    return _palette[seed % _palette.length];
  }

  // ─── URL Launcher ────────────────────────────────────────────────────────────

  void _openUrl(BuildContext context, String label, String url) async {
    final Uri uri = Uri.parse(url);
    final bool launched =
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      AnalyticsService.trackEvent(
        eventName: 'Call-$label',
        lguCode: lguCode,
        screen: 'OutCoverage Screen',
      );
    } else {
      debugPrint('Could not launch $url');
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 20),
          _buildSectionLabel(),
          const SizedBox(height: 4),
          ...lguList.map((lgu) => _buildFallbackLGUCard(context, lgu)),
        ],
      ),
    );
  }

  // ─── Header Banner ───────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5FA6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your area is not in our database yet, Q-ALERT is expanding fast!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Contact us at '),
                      TextSpan(
                        text: 'support@qalertapp.com',
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final Uri emailUri = Uri(
                              scheme: 'mailto',
                              path: 'support@qalertapp.com',
                            );
                            if (await canLaunchUrl(emailUri)) {
                              await launchUrl(emailUri);
                            }
                          },
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                      const TextSpan(text: ' to add hotlines for your area.'),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Label ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel() {
    return const Padding(
      padding: EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        'Available Hotlines',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ─── LGU Card ────────────────────────────────────────────────────────────────

  Widget _buildFallbackLGUCard(BuildContext context, LGUContact lgu) {
    if (lgu.bdrrmo.isEmpty) return const SizedBox.shrink();

    final theme = _themeForName(lgu.barName);

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.headerBg,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Pastel barName header ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.headerText.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_city_rounded,
                    color: theme.headerText,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lgu.barName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.headerText,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.headerText.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Nearby',
                    style: TextStyle(
                      color: theme.headerText,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Quick Dial — DRRMO only ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: _buildDialRow(
              context: context,
              icon: Icons.shield_rounded,
              label: 'Emergency Hotline',
              number: lgu.bdrrmo,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dial Row ────────────────────────────────────────────────────────────────

  Widget _buildDialRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String number,
    required _LGUTheme theme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.dial.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.dial, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        // ── Dial button ───────────────────────────────────────────────────
        GestureDetector(
          onTap: () => _openUrl(context, label, 'tel:$number'),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.dial,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.dial.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_rounded, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Dial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Theme Data Class ─────────────────────────────────────────────────────────

class _LGUTheme {
  final Color headerBg;    // pastel background for the name bar
  final Color headerText;  // dark shade for text + icon inside header
  final Color dial;        // solid color for dial button + icon

  const _LGUTheme({
    required this.headerBg,
    required this.headerText,
    required this.dial,
  });
}