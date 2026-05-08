import http from './http'
import type { UserInfo, Position } from './users'

export interface ApprovalStatus {
  approvalStatus: 'pending' | 'approved' | 'rejected'
  approvalRejectReason: string | null
  approvalReviewedAt: string | null
}

export interface ApproveDto {
  roleLevel?: number
  position?: Position | null
  groupIds?: string[]
  divisionIds?: string[]
}

export const approvalsApi = {
  getMyStatus: (): Promise<ApprovalStatus> => http.get('/approvals/my-status'),
  getPending: (): Promise<UserInfo[]> => http.get('/approvals/pending'),
  approve: (userId: string, dto: ApproveDto): Promise<UserInfo> =>
    http.patch(`/approvals/${userId}/approve`, dto),
  reject: (userId: string, reason: string): Promise<UserInfo> =>
    http.patch(`/approvals/${userId}/reject`, { reason }),
}
