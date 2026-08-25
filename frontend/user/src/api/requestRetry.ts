export const REQUEST_TIMEOUT_MS = 20_000
export const GET_RETRY_DELAYS_MS = [500, 1_500] as const

type FetchWithRetryOptions = {
    method: string
    timeoutMs?: number
    retryDelaysMs?: readonly number[]
    fetchImpl?: typeof fetch
    sleep?: (delayMs: number) => Promise<void>
}

const defaultSleep = (delayMs: number) => new Promise<void>((resolve) => {
    setTimeout(resolve, delayMs)
})

export const isRetryableGetStatus = (status: number) =>
    status === 408 || status === 425 || status === 429 || (status >= 500 && status <= 599)

export async function fetchWithGetRetry(
    input: RequestInfo | URL,
    init: RequestInit,
    options: FetchWithRetryOptions,
): Promise<Response> {
    const method = String(options.method || 'GET').toUpperCase()
    const retryDelays = method === 'GET'
        ? (options.retryDelaysMs ?? GET_RETRY_DELAYS_MS)
        : []
    const timeoutMs = options.timeoutMs ?? REQUEST_TIMEOUT_MS
    const fetchImpl = options.fetchImpl ?? fetch
    const sleep = options.sleep ?? defaultSleep

    for (let attempt = 0; ; attempt += 1) {
        const controller = new AbortController()
        const timer = setTimeout(() => controller.abort(), timeoutMs)
        let response: Response | undefined
        let failure: unknown

        try {
            response = await fetchImpl(input, {
                ...init,
                method,
                signal: controller.signal,
            })
        } catch (error) {
            failure = error
        } finally {
            clearTimeout(timer)
        }

        if (failure !== undefined) {
            if (attempt >= retryDelays.length) {
                throw failure
            }
            await sleep(retryDelays[attempt]!)
            continue
        }
        if (!response) {
            throw new Error('Request completed without a response')
        }
        if (attempt >= retryDelays.length || !isRetryableGetStatus(response.status)) {
            return response
        }
        await response.body?.cancel().catch(() => {})
        await sleep(retryDelays[attempt]!)
    }
}
