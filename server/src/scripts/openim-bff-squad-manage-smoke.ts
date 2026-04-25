import 'dotenv/config';
import axios, { AxiosInstance } from 'axios';

type AuthSession = {
  token: string;
  userID: string;
};

const readRequired = (name: string): string => {
  const value = (process.env[name] || '').trim();
  if (!value) {
    throw new Error(`Missing required env: ${name}`);
  }
  return value;
};

const readOptional = (name: string, fallback = ''): string => {
  const value = (process.env[name] || '').trim();
  return value || fallback;
};

const normalizeBaseURL = (): string => {
  const raw = readOptional('OPENIM_BFF_BASE_URL', 'http://localhost:3901').replace(/\/+$/, '');
  return raw.endsWith('/v1') ? raw : `${raw}/v1`;
};

const createClient = (baseURL: string, token?: string): AxiosInstance => {
  return axios.create({
    baseURL,
    timeout: 15_000,
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  });
};

const login = async (baseURL: string, username: string, password: string): Promise<AuthSession> => {
  const client = createClient(baseURL);
  const response = await client.post('/auth/login', { username, password });
  const token = response.data?.token as string | undefined;
  const userID = response.data?.user?.id as string | undefined;
  if (!token || !userID) {
    throw new Error(`login failed: missing token or user id for ${username}`);
  }
  return { token, userID };
};

const resolveUserIDByUsername = async (client: AxiosInstance, username: string): Promise<string> => {
  const response = await client.get('/users/search', { params: { q: username } });
  const users = Array.isArray(response.data) ? response.data : [];
  const exact = users.find((item) => String(item?.username || '').toLowerCase() === username.toLowerCase());
  const matched = exact ?? users[0];
  if (!matched?.id) {
    throw new Error(`cannot resolve user by username: ${username}`);
  }
  return String(matched.id);
};

const main = async (): Promise<void> => {
  const baseURL = normalizeBaseURL();
  const leaderUsername = readRequired('OPENIM_BFF_SMOKE_LEADER_USERNAME');
  const leaderPassword = readRequired('OPENIM_BFF_SMOKE_LEADER_PASSWORD');
  const memberAUsername = readRequired('OPENIM_BFF_SMOKE_MEMBER_A_USERNAME');
  const memberAPassword = readRequired('OPENIM_BFF_SMOKE_MEMBER_A_PASSWORD');
  const memberBUsername = readRequired('OPENIM_BFF_SMOKE_MEMBER_B_USERNAME');
  const memberBPassword = readRequired('OPENIM_BFF_SMOKE_MEMBER_B_PASSWORD');
  const squadName = readOptional('OPENIM_BFF_SMOKE_SQUAD_NAME', `smoke-${Date.now()}`);

  console.log('[openim-bff-squad-manage-smoke] start', {
    baseURL,
    leaderUsername,
    memberAUsername,
    memberBUsername,
    squadName,
  });

  const leader = await login(baseURL, leaderUsername, leaderPassword);
  const memberA = await login(baseURL, memberAUsername, memberAPassword);
  const memberB = await login(baseURL, memberBUsername, memberBPassword);

  const leaderClient = createClient(baseURL, leader.token);
  const memberAClient = createClient(baseURL, memberA.token);

  const memberAUserID = await resolveUserIDByUsername(leaderClient, memberAUsername);
  const memberBUserID = await resolveUserIDByUsername(leaderClient, memberBUsername);

  if (memberAUserID !== memberA.userID) {
    console.warn('[openim-bff-squad-manage-smoke] memberA id mismatch', {
      fromSearch: memberAUserID,
      fromLogin: memberA.userID,
    });
  }
  if (memberBUserID !== memberB.userID) {
    console.warn('[openim-bff-squad-manage-smoke] memberB id mismatch', {
      fromSearch: memberBUserID,
      fromLogin: memberB.userID,
    });
  }

  const createResponse = await leaderClient.post('/squads', {
    name: squadName,
    description: 'openim bff squad manage smoke',
    isPublic: false,
    memberIds: [memberAUserID, memberBUserID],
  });
  const squadID = String(createResponse.data?.id || '');
  if (!squadID) {
    throw new Error('create squad failed: missing squad id');
  }
  console.log('[openim-bff-squad-manage-smoke] create squad ok', { squadID });

  await leaderClient.patch(`/squads/${squadID}/members/${memberAUserID}/role`, { role: 'admin' });
  console.log('[openim-bff-squad-manage-smoke] promote admin ok', { squadID, memberAUserID });

  await leaderClient.patch(`/squads/${squadID}/members/${memberAUserID}/role`, { role: 'leader' });
  console.log('[openim-bff-squad-manage-smoke] transfer leader ok', { squadID, newLeader: memberAUserID });

  await memberAClient.post(`/squads/${squadID}/members/${memberBUserID}/remove`);
  console.log('[openim-bff-squad-manage-smoke] remove member ok', { squadID, memberBUserID });

  await leaderClient.post(`/squads/${squadID}/leave`);
  console.log('[openim-bff-squad-manage-smoke] old leader leave ok', { squadID, oldLeader: leader.userID });

  const profileResponse = await memberAClient.get(`/squads/${squadID}/profile`);
  const profile = profileResponse.data as { leader?: { id?: string }; members?: Array<{ id?: string }> };
  const memberIDs = new Set((profile.members || []).map((item) => String(item.id || '')));

  if (String(profile.leader?.id || '') !== memberAUserID) {
    throw new Error('post-check failed: leader is not memberA');
  }
  if (memberIDs.has(memberBUserID)) {
    throw new Error('post-check failed: memberB still exists');
  }
  if (memberIDs.has(leader.userID)) {
    throw new Error('post-check failed: old leader still exists');
  }

  console.log('[openim-bff-squad-manage-smoke] all checks passed', {
    squadID,
    finalLeader: memberAUserID,
    finalMemberCount: memberIDs.size,
  });
};

main().catch((error) => {
  console.error('[openim-bff-squad-manage-smoke] failed', error);
  process.exitCode = 1;
});
