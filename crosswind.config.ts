import type { CrosswindOptions } from '@cwcss/crosswind'

const config: CrosswindOptions = {
  content: [
    './packages/stx/src/**/*.ts',
    './templates/projects/**/src/**/*.ts',
    './examples/**/src/**/*.ts',
  ],
  output: './dist/crosswind.css',
  minify: false,
}

export default config
