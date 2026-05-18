import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';

class WechatBindQrcode {
  const WechatBindQrcode({this.qrcodeUrl, this.message});
  final String? qrcodeUrl;
  final String? message;

  bool get ok => qrcodeUrl != null && qrcodeUrl!.isNotEmpty;
}

class WechatApi {
  WechatApi(this._client);
  final DioClient _client;

  /// `GET /wechat/bind-qrcode` — server returns
  /// `{ success: bool, qrcodeUrl?: string, message?: string }`. On
  /// `success: false` we surface [message] so the caller can show why
  /// (typically "微信推送未配置").
  Future<WechatBindQrcode> getBindQrcode() async {
    final data = await _client.get<Map<String, dynamic>>('/wechat/bind-qrcode');
    final ok = (data['success'] ?? false) as bool;
    return WechatBindQrcode(
      qrcodeUrl: ok ? data['qrcodeUrl'] as String? : null,
      message: data['message'] as String?,
    );
  }
}

final wechatApiProvider = Provider<WechatApi>((ref) {
  return WechatApi(ref.watch(dioClientProvider));
});
