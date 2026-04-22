import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models/restaurant.dart';
import '../app_config.dart';

class QrCodesScreen extends StatelessWidget {
  final Restaurant restaurant;
  const QrCodesScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final totalTables = restaurant.totalTables;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        const Text(
          'QR Codes',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalTables tables · Tap a QR to share',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 22),

        // Grid of QR cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.65,
          ),
          itemCount: totalTables,
          itemBuilder: (context, index) {
            final tableNum = index + 1;
            final url = AppConfig.menuUrl(restaurant.slug, table: tableNum);
            return _QrCard(
              tableNumber: tableNum,
              url: url,
              restaurantName: restaurant.name,
            );
          },
        ),
      ],
    );
  }
}

class _QrCard extends StatefulWidget {
  final int tableNumber;
  final String url;
  final String restaurantName;

  const _QrCard({
    required this.tableNumber,
    required this.url,
    required this.restaurantName,
  });

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _shareQr() async {
    try {
      // Capture QR as image
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final pngBytes = byteData.buffer.asUint8List();
          await Share.shareXFiles(
            [XFile.fromData(pngBytes, name: 'table_${widget.tableNumber}_qr.png', mimeType: 'image/png')],
            text: '${widget.restaurantName} — Table ${widget.tableNumber}\n${widget.url}',
          );
          return;
        }
      }
    } catch (_) {
      // Fallback to text-only share
    }
    // Fallback: share just the link
    await Share.share(
      '${widget.restaurantName} — Table ${widget.tableNumber}\nScan or open: ${widget.url}',
    );
  }

  Future<void> _printTopper() async {
    final slug = widget.url.split('r=').last.split('&').first;
    final printUrl = Uri.parse('${AppConfig.webBaseUrl}/table-topper.html?r=$slug&table=${widget.tableNumber}&print=true');
    if (await canLaunchUrl(printUrl)) {
      await launchUrl(printUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Text(
            'Table ${widget.tableNumber}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
          ),
          const SizedBox(height: 10),

          // QR Code wrapped in RepaintBoundary for capture
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: widget.url,
                version: QrVersions.auto,
                size: 100,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF050505),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF050505),
                ),
              ),

            ),
          ),

          const SizedBox(height: 8),
          Text(
            '?r=${widget.url.split('r=').last}',
            style: const TextStyle(fontSize: 9, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const Spacer(),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _shareQr,
                    icon: const Icon(Icons.share, size: 14),
                    label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.lime,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _printTopper,
                    icon: const Icon(Icons.print_rounded, size: 14),
                    label: const Text('Print Topper', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
