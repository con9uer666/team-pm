import http from './http'

export type Position = 'project_manager' | 'team_captain' | 'vice_captain'

export interface UserInfo {
  id: string
  username: string
  realName: string
  roleLevel: number
  position?: Position | null
  groupIds: string[] | null
  divisionIds: string[] | null
  status: string
  phone: string | null
  isSuperAdmin: boolean
  approvalStatus: 'pending' | 'approved' | 'rejected'
  approvalRejectReason?: string | null
  wechatWorkId?: string | null
  email?: string | null
}

export interface GroupInfo {
  id: string
  name: string
  leaderIds: string[] | null
  divisionId: string | null
}

export interface DivisionInfo {
  id: string
  name: string
  leaderIds: string[] | null
  description: string | null
}

export interface OrgStructure {
  users: UserInfo[]
  groups: GroupInfo[]
  divisions: DivisionInfo[]
}

export const usersApi = {
  getMe: (): Promise<UserInfo> => http.get('/users/me'),
  getAll: (): Promise<UserInfo[]> => http.get('/users'),
  updateRole: (id: string, roleLevel: number, position?: Position | null): Promise<UserInfo> =>
    http.patch(`/users/${id}/role`, { roleLevel, position }),
  updatePosition: (id: string, position: Position | null): Promise<UserInfo> =>
    http.patch(`/users/${id}/position`, { position }),
  resetPassword: (id: string, password: string): Promise<{ message: string }> =>
    http.patch(`/users/${id}/password`, { password }),
  assignGroups: (id: string, groupIds: string[]): Promise<UserInfo> =>
    http.patch(`/users/${id}/group`, { groupIds }),
  assignDivisions: (id: string, divisionIds: string[]): Promise<UserInfo> =>
    http.patch(`/users/${id}/division`, { divisionIds }),
  createUser: (dto: {
    username: string
    password: string
    realName: string
    roleLevel?: number
    position?: Position | null
    groupIds?: string[]
    divisionIds?: string[]
    email?: string
  }): Promise<UserInfo> => http.post('/users', dto),
  removeUser: (id: string): Promise<void> =>
    http.delete(`/users/${id}`),
}

export const orgApi = {
  getGroups: (): Promise<GroupInfo[]> => http.get('/organization/groups'),
  getPublicGroups: (): Promise<Pick<GroupInfo, 'id' | 'name'>[]> => http.get('/public/groups'),
  createGroup: (dto: { name: string; leaderIds?: string[]; divisionId?: string }): Promise<GroupInfo> =>
    http.post('/organization/groups', dto),
  setGroupLeaders: (id: string, leaderIds: string[]): Promise<GroupInfo> =>
    http.patch(`/organization/groups/${id}/leaders`, { leaderIds }),
  getDivisions: (): Promise<DivisionInfo[]> => http.get('/organization/divisions'),
  createDivision: (dto: { name: string; leaderIds?: string[]; description?: string }): Promise<DivisionInfo> =>
    http.post('/organization/divisions', dto),
  setDivisionLeaders: (id: string, leaderIds: string[]): Promise<DivisionInfo> =>
    http.patch(`/organization/divisions/${id}/leaders`, { leaderIds }),
  getStructure: (): Promise<OrgStructure> => http.get('/organization/structure'),
}
