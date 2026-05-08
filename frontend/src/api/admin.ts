import http from './http'

export interface DashboardStats {
  users: {
    total: number
    pending: number
    approved: number
    byRole: Record<string, number>
  }
  tasks: {
    total: number
    active: number
    pendingReview: number
    overdue: number
  }
  meetings: {
    total: number
    scheduled: number
  }
  organization: {
    groups: number
    divisions: number
  }
  objectives: {
    active: number
    completed: number
  }
}

export const adminApi = {
  getDashboardStats: (): Promise<DashboardStats> => http.get('/admin/dashboard/stats'),
}
