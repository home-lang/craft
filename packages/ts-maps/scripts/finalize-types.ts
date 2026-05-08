#!/usr/bin/env bun
import { cpSync, existsSync, rmSync } from 'node:fs'
import { join } from 'node:path'

const nested = join('dist', 'Tools', 'craft', 'packages', 'ts-maps', 'src')

if (!existsSync(nested))
  throw new Error(`Expected TypeScript declarations at ${nested}`)

cpSync(nested, 'dist', { recursive: true })
rmSync(join('dist', 'Tools'), { recursive: true, force: true })
rmSync(join('dist', 'Libraries'), { recursive: true, force: true })
