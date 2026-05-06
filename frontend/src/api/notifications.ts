import http from './http'

export interface NotificationInfo {
  id: string
  userId: string
  type: string
  title: string
  content: string | null
  relatedId: string | null
  isRead: boolean
  createdAt: string
}

export const notificationsApi = {
  getAll: (): Promise<NotificationInfo[]> => http.get('/notifications'),
  getUnreadCount: (): Promise<number> => http.get('/notifications/unread-count'),
  markRead: (id: string): Promise<void> => http.patch(`/notifications/${id}/read`),
  markAllRead: (): Promise<void> => http.patch('/notifications/read-all'),
}
