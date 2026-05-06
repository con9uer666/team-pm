import http from './http'

export interface LoginDto {
  username: string
  password: string
}

export interface RegisterDto {
  username: string
  password: string
  realName: string
}

export interface AuthResponse {
  accessToken: string
  user: {
    id: string
    username: string
    realName: string
    roleLevel: number
    isSuperAdmin: boolean
  }
}

export const authApi = {
  login: (dto: LoginDto): Promise<AuthResponse> => http.post('/auth/login', dto),
  register: (dto: RegisterDto): Promise<AuthResponse> => http.post('/auth/register', dto),
}

export const usersApi = {
  getMe: () => http.get('/users/me'),
  getAll: () => http.get('/users'),
}
