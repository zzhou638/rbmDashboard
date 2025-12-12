import Vue from 'vue'
import App from './App.vue'
import router from './router'
import VueiClient from '@supermap/vue-iclient-mapboxgl';
import { initApiHost } from '@/api/api'

Vue.use(VueiClient);
Vue.config.productionTip = false

// 在启动 Vue 应用前初始化 API 主机（按优先级探测 localhost -> 局域网 -> 线上）
initApiHost().then((selected) => {
  console.log('[initApiHost] selected base host:', selected)

  new Vue({
    router,
    render: h => h(App),
  }).$mount('#app')
}).catch((err) => {
  console.warn('[initApiHost] error, continue with defaults', err)
  new Vue({
    router,
    render: h => h(App),
  }).$mount('#app')
}
)
