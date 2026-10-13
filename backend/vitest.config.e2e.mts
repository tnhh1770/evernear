import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 60000,
    hookTimeout: 120000,
    env: {
      NODE_ENV: 'test',
      DISABLE_WORKER_CRON: 'true',
      DB_NAME: 'carely_test_db',
    },
    include: ['test/e2e/**/*.spec.ts', 'test/**/*.e2e-spec.ts'],
    fileParallelism: false,
    maxWorkers: 1,
    pool: 'forks',
    isolate: true,
    sequence: {
      concurrent: false,
    },
  },
});
