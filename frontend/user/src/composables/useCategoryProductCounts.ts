import { productAPI } from '../api'

export type CategoryProductCounts = Record<number, number>

export interface CategoryProductCountResult {
  counts: CategoryProductCounts
  total: number
}

export const fetchCategoryProductCounts = async (): Promise<CategoryProductCountResult> => {
  const pageSize = 200
  const firstResponse = await productAPI.list({ page: 1, page_size: pageSize })
  const firstRows = Array.isArray(firstResponse.data.data) ? firstResponse.data.data : []
  const totalPages = Math.max(1, Number(firstResponse.data.pagination?.total_page || 1))
  const remainingResponses = totalPages > 1
    ? await Promise.all(Array.from({ length: totalPages - 1 }, (_, index) => productAPI.list({ page: index + 2, page_size: pageSize })))
    : []
  const rows = [
    ...firstRows,
    ...remainingResponses.flatMap((response) => Array.isArray(response.data.data) ? response.data.data : []),
  ]

  const counts: CategoryProductCounts = {}
  rows.forEach((product) => {
    const categoryId = Number(product?.category_id || product?.category?.id || 0)
    if (!Number.isFinite(categoryId) || categoryId <= 0) return
    counts[categoryId] = (counts[categoryId] || 0) + 1
  })

  return {
    counts,
    total: Number(firstResponse.data.pagination?.total || rows.length),
  }
}
