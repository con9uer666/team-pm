import http from './http'

export const wechatApi = {
  getBindQrcode: (): Promise<{ success: boolean; qrcodeUrl?: string; message?: string }> =>
    http.get('/wechat/bind-qrcode'),
}
