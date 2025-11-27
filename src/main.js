import Vue from 'vue'
import App from './App.vue'
import router from './router'
import VueiClient from '@supermap/vue-iclient-mapboxgl';
Vue.use(VueiClient);
Vue.config.productionTip = false

new Vue({
  router,
  render: h => h(App),
}).$mount('#app')
