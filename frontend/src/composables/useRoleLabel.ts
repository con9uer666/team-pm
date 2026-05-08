export const ROLE_LEVELS = [
  { value: 1, label: '梯队员' },
  { value: 2, label: '正式队员' },
  { value: 3, label: '组长' },
  { value: 4, label: '副队长' },
  { value: 5, label: '项管/队长' },
  { value: 6, label: '指导老师' },
]

export type Position = 'project_manager' | 'team_captain' | 'vice_captain'

export function roleLabel(roleLevel: number, position?: string | null): string {
  if (roleLevel === 5) {
    if (position === 'team_captain') return '队长'
    if (position === 'project_manager') return '项管'
    return '项管/队长'
  }
  if (roleLevel === 4) return '副队长'
  if (roleLevel === 3) return '组长'
  if (roleLevel === 2) return '正式队员'
  if (roleLevel === 1) return '梯队员'
  if (roleLevel === 6) return '指导老师'
  return `Lv.${roleLevel}`
}

export function roleLevelLabel(level: number, position?: string | null): string {
  return roleLabel(level, position)
}

export function positionLabel(position?: string | null): string {
  if (position === 'project_manager') return '项管'
  if (position === 'team_captain') return '队长'
  if (position === 'vice_captain') return '副队长'
  return ''
}
