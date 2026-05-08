import http from './http'

export enum AttendanceSessionStatus {
  ACTIVE = 'active',
  CLOSED = 'closed',
  AUTO_CLOSED = 'auto_closed',
}

export interface AttendanceFence {
  id: string
  name: string
  centerLat: number
  centerLng: number
  radius: number
  enabled: boolean
  createdAt: string
  updatedAt: string
}

export interface AttendanceSession {
  id: string
  userId: string
  clockInAt: string
  clockInLat: number
  clockInLng: number
  clockInAddress: string | null
  clockInFenceId: string | null
  clockOutAt: string | null
  clockOutLat: number | null
  clockOutLng: number | null
  clockOutAddress: string | null
  status: AttendanceSessionStatus
  durationMinutes: number
  createdAt: string
  updatedAt: string
}

export interface AttendanceStatRow {
  userId: string
  realName: string
  username: string
  totalMinutes: number
  sessionCount: number
}

export interface ClockDto {
  lat: number
  lng: number
  accuracy?: number
  address?: string
}

export interface CreateFenceDto {
  name: string
  centerLat: number
  centerLng: number
  radius: number
  enabled?: boolean
}

export interface UpdateFenceDto {
  name?: string
  centerLat?: number
  centerLng?: number
  radius?: number
  enabled?: boolean
}

export const attendanceApi = {
  clockIn: (dto: ClockDto): Promise<AttendanceSession> =>
    http.post('/attendance/clock-in', dto),

  clockOut: (dto: ClockDto): Promise<AttendanceSession> =>
    http.post('/attendance/clock-out', dto),

  getActive: (): Promise<AttendanceSession | null> =>
    http.get('/attendance/active'),

  getMy: (params?: { from?: string; to?: string; limit?: number }): Promise<AttendanceSession[]> =>
    http.get('/attendance/my', { params }),

  getStats: (params?: {
    scope?: 'week' | 'month' | 'all'
    groupId?: string
    divisionId?: string
  }): Promise<AttendanceStatRow[]> => http.get('/attendance/stats', { params }),

  getUserSessions: (params: {
    userId: string
    from?: string
    to?: string
    limit?: number
  }): Promise<AttendanceSession[]> => http.get('/attendance/sessions', { params }),

  listFences: (): Promise<AttendanceFence[]> => http.get('/attendance/fences'),

  createFence: (dto: CreateFenceDto): Promise<AttendanceFence> =>
    http.post('/attendance/fences', dto),

  updateFence: (id: string, dto: UpdateFenceDto): Promise<AttendanceFence> =>
    http.patch(`/attendance/fences/${id}`, dto),

  removeFence: (id: string): Promise<void> =>
    http.delete(`/attendance/fences/${id}`),
}
