module.exports = {
    root: true,
    env: {
      browser: true,
      node: true,
      es2021: true,
      jest: true,
    },
    parser: '@typescript-eslint/parser',
    parserOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      project: ['./tsconfig.json', './backend/tsconfig.json', './frontend/tsconfig.json'],
      tsconfigRootDir: __dirname,
      ecmaFeatures: {
        jsx: true,
      },
    },
    extends: [
      'eslint:recommended',
      'plugin:@typescript-eslint/recommended',
      'plugin:react/recommended',
      'plugin:react-hooks/recommended',
      'plugin:prettier/recommended',
    ],
    plugins: ['@typescript-eslint', 'react', 'react-hooks', 'prettier'],
    settings: {
      react: {
        version: 'detect',
      },
      'import/resolver': {
        typescript: {
          project: ['./tsconfig.json', './backend/tsconfig.json', './frontend/tsconfig.json'],
        },
      },
    },
    rules: {
      // TypeScript rules
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/consistent-type-imports': 'error',
  
      // React rules
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
  
      // General rules
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-debugger': 'warn',
      'prefer-const': 'error',
      'no-var': 'error',
  
      // Prettier rules
      'prettier/prettier': 'error',
    },
    overrides: [
      {
        // Backend specific rules
        files: ['backend/**/*.ts'],
        env: {
          node: true,
        },
        rules: {
          '@typescript-eslint/no-var-requires': 'off',
        },
      },
      {
        // Frontend specific rules
        files: ['frontend/**/*.ts', 'frontend/**/*.tsx'],
        extends: ['next/core-web-vitals'],
        rules: {
          'react-hooks/rules-of-hooks': 'error',
          'react-hooks/exhaustive-deps': 'warn',
        },
      },
      {
        // Test files
        files: ['**/*.test.ts', '**/*.test.tsx', '**/*.spec.ts', '**/*.spec.tsx'],
        env: {
          jest: true,
        },
      },
      {
        // JS config files
        files: ['.eslintrc.js'],
        parser: 'espree',
        rules: {},
      },
      {
        // Frontend configuration files
        files: ['frontend/next.config.ts', 'frontend/postcss.config.mjs'],
        parser: '@typescript-eslint/parser',
        rules: {
          '@typescript-eslint/no-var-requires': 'off', // Allow CommonJS-style imports
          '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
        },
      },
    ],
  };