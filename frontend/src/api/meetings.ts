import http from './http'

export interface MeetingInfo {
  id: string
  title: string
  description: string | null
  organizerId: string
  scope: 'group' | 'division' | 'team'
  groupId: string | null
  divisionId: string | null
  location: string | null
  startTime: string
  endTime: string
  status: 'scheduled' | 'in_progress' | 'ended' | 'cancelled'
  createdAt: string
}

export interface ParticipantInfo {
  id: string
  meetingId: string
  userId: string
  attendanceStatus: 'pending' | 'present' | 'late' | 'absent'
  checkInTime: string | null
}

export interface MinutesInfo {
  id: string
  meetingId: string
  content: string
  recorderId: string
  createdAt: string
  updatedAt: string | null
}

export const meetingsApi = {
  create: (dto: {
    title: string
    description?: string
    scope: string
    groupId?: string
    divisionId?: string
    location?: string
    startTime: string
    endTime: string
  }): Promise<MeetingInfo> => http.post('/meetings', dto),

  getAll: (): Promise<MeetingInfo[]> => http.get('/meetings'),
  getMy: (): Promise<MeetingInfo[]> => http.get('/meetings/my'),
  getById: (id: string): Promise<MeetingInfo> => http.get(`/meetings/${id}`),

  start: (id: string): Promise<MeetingInfo> => http.patch(`/meetings/${id}/start`),
  end: (id: string): Promise<MeetingInfo> => http.patch(`/meetings/${id}/end`),
  cancel: (id: string): Promise<MeetingInfo> => http.patch(`/meetings/${id}/cancel`),

  checkIn: (id: string): Promise<ParticipantInfo> => http.post(`/meetings/${id}/check-in`),
  getParticipants: (id: string): Promise<ParticipantInfo[]> => http.get(`/meetings/${id}/participants`),

  saveMinutes: (id: string, content: string): Promise<MinutesInfo> =>
    http.post(`/meetings/${id}/minutes`, { content }),
  getMinutes: (id: string): Promise<MinutesInfo | null> => http.get(`/meetings/${id}/minutes`),
}
