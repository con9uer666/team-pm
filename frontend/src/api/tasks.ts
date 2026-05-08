import http from './http'

export interface Task {
  id: string
  title: string
  description: string | null
  content: string | null
  divisionId: string | null
  groupId: string | null
  objectiveId: string | null
  completionRequirements: string | null
  creatorId: string
  assigneeId: string
  status: string
  priority: number
  weekYear: number
  weekNumber: number
  dueDate: string
  completedAt: string | null
  overdueMinutes: number
  rejectionReason: string | null
  rejectedBy: string | null
  reviewedBy: string | null
  reviewedAt: string | null
  completionNote: string | null
  completionAttachments: string[] | null
  createdAt: string
}

export interface TaskReviewInfo {
  id: string
  taskId: string
  reviewerId: string
  reviewType: 'division' | 'group'
  status: 'approved' | 'rejected'
  rejectionReason: string | null
  reviewedAt: string
}

export interface TaskWithMeta extends Task {
  reviews: TaskReviewInfo[]
  reviewableTypes: ('division' | 'group')[]
  canVerifyCompletion: boolean
}

export interface CreateTaskDto {
  title: string
  description?: string
  content?: string
  divisionId?: string
  groupId?: string
  objectiveId?: string
  completionRequirements?: string
  dueDate: string
  priority?: number
  dependencyIds?: string[]
  assigneeId?: string
}

export const tasksApi = {
  getMyScope: (params?: { status?: string; scope?: 'own' | 'team' | 'all' }): Promise<TaskWithMeta[]> =>
    http.get('/tasks/my-scope', { params }),

  create: (dto: CreateTaskDto): Promise<Task> =>
    http.post('/tasks', dto),

  getAll: (params?: { weekYear?: number; weekNumber?: number; status?: string; assigneeId?: string }): Promise<Task[]> =>
    http.get('/tasks', { params }),

  getById: (id: string): Promise<Task> =>
    http.get(`/tasks/${id}`),

  getDependencies: (id: string): Promise<Task[]> =>
    http.get(`/tasks/${id}/dependencies`),

  getReviews: (id: string): Promise<TaskReviewInfo[]> =>
    http.get(`/tasks/${id}/reviews`),

  getReviewableTypes: (id: string): Promise<('division' | 'group')[]> =>
    http.get(`/tasks/${id}/reviewable-types`),

  review: (id: string, dto: { action: 'approve' | 'reject'; reviewType: 'division' | 'group'; reason?: string }): Promise<Task> =>
    http.patch(`/tasks/${id}/review`, dto),

  complete: (id: string, dto: { attachments: string[]; note?: string }): Promise<Task> =>
    http.patch(`/tasks/${id}/complete`, dto),

  verifyCompletion: (id: string, dto: { action: 'approve' | 'reject'; reason?: string }): Promise<Task> =>
    http.patch(`/tasks/${id}/verify-completion`, dto),

  resubmit: (id: string, dto: { title?: string; description?: string; dueDate?: string }): Promise<Task> =>
    http.patch(`/tasks/${id}/resubmit`, dto),

  updateObjective: (id: string, objectiveId: string | null): Promise<Task> =>
    http.patch(`/tasks/${id}/objective`, { objectiveId }),

  deleteTask: (id: string): Promise<void> =>
    http.delete(`/tasks/${id}`),
}
