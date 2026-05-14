import { User } from '@/lib/api/auth';

export type AdminCmsRole = 'admin' | 'operator' | 'organizer' | 'artist' | 'user' | 'guest';

export interface AdminCmsRolePolicy {
  role: AdminCmsRole;
  label: string;
  description: string;
  canAccessAdminShell: boolean;
  canAccessContentCms: boolean;
  canAccessFullContentTool: boolean;
  canAccessOperations: boolean;
  canAccessNotificationOps: boolean;
  canAccessPreRegistrationOps: boolean;
  capabilities: string[];
}

const ROLE_LABELS: Record<AdminCmsRole, string> = {
  admin: '管理员',
  operator: '运营管理员',
  organizer: '入驻主办方',
  artist: '艺人',
  user: '普通用户',
  guest: '未登录用户',
};

const normalizeRole = (role?: string | null): AdminCmsRole => {
  if (role === 'admin' || role === 'operator' || role === 'organizer' || role === 'artist' || role === 'user') {
    return role;
  }
  return role ? 'user' : 'guest';
};

export const getAdminCmsRolePolicy = (user?: Pick<User, 'role'> | null): AdminCmsRolePolicy => {
  const role = normalizeRole(user?.role);
  const isAdmin = role === 'admin';
  const isOperator = role === 'operator';
  const isOrganizer = role === 'organizer';
  const isArtist = role === 'artist';
  const isSignedIn = role !== 'guest';
  const canAccessOperations = isAdmin || isOperator;

  const capabilities: string[] = [];
  if (isAdmin) {
    capabilities.push('管理全站活动、DJ、Set、资讯、榜单与百科内容');
    capabilities.push('查看运营状态、通知中心和敏感后台能力');
  } else if (isOperator) {
    capabilities.push('协助处理运营审核、预登记和后台状态巡检');
  } else if (isOrganizer) {
    capabilities.push('以官方主办方身份发布活动和资讯');
    capabilities.push('维护自己名下活动的阵容、时间表和媒体素材');
  } else if (isArtist) {
    capabilities.push('维护自己的艺人资料、作品、演出记录和媒体素材');
    capabilities.push('管理自己上传的活动、DJ、Set 等内容');
  } else if (isSignedIn) {
    capabilities.push('管理自己上传的活动、DJ、Set、资讯和草稿内容');
  }

  return {
    role,
    label: ROLE_LABELS[role],
    description:
      role === 'guest'
        ? '登录后可进入内容管理工作台。'
        : '当前后台能力基于账号角色、内容 owner 字段和 contributor 关系共同约束。',
    canAccessAdminShell: isSignedIn,
    canAccessContentCms: isSignedIn,
    canAccessFullContentTool: isAdmin || isOperator || isOrganizer || isArtist || role === 'user',
    canAccessOperations,
    canAccessNotificationOps: isAdmin,
    canAccessPreRegistrationOps: canAccessOperations,
    capabilities,
  };
};
