const message = [
  '[canonical-migrate] retired',
  'Canonical relationship migration has already been completed and legacy source tables/columns were dropped.',
  'This script is intentionally disabled to prevent re-running a historical migration against the canonical-only schema.',
  'Use `pnpm canonical:validate` for canonical health checks instead.',
].join('\n');

console.error(message);
process.exitCode = 1;
