import 'package:flutter/material.dart';

class TransactionImageDialog extends StatefulWidget {
  final String? imageUrl;
  final Widget headerWidget;

  const TransactionImageDialog({
    super.key,
    required this.imageUrl,
    required this.headerWidget,
  });

  @override
  State<TransactionImageDialog> createState() => _TransactionImageDialogState();
}

class _TransactionImageDialogState extends State<TransactionImageDialog> {
  final TransformationController _transformationController =
  TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header Widget passed from outside ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: widget.headerWidget,
            ),

            const Divider(height: 1),

            // ── Zoomable Image Area ──
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              color: Colors.black,
              child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                  ? _ZoomableNetworkImage(
                imageUrl: widget.imageUrl!,
                controller: _transformationController,
              )
                  : const _NoImagePlaceholder(),
            ),

            const Divider(height: 1),

            // ── Footer: Reset Zoom + OK ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reset zoom hint
                  TextButton.icon(
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.zoom_out_map, size: 18),
                    label: const Text('Reset Zoom'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  // OK dismiss
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 10),
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Zoomable + Pannable Image ──────────────────────────────────────────────
class _ZoomableNetworkImage extends StatelessWidget {
  final String imageUrl;
  final TransformationController controller;

  const _ZoomableNetworkImage({
    required this.imageUrl,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: controller,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 5.0,
      boundaryMargin: const EdgeInsets.all(20),
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: total != null ? loaded / total : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Loading image...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
                SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── No Image Placeholder ───────────────────────────────────────────────────
class _NoImagePlaceholder extends StatelessWidget {
  const _NoImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                color: Colors.white38, size: 48),
            SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}