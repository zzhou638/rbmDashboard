const { defineConfig } = require('@vue/cli-service')

const API_TARGET = process.env.VUE_APP_API_TARGET || 'http://localhost:8085'

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    // 禁用客户端错误覆盖层，避免干扰
    client: {
      overlay: {
        warnings: false,
        errors: false
      }
    },
    proxy: {
      '/api': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false,
        ws: true, // 支持 websocket
        // 增加代理超时时间，支持长时间的流式响应
        proxyTimeout: 1000 * 60 * 10, // 10 分钟
        timeout: 1000 * 60 * 10, // 10 分钟
        // 添加自定义处理器
        onProxyReq: (proxyReq, req, res) => {
          // 设置请求超时
          proxyReq.setTimeout(1000 * 60 * 10) // 10 分钟
        },
        onProxyRes: (proxyRes, req, res) => {
          // 设置响应超时
          proxyRes.setTimeout(1000 * 60 * 10) // 10 分钟
        }
      }
    }
  }
})
