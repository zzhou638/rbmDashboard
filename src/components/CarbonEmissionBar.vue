<template>
  <div class="carbon-emission-bar">
    <span class="card_title">{{ titleText }}</span>
    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else ref="chart" class="chart"></div>
  </div>
</template>

<script>
import echarts from 'echarts'
import { http } from '@/api/api'
import bus from '@/bus'

export default {
  name: 'CarbonEmissionBar',
  data() {
    return {
      chart: null,
      loading: false,
      error: null,
      chartData: null,
      currentParams: { type: '大湾区', city: '粤港澳大湾区' }
    }
  },
  computed: {
    titleText() {
      if (this.currentParams.district) {
        return `${this.currentParams.district}碳排放趋势`
      } else if (this.currentParams.city) {
        return `${this.currentParams.city}碳排放趋势`
      }
      return '大湾区碳排放趋势'
    }
  },
  mounted() {
    this.$nextTick(() => {
      window.addEventListener('resize', this.onResize, { passive: true })
      // 先初始化图表容器
      const el = this.$refs.chart
      if (el) {
        this.chart = echarts.init(el)
      }
    })
    
    // 初始化加载大湾区数据
    this.fetchData({ type: '大湾区', city: '粤港澳大湾区' })
    
    // 监听地图点击事件
    bus.$on('map:identify', this.handleMapIdentify)
    // 监听模式切换事件
    bus.$on('mode:switch', this.handleModeSwitch)
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.onResize)
    bus.$off('map:identify', this.handleMapIdentify)
    bus.$off('mode:switch', this.handleModeSwitch)
    if (this.chart) {
      try { this.chart.dispose() } catch (e) { /* ignore */ }
      this.chart = null
    }
  },
  watch: {
    chartData: {
      deep: true,
      handler() { this.render() }
    }
  },
  methods: {
    async fetchData(params) {
      this.loading = true
      this.error = null
      this.currentParams = params
      
      try {
        console.log('[CarbonEmissionBar] 获取数据:', params)
        const response = await http.get('carbon/trend/recent-five-years', { params })
        
        if (response.data) {
          this.chartData = response.data
          console.log('[CarbonEmissionBar] 数据加载成功:', response.data)
          // 数据加载成功后立即渲染
          this.$nextTick(() => {
            this.render()
          })
        } else {
          throw new Error('数据格式错误')
        }
      } catch (err) {
        console.error('[CarbonEmissionBar] 获取数据失败:', err)
        this.error = '数据加载失败'
      } finally {
        this.loading = false
      }
    },
    
    handleMapIdentify(properties) {
      console.log('[CarbonEmissionBar] 收到地图点击事件:', properties)
      
      if (!properties) return
      
      let params = {}
      
      // 优先使用 DistrictCN（区县级）
      if (properties.DistrictCN) {
        params = {
          district: properties.DistrictCN,
          type: '区县级'
        }
        console.log('[CarbonEmissionBar] 区县级:', properties.DistrictCN)
      }
      // 其次使用 CityCN（市级）
      else if (properties.CityCN) {
        params = {
          city: properties.CityCN,
          type: '市级'
        }
        console.log('[CarbonEmissionBar] 市级:', properties.CityCN)
      }
      // 否则返回，不更新
      else {
        console.log('[CarbonEmissionBar] 未找到 CityCN 或 DistrictCN 字段')
        return
      }
      
      this.fetchData(params)
    },
    
    handleModeSwitch() {
      // 切换模式时，重置为大湾区数据
      console.log('[CarbonEmissionBar] 模式切换，重置为大湾区')
      this.fetchData({ type: '大湾区', city: '粤港澳大湾区' })
    },
    
    onResize() {
      if (this.chart) {
        try { this.chart.resize() } catch (e) { /* ignore */ }
      }
    },
    
    initChart() {
      const el = this.$refs.chart
      if (!el) return
      if (!this.chart) {
        this.chart = echarts.init(el)
      }
      if (this.chartData) {
        this.render()
      }
    },
    
    render() {
      if (!this.chartData) {
        console.log('[CarbonEmissionBar] render: 无数据')
        return
      }
      
      // 确保图表已初始化
      if (!this.chart) {
        const el = this.$refs.chart
        if (el) {
          this.chart = echarts.init(el)
          console.log('[CarbonEmissionBar] render: 初始化图表实例')
        } else {
          console.log('[CarbonEmissionBar] render: 图表容器不存在')
          return
        }
      }
      
      const { startYear, endYear, carbonEmissions } = this.chartData
      console.log('[CarbonEmissionBar] render: 渲染图表', { startYear, endYear, carbonEmissions })
      
      // 生成年份数组
      const years = []
      for (let year = startYear; year <= endYear; year++) {
        years.push(year.toString())
      }

      const option = {
        backgroundColor: 'transparent',
        grid: { 
          left: '2%', 
          right: '2%', 
          bottom: '5%', 
          top: '18%', 
          containLabel: true 
        },
        tooltip: {
          trigger: 'axis',
          axisPointer: { 
            type: 'shadow',
            shadowStyle: {
              color: 'rgba(75, 166, 240, 0.1)'
            }
          },
          backgroundColor: 'rgba(13, 26, 60, 0.9)',
          borderColor: '#4ba6f0',
          borderWidth: 1,
          textStyle: { color: '#fff' },
          formatter: (params) => {
            const p = params && params[0]
            if (!p) return ''
            return `<div style="font-weight:bold;color:#4ba6f0;margin-bottom:4px;">${p.name}年</div>碳排放量：<span style="color:#fff;font-weight:bold;">${p.value.toFixed(1)}</span> 万吨`
          }
        },
        xAxis: {
          type: 'category',
          data: years,
          axisLine: { 
            lineStyle: { color: 'rgba(75, 166, 240, 0.3)' } 
          },
          axisLabel: { 
            color: '#aaddff',
            fontSize: 12,
            margin: 12
          },
          axisTick: { show: false }
        },
        yAxis: {
          type: 'value',
          name: '万吨',
          nameTextStyle: { 
            color: '#aaddff', 
            fontSize: 12,
            align: 'right',
            padding: [0, 10, 0, 0]
          },
          axisLine: { show: false },
          axisLabel: { color: '#aaddff' },
          splitLine: { 
            lineStyle: { 
              color: 'rgba(75, 166, 240, 0.1)',
              type: 'dashed'
            } 
          }
        },
        series: [{
          name: '碳排放量',
          type: 'bar',
          data: carbonEmissions,
          barMaxWidth: 24,
          itemStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: '#00f2ff' },
              { offset: 1, color: 'rgba(0, 102, 255, 0.6)' }
            ]),
            borderRadius: [2, 2, 0, 0]
          },
          showBackground: true,
          backgroundStyle: {
            color: 'rgba(255, 255, 255, 0.05)',
            borderRadius: [2, 2, 0, 0]
          },
          animationDelay: (idx) => idx * 100
        }]
      }

      this.chart.setOption(option, true)
    }
  }
}
</script>

<style scoped>
.carbon-emission-bar {
  width: 100%;
  height: 100%;
  position: relative;
  padding-top: 38px;
  box-sizing: border-box;
}

.card_title {
  position: absolute;
  top: 0px;
  left: 0px;
  font-size: 22px;
  font-weight: 700;
  color: #66ddff;
  letter-spacing: 0.08em;
  text-shadow: 0 0 8px rgba(0, 170, 255, 0.55);
  z-index: 5;
}

.loading, .error {
  width: 100%;
  height: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  color: #4ba6f0;
  font-size: 14px;
}

.chart {
  width: 100%;
  height: 100%;
}
</style>


