import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import { toTencentIMUserID } from '../services/tencent-im/tencent-im-id';

const prisma = new PrismaClient();

type ExportRow = {
  platformUserID: string;
  username: string;
  displayName: string;
  tencentIMUserID: string;
  active: boolean;
};

const rootDir = path.resolve(__dirname, '../../..');
const outputDir = path.join(rootDir, 'docs', 'generated');
const csvPath = path.join(outputDir, 'tencent-im-user-mapping.csv');
const mdPath = path.join(outputDir, 'tencent-im-user-mapping.md');
const jsonPath = path.join(outputDir, 'tencent-im-user-mapping.json');

const csvEscape = (value: string): string => {
  if (/[",\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
};

const toCSV = (rows: ExportRow[]): string => {
  const header = ['platformUserID', 'username', 'displayName', 'tencentIMUserID', 'active'];
  const lines = rows.map((row) =>
    [
      row.platformUserID,
      row.username,
      row.displayName,
      row.tencentIMUserID,
      String(row.active),
    ]
      .map(csvEscape)
      .join(',')
  );
  return [header.join(','), ...lines].join('\n');
};

const toMarkdown = (rows: ExportRow[]): string => {
  const lines = [
    '# Tencent IM User Mapping',
    '',
    `Generated at: ${new Date().toISOString()}`,
    '',
    `Total rows: ${rows.length}`,
    '',
    '| Platform User ID | Username | Display Name | Tencent IM User ID | Active |',
    '| --- | --- | --- | --- | --- |',
    ...rows.map((row) =>
      `| ${row.platformUserID} | ${row.username || '-'} | ${row.displayName || '-'} | ${row.tencentIMUserID} | ${row.active ? 'yes' : 'no'} |`
    ),
    '',
  ];
  return lines.join('\n');
};

const main = async (): Promise<void> => {
  const users = await prisma.user.findMany({
    where: { isActive: true },
    select: {
      id: true,
      username: true,
      displayName: true,
      isActive: true,
    },
    orderBy: {
      createdAt: 'asc',
    },
  });

  const rows: ExportRow[] = users.map((user) => ({
    platformUserID: user.id,
    username: user.username,
    displayName: user.displayName?.trim() || '',
    tencentIMUserID: toTencentIMUserID(user.id),
    active: user.isActive,
  }));

  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(csvPath, toCSV(rows), 'utf8');
  await fs.writeFile(mdPath, toMarkdown(rows), 'utf8');
  await fs.writeFile(jsonPath, JSON.stringify(rows, null, 2), 'utf8');

  console.log('[tencent-im:export-user-mapping] done', {
    totalRows: rows.length,
    csvPath,
    mdPath,
    jsonPath,
  });
};

void main()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[tencent-im:export-user-mapping] failed: ${message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
