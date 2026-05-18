import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/wechat_api.dart';

/// Bottom sheet that walks the user through binding their WeChat (Work)
/// account for push notifications. Mirrors the web Profile.vue flow:
/// 1. Generate a single-use qrcode via `/wechat/bind-qrcode`.
/// 2. Poll `/users/me` every 3s — when `wechatWorkId` shows up the
///    backend callback has completed the bind.
/// 3. Hard timeout at 5 minutes to avoid an infinite poll loop.
class WechatBindSheet extends ConsumerStatefulWidget {
  const WechatBindSheet({super.key});

  static const _pollInterval = Duration(seconds: 3);
  static const _pollTimeout = Duration(minutes: 5);

  @override
  ConsumerState<WechatBindSheet> createState() => _WechatBindSheetState();
}

class _WechatBindSheetState extends ConsumerState<WechatBindSheet> {
  WechatBindQrcode? _qr;
  String? _error;
  bool _loading = true;
  Timer? _poll;
  DateTime? _pollStartedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qr = await ref.read(wechatApiProvider).getBindQrcode();
      if (!mounted) return;
      if (!qr.ok) {
        setState(() {
          _error = qr.message ?? '生成二维码失败';
          _loading = false;
        });
        return;
      }
      setState(() {
        _qr = qr;
        _loading = false;
      });
      _startPolling();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = dioErrorMessage(e, '生成二维码失败');
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _pollStartedAt = DateTime.now();
    _poll = Timer.periodic(WechatBindSheet._pollInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    final started = _pollStartedAt;
    if (started != null &&
        DateTime.now().difference(started) > WechatBindSheet._pollTimeout) {
      _poll?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('二维码已过期，请重新生成')),
      );
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).refreshUser();
      final user = ref.read(authControllerProvider).user;
      if (user?.wechatWorkId != null && user!.wechatWorkId!.isNotEmpty) {
        _poll?.cancel();
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('绑定成功')),
        );
      }
    } on Object catch (_) {
      // Transient errors during polling are non-fatal; the timer keeps trying
      // until the user cancels or the 5-minute timeout hits.
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Center(
                child: Text(
                  '绑定企业微信通知',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  '扫码关注公众号即可完成绑定',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 16),
              _buildBody(),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.dangerFg)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final url = _qr?.qrcodeUrl;
    return Column(
      children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(12),
          child: url == null
              ? const Center(child: Text('二维码不可用'))
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, evt) {
                    if (evt == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('二维码加载失败'),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('等待扫码…', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}
