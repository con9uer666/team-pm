import http from './http'

export interface LoginDto {
  username: string
  password: string
  rememberMe?: boolean
}

export interface RegisterDto {
  username: string
  password: string
  realName: string
  email: string
  groupIds: string[]
}

export interface AuthResponse {
  user: {
    id: string
    username: string
    realName: string
    roleLevel: number
    isSuperAdmin: boolean
    approvalStatus: 'pending' | 'approved' | 'rejected'
    wechatWorkId?: string | null
    email?: string | null
  }
  accessToken?: string
}

export const authApi = {
  login: (dto: LoginDto): Promise<AuthResponse> => http.post('/auth/login', dto),
  register: (dto: RegisterDto): Promise<AuthResponse> => http.post('/auth/register', dto),
  logout: (): Promise<void> => http.post('/auth/logout'),
}

export const usersApi = {
  getMe: (): Promise<AuthResponse['user']> => http.get('/users/me'),
  getAll: () => http.get('/users'),
}
