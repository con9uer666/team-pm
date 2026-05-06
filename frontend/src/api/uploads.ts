import http from './http'

export const uploadsApi = {
  upload: (file: File): Promise<{ url: string }> => {
    const fd = new FormData()
    fd.append('file', file)
    return http.post('/uploads', fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 120000,
    })
  },
}
