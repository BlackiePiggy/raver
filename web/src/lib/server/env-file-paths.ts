import fs from 'fs';
import path from 'path';

const pathExists = (targetPath: string): boolean => {
  try {
    return fs.existsSync(targetPath);
  } catch {
    return false;
  }
};

const uniquePaths = (paths: string[]): string[] =>
  Array.from(new Set(paths.map((item) => path.resolve(item))));

const candidateBaseDirs = (cwd: string): string[] =>
  uniquePaths([
    cwd,
    path.resolve(cwd, '..'),
    path.resolve(cwd, '..', '..'),
    path.resolve(cwd, '..', '..', '..'),
  ]);

const findRepoRoot = (cwd: string): string | null => {
  for (const baseDir of candidateBaseDirs(cwd)) {
    if (pathExists(path.join(baseDir, 'web')) && pathExists(path.join(baseDir, 'server'))) {
      return baseDir;
    }
  }
  return null;
};

const firstExistingPath = (candidates: string[]): string | null => {
  for (const candidate of uniquePaths(candidates)) {
    if (pathExists(candidate)) {
      return candidate;
    }
  }
  return null;
};

export type AdminEnvFilePaths = {
  repoRoot: string | null;
  serverEnvPath: string;
  webEnvPath: string;
};

export const resolveAdminEnvFilePaths = (cwd: string = process.cwd()): AdminEnvFilePaths => {
  const repoRoot = findRepoRoot(cwd);
  if (repoRoot) {
    return {
      repoRoot,
      serverEnvPath: path.join(repoRoot, 'server', '.env'),
      webEnvPath: path.join(repoRoot, 'web', '.env.local'),
    };
  }

  const serverEnvCandidates = [
    path.join(cwd, 'server', '.env'),
    path.join(cwd, '.env'),
    path.resolve(cwd, '..', 'server', '.env'),
    path.resolve(cwd, '..', '..', 'server', '.env'),
  ];
  const webEnvCandidates = [
    path.join(cwd, 'web', '.env.local'),
    path.join(cwd, '.env.local'),
    path.resolve(cwd, '..', 'web', '.env.local'),
    path.resolve(cwd, '..', '..', 'web', '.env.local'),
  ];

  return {
    repoRoot: null,
    serverEnvPath: firstExistingPath(serverEnvCandidates) || path.resolve(serverEnvCandidates[0]),
    webEnvPath: firstExistingPath(webEnvCandidates) || path.resolve(webEnvCandidates[0]),
  };
};
