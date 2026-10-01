// Static gate - ESLint with TypeScript rules, alongside `tsc --noEmit`. Two
// tools because they answer different questions: tsc proves the types hold,
// ESLint proves the code follows the rules the types cannot express.
import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  { ignores: ['dist', 'node_modules', 'playwright-report', 'test-results', 'gate-logs'] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      // A warning is a failure. The gate runs with --max-warnings=0, so
      // anything the linter reports stops the build rather than scrolling
      // past in a log nobody reads.
      'no-console': 'error',
      // SEC-015 - output encoding is JSX's escaping, and dangerouslySetInnerHTML
      // is the one door around it. Banned by syntax (no plugin needed); the
      // measured baseline is zero usages, and this rule is what keeps that
      // number load-bearing instead of incidental.
      'no-restricted-syntax': [
        'error',
        {
          selector: "JSXAttribute[name.name='dangerouslySetInnerHTML']",
          message: 'SEC-015: dangerouslySetInnerHTML bypasses JSX output encoding - render text and let React escape it.',
        },
        {
          // Assignment only: tests legitimately READ innerHTML (Playwright's
          // .innerHTML(), container.innerHTML comparisons) - writing is the
          // injection sink.
          selector: "AssignmentExpression > MemberExpression.left[property.name='innerHTML']",
          message: 'SEC-015: assigning innerHTML bypasses output encoding - build DOM through React.',
        },
      ],
    },
  },
  {
    files: ['tests/**/*.{ts,tsx}', '*.config.{ts,js}', 'vitest.setup.ts'],
    languageOptions: { globals: { ...globals.browser, ...globals.node } },
  },
)
