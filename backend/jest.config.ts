import type { Config } from 'jest';

const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '.*\\.spec\\.ts$',
  transform: {
    '^.+\\.(t|j)s$': [
      'ts-jest',
      {
        tsconfig: {
          module: 'commonjs',
          moduleResolution: 'node16',
          resolvePackageJsonExports: false,
          target: 'ES2022',
          ignoreDeprecations: '6.0',
        },
      },
    ],
  },
  testEnvironment: 'node',
};

export default config;
