import axios from 'axios'

// 候选后端主机（优先级按顺序）：本地 -> 局域网 -> 线上
const CANDIDATE_HOSTS = [
  'http://localhost:8085',
  'http://10.7.0.1:8085',
  'https://api.zhougis.app'
]

const apiPrefix = '/api/'

// 默认选项（在 initApiHost 之前使用此默认值）
const DEFAULT_HOST = process.env.NODE_ENV === 'development'
  ? 'http://localhost:8085'
  : 'https://api.zhougis.app'

let baseHost = process.env.VUE_APP_API_HOST || DEFAULT_HOST

const remote_api = `${baseHost}${apiPrefix}`

// 创建 axios 实例，baseURL 会在 initApiHost 中被覆盖为探测到的可用主机
const http = axios.create({
  baseURL: remote_api,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json'
  }
})

/**
 * 探测指定 host 是否可用（通过 GET /api/user/handshake，返回 true 表示可用）
 * @param {string} host
 * @returns {Promise<boolean>}
 */
async function probeHost(host) {
  try {
    const url = `${host}${apiPrefix}user/handshake`
    const res = await axios.get(url, { timeout: 2000 })
    return res && res.data === true
  } catch (e) {
    return false
  }
}

/**
 * 初始化 API 主机：按候选顺序探测并设置 `http.defaults.baseURL`，
 * 返回被选中的 baseHost 字符串。
 * 建议在应用入口（`main.js`）调用一次，并 await 其完成。
 */
async function initApiHost() {
  for (const candidate of CANDIDATE_HOSTS) {
    // 如果 env 覆盖了 baseHost，优先使用 env 指定的 host
    if (process.env.VUE_APP_API_HOST && process.env.VUE_APP_API_HOST !== '') {
      baseHost = process.env.VUE_APP_API_HOST
      break
    }

    // 探测候选主机
    // 如果候选是线上最后一个，也允许作为兜底
    const ok = await probeHost(candidate)
    if (ok) {
      baseHost = candidate
      break
    }
  }

  // 如果都不可用，保持原 baseHost（由 env 或 DEFAULT_HOST 提供）
  const finalBase = baseHost
  http.defaults.baseURL = `${finalBase}${apiPrefix}`
  return finalBase
}

export { http, baseHost, initApiHost }

export default {
  http,
  baseHost,
  initApiHost,
  CANDIDATE_HOSTS,
  apiPrefix
}