import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/dio_client.dart';
import '../../core/uploads/uploads_api.dart';

/// Per-item upload state used by [FileUploader].
class _Item {
  _Item(this.file, {this.uploading = false, this.url, this.error});
  final XFile file;
  bool uploading;
  String? url;
  String? error;
}

/// Multi-image picker + uploader. Mirrors the Vue `FileUploader.vue` behavior:
/// pick from gallery, show thumbnails with per-item upload state, surface
/// errors, expose the final URL list to the parent via [onChanged].
///
/// Uploads happen automatically as soon as files are picked — caller waits for
/// [allFinished] before submitting the surrounding form.
class FileUploader extends ConsumerStatefulWidget {
  const FileUploader({
    super.key,
    required this.onChanged,
    this.maxCount = 9,
    this.disabled = false,
  });

  final ValueChanged<List<String>> onChanged;
  final int maxCount;
  final bool disabled;

  @override
  ConsumerState<FileUploader> createState() => _FileUploaderState();
}

class _FileUploaderState extends ConsumerState<FileUploader> {
  final _picker = ImagePicker();
  final List<_Item> _items = [];

  bool get allFinished => _items.every((i) => !i.uploading);

  List<String> get _urls => [
        for (final i in _items)
          if (i.url != null) i.url!
      ];

  Future<void> _pick() async {
    if (widget.disabled) return;
    final remaining = widget.maxCount - _items.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final toAdd = picked.take(remaining).map(_Item.new).toList();
    setState(() => _items.addAll(toAdd));
    for (final item in toAdd) {
      unawaited(_upload(item));
    }
  }

  Future<void> _upload(_Item item) async {
    setState(() => item.uploading = true);
    try {
      final api = ref.read(uploadsApiProvider);
      final url = await api.uploadOne(item.file.path);
      if (!mounted) return;
      setState(() {
        item.url = url;
        item.uploading = false;
        item.error = null;
      });
      widget.onChanged(_urls);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        item.uploading = false;
        item.error = dioErrorMessage(e, '上传失败');
      });
    }
  }

  void _remove(int idx) {
    setState(() => _items.removeAt(idx));
    widget.onChanged(_urls);
  }

  Future<void> _retry(int idx) async {
    final item = _items[idx];
    if (item.uploading) return;
    item.error = null;
    item.url = null;
    await _upload(item);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _items.length; i++)
          _Thumb(
            item: _items[i],
            onRemove: disabled ? null : () => _remove(i),
            onRetry: disabled ? null : () => _retry(i),
          ),
        if (_items.length < widget.maxCount)
          _AddTile(onTap: disabled ? null : _pick),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.onRemove, required this.onRetry});
  final _Item item;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(item.file.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF1F5F9),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image,
                      color: Color(0xFF94A3B8), size: 28),
                ),
              ),
            ),
          ),
          if (item.uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                ),
              ),
            ),
          if (item.error != null)
            Positioned.fill(
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 24),
                      Text('重试', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.add, color: Color(0xFF64748B), size: 28),
      ),
    );
  }
}
