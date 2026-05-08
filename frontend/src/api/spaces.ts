import http from './http'
import type { UserInfo } from './users'
import type { Objective } from './objectives'

export interface SpaceInfo {
  id: string
  name: string
  leaderIds: string[]
  memberCount: number
}

export interface MySpaces {
  groups: SpaceInfo[]
  divisions: SpaceInfo[]
}

export interface SpaceDetail {
  info: {
    id: string
    name: string
    leaderIds: string[]
    divisionId?: string | null
    description?: string | null
  }
  members: UserInfo[]
  objectives: Objective[]
  tasks: any[]
}

export const spacesApi = {
  getMy: (): Promise<MySpaces> => http.get('/spaces/my'),
  getGroup: (id: string): Promise<SpaceDetail> => http.get(`/spaces/group/${id}`),
  getDivision: (id: string): Promise<SpaceDetail> => http.get(`/spaces/division/${id}`),
}
