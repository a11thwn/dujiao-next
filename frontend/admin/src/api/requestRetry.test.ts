import { describe, expect, it, vi } from 'vitest'

import {
  GET_RETRY_DELAYS_MS,
  REQUEST_TIMEOUT_MS,
  fetchWithGetRetry,
  isRetryableGetStatus,
} from './requestRetry'

describe('GET request retry policy', () => {
  it('uses a 20 second timeout and two bounded retries', () => {
    expect(REQUEST_TIMEOUT_MS).toBe(20_000)
    expect(GET_RETRY_DELAYS_MS).toEqual([500, 1_500])
    expect(isRetryableGetStatus(408)).toBe(true)
    expect(isRetryableGetStatus(429)).toBe(true)
    expect(isRetryableGetStatus(503)).toBe(true)
    expect(isRetryableGetStatus(404)).toBe(false)
  })

  it('retries GET failures but never replays POST', async () => {
    const getFetch = vi.fn()
      .mockRejectedValueOnce(new TypeError('network failed'))
      .mockResolvedValue(new Response('{}', { status: 200 }))
    const response = await fetchWithGetRetry('/api/test', {}, {
      method: 'GET',
      retryDelaysMs: [1, 2],
      fetchImpl: getFetch,
      sleep: async () => {},
    })
    expect(response.status).toBe(200)
    expect(getFetch).toHaveBeenCalledTimes(2)

    const postFetch = vi.fn().mockRejectedValue(new TypeError('network failed'))
    await expect(fetchWithGetRetry('/api/test', {}, {
      method: 'POST',
      retryDelaysMs: [1, 2],
      fetchImpl: postFetch,
      sleep: async () => {},
    })).rejects.toThrow('network failed')
    expect(postFetch).toHaveBeenCalledTimes(1)
  })
})
