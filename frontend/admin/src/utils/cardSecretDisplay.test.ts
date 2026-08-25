import { describe, expect, it } from 'vitest'
import type { AdminProduct } from '@/api/types'
import {
  buildCardSecretSkuLabelCatalog,
  mergeCardSecretProductCatalog,
  resolveCardSecretSkuLabel,
} from './cardSecretDisplay'

const product = (id: number, skuID: number, skuCode: string, specValues: Record<string, string>): AdminProduct => ({
  id,
  fulfillment_type: 'auto',
  skus: [{ id: skuID, product_id: id, sku_code: skuCode, spec_values: specValues }],
} as AdminProduct)

describe('card-secret SKU display catalog', () => {
  it('resolves a business SKU label before a product filter is selected', () => {
    const catalog = mergeCardSecretProductCatalog(new Map(), [
      product(6, 105, 'Gatorade-100', { 'en-US': '$100' }),
    ])
    const labels = buildCardSecretSkuLabelCatalog(catalog.values())

    expect(resolveCardSecretSkuLabel(labels, 6, 105)).toBe('Gatorade-100 · en-US:$100')
  })

  it('retains labels independently from changing product search results', () => {
    let catalog = mergeCardSecretProductCatalog(new Map(), [
      product(6, 105, 'Gatorade-100', { 'en-US': '$100' }),
      product(7, 106, 'Adidas-200', { 'en-US': '$200' }),
    ])

    catalog = mergeCardSecretProductCatalog(catalog, [
      product(6, 105, 'Gatorade-100', { 'en-US': '$100' }),
    ])
    const labels = buildCardSecretSkuLabelCatalog(catalog.values())

    expect(resolveCardSecretSkuLabel(labels, 7, 106)).toBe('Adidas-200 · en-US:$200')
    expect(resolveCardSecretSkuLabel(labels, 7, 999)).toBe('#999')
  })

  it('does not let placeholder products erase cached SKU metadata', () => {
    let catalog = mergeCardSecretProductCatalog(new Map(), [
      product(6, 105, 'Gatorade-100', { 'en-US': '$100' }),
    ])
    catalog = mergeCardSecretProductCatalog(catalog, [{ id: 6, fulfillment_type: 'auto' } as AdminProduct])

    const labels = buildCardSecretSkuLabelCatalog(catalog.values())
    expect(resolveCardSecretSkuLabel(labels, 6, 105)).toBe('Gatorade-100 · en-US:$100')
  })
})
