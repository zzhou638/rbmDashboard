<template>
  <div class="green-finance-trend">
    <span class="card_title">总投资趋势</span>
    <div class="trend-chart" ref="chart"></div>
  </div>
</template>

<script>
import * as echarts from 'echarts'
import bus from '@/bus'
import { http } from '@/api/api'

export default {
  name: 'GreenFinanceInvestimentTrend',
  props: {
    // 期望的输入格式：[{ name: '2018', value: 145098 }, ...]
    trend: { type: Array, default: () => [] },
    // 组件外层期望的最小高度（可被外部容器覆盖）
    minHeight: { type: [Number, String], default: 220 }
  },
  data () {
    return {
      chart: null,
      trendData: [],
      filterParams: {}
    }
  },
  mounted () {
    this.init()
    this.fetchTrendData()
    bus.$on('overview:investmentFilter', this.onFilterChange)
    window.addEventListener('resize', this.resize)
  },
  beforeDestroy () {
    this.chart && this.chart.dispose()
    bus.$off('overview:investmentFilter', this.onFilterChange)
    window.removeEventListener('resize', this.resize)
  },
  watch: {
    trend: { deep: true, handler () { this.render() } }
  },
  methods: {
    init () {
      this.chart = echarts.init(this.$refs.chart)
      this.render()
    },
    resize () { if (this.chart) this.chart.resize() },
    onFilterChange (filters) {
      if (!filters || typeof filters !== 'object') {
        this.filterParams = {}
      } else {
        const { city, district } = filters
        this.filterParams = {
          ...(city ? { city } : {}),
          ...(district ? { district } : {})
        }
      }
      this.fetchTrendData()
    },
    fetchTrendData (params) {
      const query = params || this.filterParams || {}
      http.get('green-investment/trend', { params: query })
        .then(res => {
          const payload = res?.data || {}
          this.trendData = this.transformResponse(payload)
          this.render()
        })
        .catch(err => {
          console.warn('[GreenFinanceTrend] 获取趋势数据失败:', err)
          this.trendData = []
          this.render()
        })
    },
    transformResponse (data = {}) {
      const startYear = Number(data.startYear) || 0
      const investSum = Array.isArray(data.investSum) ? data.investSum : []
      if (!startYear || !investSum.length) return []
      return investSum.map((val, idx) => ({
        name: `${startYear + idx}`,
        value: Number(val) / 1e8 // 转为亿元
      }))
    },
    getDataset () {
      if (this.trendData.length) return this.trendData
      return (this.trend || []).map(item => ({
        name: item && item.name ? item.name : '',
        value: item && item.value != null ? Number(item.value) : 0
      }))
    },
    render () {
      if (!this.chart) return
      const dataset = this.getDataset()
      const x = dataset.map(d => d && (d.name + ''))
      const y = dataset.map(d => d && Number(d.value))
      // 计算 y 的最大值，用于决定格式化规则（小于 5 亿元时保留一位小数）
      const validYs = y.filter(v => Number.isFinite(v))
      const maxY = validYs.length ? Math.max(...validYs) : 0
      const useOneDecimal = maxY < 5
      const techBlue = '#1e90ff'

      const option = {
        backgroundColor: 'transparent',
        tooltip: {
          trigger: 'axis',
          axisPointer: { type: 'line' },
          formatter: (params) => {
            const p = params && params[0]
            if (!p) return ''
            const raw = p.data
            const num = Number(raw)
            if (!Number.isFinite(num)) return `${p.axisValueLabel}<br/>投资额：`
            const display = useOneDecimal ? num.toFixed(1) : String(Math.round(num))
            return `${p.axisValueLabel}<br/>投资额：${display} 亿元`
          }
        },
        // 留出少量安全边距以防标签溢出
        grid: { left: 30, right: 30, top: 30, bottom: 15, containLabel: true },
        xAxis: {
          type: 'category',
          data: x,
          boundaryGap: false,
          axisLine: { lineStyle: { color: '#9AA4AE' } },
          axisLabel: { color: '#ffffff', margin: 2 },
          axisTick: { show: false }
        },
        yAxis: {
          type: 'value',
          name: '亿元',
          nameTextStyle: { color: '#ffffff', padding: [0, 0, 0, 0] },
          axisLine: { lineStyle: { color: '#9AA4AE' } },
          axisLabel: {
            color: '#ffffff',
            margin: 2,
            formatter: (value) => {
              const num = Number(value)
              if (!Number.isFinite(num) || num === 0) return ''
              return useOneDecimal ? Number(num).toFixed(1) : String(Math.round(num))
            }
          },
          splitLine: { lineStyle: { color: 'rgba(255,255,255,0.12)' } }
        },
        series: [
          {
            name: '绿色金融总投资额',
            type: 'line',
            smooth: true,
            symbol: 'circle',
            symbolSize: 6,
            showSymbol: true,
            lineStyle: { color: techBlue, width: 2 },
            itemStyle: { color: techBlue, borderColor: '#ffffff', borderWidth: 1 },
            areaStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: 'rgba(30, 144, 255, 0.35)' },
                { offset: 1, color: 'rgba(30, 144, 255, 0.05)' }
              ])
            },
            data: y
          }
        ]
      }

      this.chart.setOption(option, true)
      this.resize()
    }
  }
}
</script>

<style scoped>
.green-finance-trend { width: 100%; height: 100%; }
.green-finance-trend {
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
.trend-chart {
  width: 100%;
  height: calc(100% - 38px);
  min-height: clamp(160px, 26vh, 280px);
}
</style>

