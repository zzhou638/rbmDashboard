const { defineConfig } = require('@vue/cli-service')

const API_TARGET = process.env.VUE_APP_API_TARGET || 'http://localhost:8085'

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    proxy: {
      '/api': {
        target: API_TARGET,
        changeOrigin: true,
        secure: false
      }
    }
  }
})
