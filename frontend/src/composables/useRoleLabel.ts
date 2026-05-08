export const ROLE_LEVELS = [
  { value: 1, label: '梯队员' },
  { value: 2, label: '正式队员' },
  { value: 3, label: '组长' },
  { value: 4, label: '项管' },
  { value: 5, label: '队长' },
  { value: 6, label: '指导老师' },
]

export function roleLevelLabel(level: number): string {
  return ROLE_LEVELS.find(r => r.value === level)?.label || `Lv.${level}`
}
