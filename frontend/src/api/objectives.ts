import http from './http'
import type { Task } from './tasks'

export type ObjectiveScope = 'division' | 'group'
export type ObjectiveStatus = 'active' | 'completed' | 'cancelled'

export interface Objective {
  id: string
  title: string
  description: string | null
  scope: ObjectiveScope
  divisionId: string | null
  groupId: string | null
  dueDate: string
  status: ObjectiveStatus
  manuallyCompleted: boolean
  createdById: string
  createdAt: string
  updatedAt: string
  totalTasks?: number
  completedTasks?: number
  progress?: number
}

export interface CreateObjectiveDto {
  title: string
  description?: string
  scope: ObjectiveScope
  divisionId?: string
  groupId?: string
  dueDate: string
}

export interface UpdateObjectiveDto {
  title?: string
  description?: string
  dueDate?: string
  status?: ObjectiveStatus
}

export const objectivesApi = {
  create: (dto: CreateObjectiveDto): Promise<Objective> => http.post('/objectives', dto),
  list: (query: { scope?: ObjectiveScope; divisionId?: string; groupId?: string } = {}): Promise<Objective[]> =>
    http.get('/objectives', { params: query }),
  get: (id: string): Promise<Objective> => http.get(`/objectives/${id}`),
  getTasks: (id: string): Promise<Task[]> => http.get(`/objectives/${id}/tasks`),
  update: (id: string, dto: UpdateObjectiveDto): Promise<Objective> =>
    http.patch(`/objectives/${id}`, dto),
  complete: (id: string): Promise<Objective> => http.patch(`/objectives/${id}/complete`),
  remove: (id: string): Promise<void> => http.delete(`/objectives/${id}`),
}
