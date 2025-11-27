<template>
  <div class="avg-temp-line">
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
  name: 'AverageTemperatureLine',
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
        return `${this.currentParams.district}温度趋势`
      } else if (this.currentParams.city) {
        return `${this.currentParams.city}温度趋势`
      }
      return '大湾区温度趋势'
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
        console.log('[AverageTemperatureLine] 获取数据:', params)
        const response = await http.get('temperature/trend/recent-five-years', { params })
        
        if (response.data) {
          this.chartData = response.data
          console.log('[AverageTemperatureLine] 数据加载成功:', response.data)
          // 数据加载成功后立即渲染
          this.$nextTick(() => {
            this.render()
          })
        } else {
          throw new Error('数据格式错误')
        }
      } catch (err) {
        console.error('[AverageTemperatureLine] 获取数据失败:', err)
        this.error = '数据加载失败'
      } finally {
        this.loading = false
      }
    },
    
    handleMapIdentify(properties) {
      console.log('[AverageTemperatureLine] 收到地图点击事件:', properties)
      
      if (!properties) return
      
      let params = {}
      
      // 优先使用 DistrictCN（区县级）
      if (properties.DistrictCN) {
        params = {
          district: properties.DistrictCN,
          type: '区县级'
        }
        console.log('[AverageTemperatureLine] 区县级:', properties.DistrictCN)
      }
      // 其次使用 CityCN（市级）
      else if (properties.CityCN) {
        params = {
          city: properties.CityCN,
          type: '市级'
        }
        console.log('[AverageTemperatureLine] 市级:', properties.CityCN)
      }
      // 否则返回，不更新
      else {
        console.log('[AverageTemperatureLine] 未找到 CityCN 或 DistrictCN 字段')
        return
      }
      
      this.fetchData(params)
    },
    
    handleModeSwitch() {
      // 切换模式时，重置为大湾区数据
      console.log('[AverageTemperatureLine] 模式切换，重置为大湾区')
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
        console.log('[AverageTemperatureLine] render: 无数据')
        return
      }
      
      // 确保图表已初始化
      if (!this.chart) {
        const el = this.$refs.chart
        if (el) {
          this.chart = echarts.init(el)
          console.log('[AverageTemperatureLine] render: 初始化图表实例')
        } else {
          console.log('[AverageTemperatureLine] render: 图表容器不存在')
          return
        }
      }
      
      const { startYear, endYear, temperatures } = this.chartData
      console.log('[AverageTemperatureLine] render: 渲染图表', { startYear, endYear, temperatures })
      // 计算 y 轴最小值和最大值，并添加约 5% 的 padding
      let yMin = 0
      let yMax = 0
      let yInterval = null
      try {
        if (Array.isArray(temperatures) && temperatures.length > 0) {
          const nums = temperatures.map(v => Number(v)).filter(v => Number.isFinite(v))
          if (nums.length > 0) {
            yMin = Math.min(...nums)
            yMax = Math.max(...nums)
            if (yMax === yMin) {
              if (yMax === 0) {
                yMin = 0
                yMax = 1
              } else {
                const pad = Math.abs(yMax) * 0.05
                yMin = yMin - pad
                yMax = yMax + pad
              }
            } else {
              const pad = (yMax - yMin) * 0.05
              yMin = yMin - pad
              yMax = yMax + pad
            }

            // 如果范围过小，设置步长为 0.1
            if ((yMax - yMin) < 1) {
              yInterval = 0.1
            }
          }
        }
      } catch (e) {
        console.warn('[AverageTemperatureLine] 计算 y 轴范围失败', e)
      }
      
      // 生成年份数组
      const years = []
      for (let year = startYear; year <= endYear; year++) {
        years.push(year.toString())
      }

      const option = {
        backgroundColor: 'transparent',
        // 增加右侧和底部安全边距，避免最后一个 x 轴标签或点被裁切
        grid: { 
          left: '2%', 
          right: '6%', 
          bottom: '8%', 
          top: '18%', 
          containLabel: true 
        },
        tooltip: {
          trigger: 'axis',
          axisPointer: { 
            type: 'line',
            lineStyle: {
              color: 'rgba(75, 166, 240, 0.5)',
              type: 'dashed'
            }
          },
          backgroundColor: 'rgba(13, 26, 60, 0.9)',
          borderColor: '#4ba6f0',
          borderWidth: 1,
          textStyle: { color: '#fff' },
          formatter: (params) => {
            const p = params && params[0]
            if (!p) return ''
            return `<div style="font-weight:bold;color:#4ba6f0;margin-bottom:4px;">${p.name}年</div>平均温度：<span style="color:#fff;font-weight:bold;">${p.value.toFixed(1)}</span> °C`
          }
        },
        xAxis: {
          type: 'category',
          data: years,
          boundaryGap: false,
          axisLine: { 
            lineStyle: { color: 'rgba(75, 166, 240, 0.3)' } 
          },
          axisLabel: { 
            color: '#aaddff',
            fontSize: 12,
            margin: 14
          },
          axisTick: { show: false }
        },
        yAxis: {
          type: 'value',
          name: '°C',
          min: yMin,
          max: yMax,
          interval: yInterval,
          nameTextStyle: { 
            color: '#aaddff', 
            fontSize: 12,
            align: 'right',
            padding: [0, 10, 0, 0]
          },
          axisLine: { show: false },
          axisLabel: {
            color: '#aaddff',
            formatter: (value) => {
              // 保留一位小数
              if (Number.isFinite(value)) return Number(value).toFixed(1)
              return value
            }
          },
          splitLine: { 
            lineStyle: { 
              color: 'rgba(75, 166, 240, 0.1)',
              type: 'dashed'
            } 
          }
        },
        series: [{
          name: '平均温度',
          type: 'line',
          smooth: true,
          data: temperatures,
          showSymbol: true,
          symbol: 'circle',
          symbolSize: 8,
          itemStyle: {
            color: '#00f2ff',
            borderColor: '#fff',
            borderWidth: 1
          },
          lineStyle: {
            width: 3,
            color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
              { offset: 0, color: 'rgba(0, 242, 255, 0.5)' },
              { offset: 1, color: '#00f2ff' }
            ]),
            shadowColor: 'rgba(0, 242, 255, 0.5)',
            shadowBlur: 10
          },
          areaStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(0, 242, 255, 0.3)' },
              { offset: 1, color: 'rgba(0, 242, 255, 0.02)' }
            ])
          },
          animationDelay: (idx) => idx * 80
        }]
      }

      this.chart.setOption(option, true)
    }
  }
}
</script>

<style scoped>
.avg-temp-line {
   width: 100%;
   height: 100%;
   position: relative;
   padding-top: 38px;
   box-sizing: border-box;
   margin: 0 auto;
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


