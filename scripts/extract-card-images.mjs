#!/usr/bin/env node

/**
 * Extract the gift-card artwork embedded in card.pdf and publish one normalized
 * WebP image per storefront product.
 *
 * Usage:
 *   node scripts/extract-card-images.mjs /absolute/path/to/card.pdf
 */

import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, join, resolve } from 'node:path'
import { giftCardCatalog } from './card-catalog.mjs'

const sourcePDF = process.argv[2]
if (!sourcePDF) throw new Error('Pass the absolute path to card.pdf.')
if (!existsSync(sourcePDF)) throw new Error(`PDF not found: ${sourcePDF}`)

const outputDir = resolve('frontend/user/public/gift-cards')
const workDir = mkdtempSync(join(tmpdir(), 'usgiftcardhub-card-images-'))
mkdirSync(outputDir, { recursive: true })

const run = (command, args, options = {}) => execFileSync(command, args, {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
  ...options,
})

const findCardBounds = (imagePath) => {
  const result = spawnSync('magick', [
    imagePath,
    '-crop', '300x+0+0',
    '-colorspace', 'gray',
    '-threshold', '94%',
    '-negate',
    '-define', 'connected-components:verbose=true',
    '-connected-components', '8',
    'null:',
  ], { encoding: 'utf8' })
  if (result.status !== 0) throw new Error(result.stderr || `ImageMagick failed for ${basename(imagePath)}`)
  const output = `${result.stdout || ''}\n${result.stderr || ''}`

  const allComponents = output
    .split('\n')
    .map((line) => line.match(/\s\d+:\s(\d+)x(\d+)\+(\d+)\+(\d+)\s/))
    .filter(Boolean)
    .map((match) => ({
      width: Number(match[1]),
      height: Number(match[2]),
      x: Number(match[3]),
      y: Number(match[4]),
    }))
  const components = allComponents
    .filter(({ width, height, x }) => width >= 150 && width <= 240 && height >= 80 && height <= 170 && x <= 110)
    .sort((a, b) => (b.width * b.height) - (a.width * a.height))

  // The source StubHub artwork is a very thin purple card mark rather than a
  // conventional rectangle. Keep it as a last-resort source-specific crop.
  if (!components.length) {
    components.push(...allComponents
      .filter(({ width, height, x, y }) => width >= 150 && width <= 240 && height >= 8 && x <= 110 && y >= 70)
      .sort((a, b) => (b.width * b.height) - (a.width * a.height)))
  }

  if (!components.length) throw new Error(`Could not locate gift-card artwork in ${basename(imagePath)}`)
  return components[0]
}

try {
  const prefix = join(workDir, 'card')
  run('pdfimages', ['-png', sourcePDF, prefix])

  const generated = []
  for (const item of giftCardCatalog) {
    const sourceNumber = item.sourceNumbers[0]
    const embeddedIndex = String(sourceNumber - 1).padStart(3, '0')
    const sourceImage = `${prefix}-${embeddedIndex}.png`
    const bounds = findCardBounds(sourceImage)
    const padding = 3
    const x = Math.max(0, bounds.x - padding)
    const y = Math.max(0, bounds.y - padding)
    const width = bounds.width + (padding * 2)
    const height = bounds.height + (padding * 2)
    const destination = join(outputDir, `${item.slug}.webp`)

    run('magick', [
      sourceImage,
      '-crop', `${width}x${height}+${x}+${y}`,
      '+repage',
      '-resize', '460x280',
      '-background', 'white',
      '-gravity', 'center',
      '-extent', '480x300',
      '-strip',
      '-quality', '88',
      destination,
    ])

    // Two source screenshots do not contain usable artwork. Preserve the
    // source brand identity with a clean text-card fallback instead of showing
    // a broken image or a thin placeholder line.
    if (item.slug === 'stubhub-gift-card') {
      run('magick', [
        '-size', '480x300', 'gradient:#8b5cf6-#4c1d95',
        '-gravity', 'center', '-font', 'Helvetica-Bold', '-fill', 'white',
        '-pointsize', '58', '-annotate', '+0+0', 'StubHub',
        '-strip', '-quality', '88', destination,
      ])
    }
    if (item.slug === 'factor-gift-card') {
      run('magick', [
        '-size', '480x300', 'gradient:#17251e-#07110c',
        '-gravity', 'center', '-font', 'Helvetica-Bold', '-fill', 'white',
        '-pointsize', '62', '-annotate', '+0-18', 'FACTOR',
        '-font', 'Helvetica', '-pointsize', '21', '-annotate', '+0+46', 'Healthy Eating - Made Simple',
        '-strip', '-quality', '88', destination,
      ])
    }
    generated.push(destination)
  }

  console.log(JSON.stringify({ generated: generated.length, outputDir }, null, 2))
} finally {
  rmSync(workDir, { recursive: true, force: true })
}
