#!/usr/bin/env node

/**
 * Idempotently applies the US Gift Card Hub starter catalog and storefront
 * settings to a running Dujiao-Next API.
 *
 * Required environment variables:
 *   DJ_ADMIN_USER
 *   DJ_ADMIN_PASSWORD
 *
 * Optional environment variables:
 *   DJ_API_BASE=http://127.0.0.1:8080/api/v1
 *   DJ_SITE_URL=http://127.0.0.1:8080
 */

import { giftCardCatalog, giftCardCategories } from './card-catalog.mjs'

const apiBase = (process.env.DJ_API_BASE || 'http://127.0.0.1:8080/api/v1').replace(/\/$/, '')
const siteURL = (process.env.DJ_SITE_URL || 'http://127.0.0.1:8080').replace(/\/$/, '')
const username = String(process.env.DJ_ADMIN_USER || '').trim()
const password = String(process.env.DJ_ADMIN_PASSWORD || '')

if (!username || !password) {
  console.error('DJ_ADMIN_USER and DJ_ADMIN_PASSWORD are required.')
  process.exit(1)
}

const localized = (zhCN, zhTW, enUS) => ({
  'zh-CN': zhCN,
  'zh-TW': zhTW,
  'en-US': enUS,
})

const parseResponse = async (response) => {
  const text = await response.text()
  let payload
  try {
    payload = JSON.parse(text)
  } catch {
    throw new Error(`${response.status} ${response.url}: ${text.slice(0, 300)}`)
  }
  if (!response.ok) {
    throw new Error(`${response.status} ${response.url}: ${JSON.stringify(payload)}`)
  }
  return payload
}

const login = await parseResponse(await fetch(`${apiBase}/admin/login`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ username, password }),
}))
const token = login?.data?.token
if (!token) throw new Error(`Admin login did not return a token: ${JSON.stringify(login)}`)

const request = async (path, method = 'GET', body) => {
  const response = await fetch(`${apiBase}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  return (await parseResponse(response)).data
}

const updateSetting = (key, value) => request('/admin/settings', 'PUT', { key, value })

await updateSetting('site_config', {
  brand: {
    site_name: 'US Gift Card Hub',
    site_url: siteURL,
    site_icon: '',
    site_logo: '',
    site_description: localized(
      '美国礼品卡品牌目录。支付尚未接入，当前仅供浏览。',
      '美國禮品卡品牌目錄。支付尚未接入，目前僅供瀏覽。',
      'A US gift card brand catalog. Payments are not connected; browsing only.',
    ),
  },
  contact: { telegram: '', whatsapp: '' },
  seo: {
    title: localized('美国礼品卡商城 | US Gift Card Hub', '美國禮品卡商城 | US Gift Card Hub', 'US Gift Card Store | US Gift Card Hub'),
    keywords: localized('美国礼品卡,数字礼品卡,Apple礼品卡,Amazon礼品卡', '美國禮品卡,數位禮品卡,Apple禮品卡,Amazon禮品卡', 'US gift cards,digital gift cards,Apple gift card,Amazon gift card'),
    description: localized('浏览即将上线的美国区数字礼品卡目录。支付暂未接入，当前不支持购买。', '瀏覽即將上線的美國區數位禮品卡目錄。支付暫未接入，目前不支援購買。', 'Browse our upcoming US gift card catalog. Payments and purchasing are not available yet.'),
  },
  legal: {
    terms: localized(
      '当前支付与交付尚未接入，站内商品仅供目录展示，不能下单。正式开售后，购买前请确认商品面额、适用地区、账户区域及退款规则。',
      '目前支付與交付尚未接入，站內商品僅供目錄展示，不能下單。正式開售後，購買前請確認商品面額、適用地區、帳戶區域及退款規則。',
      'Payments and fulfillment are not connected. Listings are catalog previews only and cannot be ordered. Denomination, region, account eligibility, and refund terms must be confirmed before launch.',
    ),
    privacy: localized(
      '我们仅收集完成订单、交付与售后所需的信息。正式上线前需要补充运营主体、数据保存期限和联系渠道。',
      '我們僅收集完成訂單、交付與售後所需的資訊。正式上線前需要補充營運主體、資料保存期限和聯絡管道。',
      'We collect only the information needed for orders, delivery, and support. Operator identity, retention periods, and support contacts must be completed before launch.',
    ),
  },
  about: {
    hero: {
      title: localized('关于 US Gift Card Hub', '關於 US Gift Card Hub', 'About US Gift Card Hub'),
      subtitle: localized('美国区数字礼品卡目录即将上线', '美國區數位禮品卡目錄即將上線', 'US gift card catalog coming soon'),
    },
    introduction: localized(
      '我们正在整理面额、适用地区、兑换条件和售后边界。支付尚未接入，当前仅开放目录浏览。',
      '我們正在整理面額、適用地區、兌換條件和售後邊界。支付尚未接入，目前僅開放目錄瀏覽。',
      'We are preparing denomination, region, redemption, and support details. Payments are not connected and the catalog is browse-only.',
    ),
    services: {
      title: localized('我们提供', '我們提供', 'What we offer'),
      items: [
        localized('美国区数字礼品卡商品展示', '美國區數位禮品卡商品展示', 'US-region digital gift card listings'),
        localized('订单与交付状态查询', '訂單與交付狀態查詢', 'Order and delivery tracking'),
        localized('明确的兑换与售后说明', '清楚的兌換與售後說明', 'Clear redemption and support guidance'),
      ],
    },
    contact: {
      title: localized('联系我们', '聯絡我們', 'Contact us'),
      text: localized('正式客服邮箱与即时通讯方式待运营方提供。', '正式客服信箱與即時通訊方式待營運方提供。', 'Support email and messaging details are pending operator input.'),
    },
  },
  scripts: [],
  footer_links: [],
  languages: ['en-US', 'zh-CN', 'zh-TW'],
  currency: 'USD',
  template_mode: 'card',
  storefront_template: 'vault',
  purchasing_enabled: false,
})

await updateSetting('nav_config', {
  builtin: { blog: false, notice: true, about: true },
  custom_items: [],
})

await updateSetting('registration_config', {
  registration_enabled: true,
  email_verification_enabled: false,
  email_domain_allowlist_enabled: false,
  allowed_email_domains: [],
})

const flattenCategories = (items) => items.flatMap((item) => [item, ...flattenCategories(item.children || [])])
const existingCategories = flattenCategories(await request('/admin/categories'))
const categoriesBySlug = new Map(existingCategories.map((item) => [item.slug, item]))

const upsertCategory = async (payload) => {
  const current = categoriesBySlug.get(payload.slug)
  const applied = current
    ? await request(`/admin/categories/${current.id}`, 'PUT', payload)
    : await request('/admin/categories', 'POST', payload)
  categoriesBySlug.set(payload.slug, applied)
  return applied
}

const rootCategory = await upsertCategory({
  parent_id: 0,
  slug: 'us-gift-cards',
  name: localized('美国礼品卡', '美國禮品卡', 'US Gift Cards'),
  icon: '',
  sort_order: 100,
})

const categoryIDs = new Map()
for (const definition of giftCardCategories) {
  const category = await upsertCategory({
    parent_id: rootCategory.id,
    slug: definition.slug,
    name: localized(definition.zhCN, definition.zhTW, definition.enUS),
    icon: '',
    sort_order: definition.sortOrder,
  })
  categoryIDs.set(definition.slug, category.id)
}

const sharedProduct = {
  images: [],
  purchase_type: 'guest',
  min_purchase_quantity: 1,
  max_purchase_quantity: 1,
  stock_display_mode: 'status',
  fulfillment_type: 'manual',
  manual_stock_total: 0,
  manual_form_schema: {},
  wholesale_prices: [],
  skus: [],
  payment_channel_ids: [],
  is_affiliate_enabled: false,
  is_active: true,
}

const products = giftCardCatalog.map((item) => {
  return {
    ...sharedProduct,
    seo_meta: {
      catalog_preview: true,
      available_amounts: item.availableAmounts,
      source_document: 'card.pdf',
      source_items: item.sourceNumbers,
    },
    category_id: categoryIDs.get(item.category),
    images: [`/gift-cards/${item.slug}.webp`],
    slug: item.slug,
    title: localized(`${item.brand} 美国礼品卡`, `${item.brand} 美國禮品卡`, `${item.brand} Gift Card`),
    description: localized(
      `${item.brand} 美国礼品卡。可用金额：${item.availableAmounts}。`,
      `${item.brand} 美國禮品卡。可用金額：${item.availableAmounts}。`,
      item.description,
    ),
    content: localized(
      `<h2>可用金额</h2><p>${item.availableAmounts}</p><p>金额为可输入区间或固定下拉面额。</p>`,
      `<h2>可用金額</h2><p>${item.availableAmounts}</p><p>金額為可輸入區間或固定下拉面額。</p>`,
      `<h2>Available amounts</h2><p>${item.availableAmounts}</p><p>Amounts are shown as an input range or fixed dropdown denominations.</p>`,
    ),
    instructions: localized('暂未开放兑换与交付。', '暫未開放兌換與交付。', 'Redemption and fulfillment are not available yet.'),
    // Required by Dujiao-Next's product model, but hidden from the storefront
    // while stock is zero. This sentinel is not a denomination or sale price.
    price_amount: 0.01,
    cost_price_amount: 0,
    tags: [item.brand],
    sort_order: 1000 - Math.min(...item.sourceNumbers),
  }
})

const listAllProducts = async () => {
  const result = []
  for (let page = 1; ; page += 1) {
    const rows = await request(`/admin/products?page=${page}&page_size=100`)
    result.push(...rows)
    if (rows.length < 100) return result
  }
}

const currentProducts = await listAllProducts()
const currentBySlug = new Map(currentProducts.map((item) => [item.slug, item]))
const appliedProducts = []
for (const payload of products) {
  const current = currentBySlug.get(payload.slug)
  appliedProducts.push(current
    ? await request(`/admin/products/${current.id}`, 'PUT', payload)
    : await request('/admin/products', 'POST', payload))
}

// Retire the original starter examples that are not present in card.pdf.
// PATCH makes this reversible and keeps historical records intact.
const retiredStarterSlugs = new Set([
  'amazon-gift-card-us-50',
  'google-play-gift-card-us-25',
  'steam-wallet-us-20',
])
const retiredProducts = []
for (const item of currentProducts) {
  if (retiredStarterSlugs.has(item.slug) && item.is_active) {
    retiredProducts.push(await request(`/admin/products/${item.id}`, 'PATCH', { is_active: false }))
  }
}

console.log(JSON.stringify({
  api_base: apiBase,
  site_url: siteURL,
  source_rows: 100,
  unique_products: appliedProducts.length,
  root_category: rootCategory.slug,
  child_categories: giftCardCategories.map(({ slug }) => slug),
  retired_starter_products: retiredProducts.map(({ slug }) => slug),
  purchasing_enabled: false,
}, null, 2))
