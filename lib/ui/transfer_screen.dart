// ui/transfer_screen.dart
// Shows active and completed transfers with progress bars.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/transfer/models/transfer_entry.dart';
import '../features/transfer/models/transfer_status.dart';
import '../state/transfer_state.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Transfers', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (transferState.activeTransfers.isNotEmpty) ...[
            _sectionHeader('Active'),
            showActiveTransfers(context, ref, transferState.activeTransfers),
            const SizedBox(height: 24),
          ],
          _sectionHeader('History'),
          showTransferHistory(context, transferState.completedTransfers),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget showActiveTransfers(
    BuildContext context,
    WidgetRef ref,
    List<TransferEntry> transfers,
  ) {
    return Column(
      children: transfers.map((t) => _ActiveTransferCard(entry: t, ref: ref)).toList(),
    );
  }

  Widget showTransferHistory(BuildContext context, List<TransferEntry> transfers) {
    if (transfers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No completed transfers', style: TextStyle(color: Colors.white38)),
      );
    }
    return Column(
      children: transfers.map((t) => _HistoryCard(entry: t)).toList(),
    );
  }

  void onPauseTransfer(WidgetRef ref, String transferId) {
    // TODO: Call FileTransferManager.pauseTransfer(transferId).
  }

  void onCancelTransfer(WidgetRef ref, String transferId) {
    // TODO: Call FileTransferManager.cancelTransfer(transferId).
    ref.read(transferStateProvider.notifier).removeTransfer(transferId);
  }
}

class _ActiveTransferCard extends StatelessWidget {
  final TransferEntry entry;
  final WidgetRef ref;

  const _ActiveTransferCard({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.fileName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(entry.fileSizeLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: entry.progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF238636)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(entry.progress * 100).toInt()}%  →  ${entry.targetDevice.name}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.pause, color: Colors.white70, size: 20),
                      onPressed: () {/* pause */},
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () {/* cancel */},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final TransferEntry entry;

  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isOk = entry.status == TransferStatus.completed;
    return ListTile(
      leading: Icon(
        isOk ? Icons.check_circle : Icons.error_outline,
        color: isOk ? const Color(0xFF238636) : Colors.red,
      ),
      title: Text(entry.fileName,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.fileSizeLabel}  •  ${entry.targetDevice.name}',
        style: const TextStyle(color: Colors.white38),
      ),
    );
  }
}
