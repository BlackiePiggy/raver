#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const YEARS = [2022, 2023, 2024, 2025];

const decodeHtml = (text) =>
  text
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, code) => String.fromCharCode(parseInt(code, 16)))
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#038;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();

async function fetchYear(year) {
  const url = `https://www.djmagvote.com/category/top-100-djs/${year}/`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed ${year}: HTTP ${response.status}`);
  }
  const html = await response.text();

  const rankRegex = new RegExp(
    '<span class="elementor-heading-title elementor-size-default">\\s*(\\d+)\\s*<\\/span>',
    'g'
  );
  const ranks = [];
  let rankMatch;
  while ((rankMatch = rankRegex.exec(html)) !== null) {
    const rank = Number(rankMatch[1]);
    if (rank >= 1 && rank <= 100) {
      ranks.push(rank);
    }
  }

  const nameRegex = new RegExp(
    `<h2[^>]*>\\s*<a href="https://www\\.djmagvote\\.com/category/top-100-djs/${year}/[^"]+/"[^>]*>(.*?)<\\/a>\\s*<\\/h2>`,
    'g'
  );
  const parsedNames = [];
  let nameMatch;
  while ((nameMatch = nameRegex.exec(html)) !== null) {
    parsedNames.push(decodeHtml(nameMatch[1]));
  }

  const names = [];
  for (let i = 0; i < 100; i += 1) {
    const fallbackRank = ranks[i] || i + 1;
    names.push(parsedNames[i] || `Unknown DJ (source missing rank ${fallbackRank})`);
  }

  return names;
}

async function main() {
  const outDir = path.join(__dirname, '..', 'web', 'public', 'rankings', 'djmag');
  fs.mkdirSync(outDir, { recursive: true });

  for (const year of YEARS) {
    const names = await fetchYear(year);
    const content = names.map((name, index) => `${index + 1}. ${name}`).join('\n') + '\n';
    const outPath = path.join(outDir, `${year}.txt`);
    fs.writeFileSync(outPath, content, 'utf8');
    console.log(`Saved ${year}.txt with ${names.length} rows`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
