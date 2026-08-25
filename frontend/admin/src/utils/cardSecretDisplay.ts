import type { AdminProduct, AdminProductSKU } from '@/api/types'

export type CardSecretProductCatalog = ReadonlyMap<number, AdminProduct>

const normalizeID = (value: unknown) => {
  const parsed = Number(value || 0)
  if (!Number.isFinite(parsed) || parsed <= 0) return 0
  return Math.floor(parsed)
}

export const formatCardSecretSkuSpecValues = (specValues: Record<string, string> | null | undefined) => {
  if (!specValues || typeof specValues !== 'object' || Array.isArray(specValues)) return ''
  return Object.entries(specValues as Record<string, string>)
    .map(([key, value]) => {
      const keyText = String(key || '').trim()
      const valueText = Array.isArray(value)
        ? value.map((entry) => String(entry || '').trim()).filter(Boolean).join(', ')
        : String(value ?? '').trim()
      if (!valueText) return ''
      if (!keyText) return valueText
      return `${keyText}:${valueText}`
    })
    .filter(Boolean)
    .join(' / ')
}

export const buildCardSecretSkuLabel = (sku: AdminProductSKU | null | undefined) => {
  const skuCode = String(sku?.sku_code || '').trim()
  const specText = formatCardSecretSkuSpecValues(sku?.spec_values)
  if (skuCode && specText) return `${skuCode} · ${specText}`
  if (skuCode) return skuCode
  if (specText) return specText
  if (sku?.id) return `#${sku.id}`
  return '-'
}

export const mergeCardSecretProductCatalog = (
  current: CardSecretProductCatalog,
  incoming: AdminProduct[],
) => {
  const next = new Map(current)
  incoming.forEach((product) => {
    const productID = normalizeID(product?.id)
    if (!productID) return

    const previous = next.get(productID)
    if (!previous) {
      next.set(productID, product)
      return
    }

    next.set(productID, {
      ...previous,
      ...product,
      skus: Array.isArray(product.skus) ? product.skus : previous.skus,
    })
  })
  return next
}

const skuCatalogKey = (productID: number, skuID: number) => `${productID}:${skuID}`

export const buildCardSecretSkuLabelCatalog = (products: Iterable<AdminProduct>) => {
  const labels = new Map<string, string>()
  for (const product of products) {
    const productID = normalizeID(product?.id)
    if (!productID || !Array.isArray(product?.skus)) continue
    product.skus.forEach((sku) => {
      const skuID = normalizeID(sku?.id)
      if (!skuID) return
      labels.set(skuCatalogKey(productID, skuID), buildCardSecretSkuLabel(sku))
    })
  }
  return labels
}

export const resolveCardSecretSkuLabel = (
  labels: ReadonlyMap<string, string>,
  productIDValue: unknown,
  skuIDValue: unknown,
) => {
  const skuID = normalizeID(skuIDValue)
  if (!skuID) return '-'
  const productID = normalizeID(productIDValue)
  if (!productID) return `#${skuID}`
  return labels.get(skuCatalogKey(productID, skuID)) || `#${skuID}`
}
