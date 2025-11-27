import Vue from 'vue'

// 全局事件总线，用于组件间通信（Vue 2）
// 使用方式：
// 发送：bus.$emit('overview:update', payload)
// 监听：bus.$on('overview:update', handler)
const bus = new Vue()

export default bus









