import axios from 'axios'

const DEFAULT_HOST = process.env.NODE_ENV === 'development'
  ? 'http://localhost:8085'
  : 'http://www.zhougis.top:8085'
const baseHost = process.env.VUE_APP_API_HOST || DEFAULT_HOST
const apiPrefix = '/api/'
const remote_api = `${baseHost}${apiPrefix}`

const http = axios.create({
  baseURL: remote_api,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json'
  }
})

export { http, baseHost }

export default {
  remote_api,
  http,
  baseHost
}