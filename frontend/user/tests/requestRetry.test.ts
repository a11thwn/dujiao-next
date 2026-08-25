import assert from 'node:assert/strict'
import test from 'node:test'

import {
    GET_RETRY_DELAYS_MS,
    REQUEST_TIMEOUT_MS,
    fetchWithGetRetry,
    isRetryableGetStatus,
} from '../src/api/requestRetry.ts'

test('GET retry policy uses a 20 second timeout and two bounded retries', () => {
    assert.equal(REQUEST_TIMEOUT_MS, 20_000)
    assert.deepEqual(GET_RETRY_DELAYS_MS, [500, 1_500])
    assert.equal(isRetryableGetStatus(408), true)
    assert.equal(isRetryableGetStatus(429), true)
    assert.equal(isRetryableGetStatus(503), true)
    assert.equal(isRetryableGetStatus(404), false)
})

test('GET retries transient fetch failures and succeeds on the third attempt', async () => {
    let attempts = 0
    const delays: number[] = []
    const response = await fetchWithGetRetry('/api/test', {}, {
        method: 'GET',
        retryDelaysMs: [5, 10],
        fetchImpl: async () => {
            attempts += 1
            if (attempts < 3) throw new TypeError('network failed')
            return new Response('{}', { status: 200 })
        },
        sleep: async (delayMs) => { delays.push(delayMs) },
    })

    assert.equal(response.status, 200)
    assert.equal(attempts, 3)
    assert.deepEqual(delays, [5, 10])
})

test('GET retries transient HTTP responses but POST is never replayed', async () => {
    let getAttempts = 0
    const getResponse = await fetchWithGetRetry('/api/test', {}, {
        method: 'GET',
        retryDelaysMs: [1, 2],
        fetchImpl: async () => {
            getAttempts += 1
            return new Response('{}', { status: getAttempts === 1 ? 503 : 200 })
        },
        sleep: async () => {},
    })
    assert.equal(getResponse.status, 200)
    assert.equal(getAttempts, 2)

    let postAttempts = 0
    await assert.rejects(() => fetchWithGetRetry('/api/test', {}, {
        method: 'POST',
        retryDelaysMs: [1, 2],
        fetchImpl: async () => {
            postAttempts += 1
            throw new TypeError('network failed')
        },
        sleep: async () => {},
    }))
    assert.equal(postAttempts, 1)
})
