import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      );
}

class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetryWidget({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyWidget({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  const StatusChip({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          itemCount: count,
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, __) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  Text(value, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
