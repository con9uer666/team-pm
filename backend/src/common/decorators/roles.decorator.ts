import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';
export const Roles = (minRole: number) => SetMetadata(ROLES_KEY, minRole);
