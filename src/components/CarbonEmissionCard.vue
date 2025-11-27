<template>
  <div v-if="visible" class="carbon-modal">
    <div class="modal-backdrop" @click="close"></div>
    <div class="carbon-card">
      <div class="card-header">
        <div class="title-group">
          <span class="chip">碳排放报告</span>
          <h3 class="card-title">黄鲁山监测点</h3>
          <p class="card-subtitle">113.5721821°E · 22.7860305°N</p>
        </div>
        <button class="close-btn" @click="close">×</button>
      </div>
      <div class="card-body">
        <div class="photo-wrapper">
          <img :src="photo" alt="黄鲁山森林公园照片" />
          <span class="photo-tag">实地照片</span>
        </div>

        <div class="metrics">
          <div class="metric">
            <span class="metric-label">温度</span>
            <span class="metric-value">28.1°C</span>
          </div>
          <div class="metric">
            <span class="metric-label">RH</span>
            <span class="metric-value">88.0%</span>
          </div>
          <div class="metric">
            <span class="metric-label">DP</span>
            <span class="metric-value">26.0°C</span>
          </div>
        </div>


        <div class="report-block">
          <div class="report-title">碳排放洞察</div>
          <p class="report-content">
            从南沙前往黄鲁山森林公园的出行活动会产生一定的交通碳排放。若选择私家车或网约车，排放量主要来自车辆燃油燃烧过程，平均每公里约排放 0.15–0.20 kg CO₂，当行程约 35–45 公里时，总排放可达到 5–9 kg CO₂。若采用公共交通，如地铁接驳加公交，单位出行的碳排放可降低约 60%–80%，整体排放量通常不足 2 kg CO₂。
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import * as echarts from 'echarts'
import { http } from '@/api/api'
import bus from '@/bus'
import photo from '@/assets/Huanglushan.jpg'

const DEFAULT_SCOPE = {
  label: '大湾区',
  type: '大湾区',
  params: { type: '大湾区' }
}

export default {
  name: 'CarbonEmissionCard',
  data() {
    return {
      visible: false,
      photo,
      chart: null,
      chartData: { years: [], values: [] },
      loading: false,
      currentScopeLabel: DEFAULT_SCOPE.label,
      currentScopeType: DEFAULT_SCOPE.type
    }
  },
  computed: {
    hasTrendData() {
      return Array.isArray(this.chartData?.years) && this.chartData.years.length > 0
    }
  },
  mounted() {
    this.fetchTrend(DEFAULT_SCOPE.params)
    bus.$on('map:identify', this.onMapIdentify)
    bus.$on('mode:switch', this.onModeSwitch)
    window.addEventListener('resize', this.handleResize)
  },
  beforeDestroy() {
    bus.$off('map:identify', this.onMapIdentify)
    bus.$off('mode:switch', this.onModeSwitch)
    window.removeEventListener('resize', this.handleResize)
    if (this.chart) {
      this.chart.dispose()
      this.chart = null
    }
  },
  methods: {
    show() {
      this.visible = true
      this.$nextTick(() => {
        this.ensureChartInstance()
        this.renderChart()
      })
    },
    close() {
      this.visible = false
    },
    handleResize() {
      if (this.chart) {
        this.chart.resize()
      }
    },
    ensureChartInstance() {
      if (!this.$refs.trendChart || this.chart) return
      this.chart = echarts.init(this.$refs.trendChart)
    },
    async fetchTrend(params = DEFAULT_SCOPE.params) {
      this.loading = true
      try {
        const res = await http.get('carbon/trend/recent-five-years', { params })
        const payload = res?.data || {}
        this.chartData = this.transformResponse(payload)
        this.$nextTick(() => this.renderChart())
      } catch (err) {
        console.error('[CarbonEmissionCard] 获取碳排放趋势失败:', err)
        this.chartData = { years: [], values: [] }
        this.$nextTick(() => this.renderChart())
      } finally {
        this.loading = false
      }
    },
    transformResponse(data = {}) {
      const startYear = Number(data.startYear)
      const emissions = Array.isArray(data.carbonEmissions) ? data.carbonEmissions : []
      if (!Number.isFinite(startYear) || !emissions.length) {
        return { years: [], values: [] }
      }
      const years = emissions.map((_, idx) => `${startYear + idx}`)
      const values = emissions.map(val => Number(val) || 0)
      return { years, values }
    },
    renderChart() {
      this.ensureChartInstance()
      if (!this.chart) return
      const { years = [], values = [] } = this.chartData || {}
      const option = {
        backgroundColor: 'transparent',
        grid: {
          left: 40,
          right: 18,
          top: 30,
          bottom: 30
        },
        tooltip: {
          trigger: 'axis',
          backgroundColor: 'rgba(2,13,33,0.9)',
          borderColor: '#4dd9ff',
          textStyle: { color: '#fff' },
          formatter: params => {
            if (!params || !params.length) return ''
            const item = params[0]
            return `${item.axisValue} 年<br/>碳排放: <span style="color:#4dd9ff;font-weight:bold;">${Number(item.value).toLocaleString()} 吨</span>`
          }
        },
        xAxis: {
          type: 'category',
          data: years,
          boundaryGap: false,
          axisLine: { lineStyle: { color: 'rgba(77, 217, 255, 0.5)' } },
          axisLabel: { color: '#9bdcff', fontSize: 11 }
        },
        yAxis: {
          type: 'value',
          axisLine: { show: false },
          axisTick: { show: false },
          splitLine: { lineStyle: { color: 'rgba(77, 217, 255, 0.15)', type: 'dashed' } },
          axisLabel: {
            color: '#9bdcff',
            formatter: val => (val >= 1000 ? `${(val / 1000).toFixed(1)}k` : val)
          }
        },
        series: [
          {
            type: 'line',
            data: values,
            smooth: true,
            showSymbol: false,
            lineStyle: {
              width: 3,
              color: '#4dd9ff'
            },
            areaStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: 'rgba(77, 217, 255, 0.35)' },
                { offset: 1, color: 'rgba(77, 217, 255, 0.05)' }
              ])
            }
          }
        ]
      }
      this.chart.setOption(option, true)
      if (this.visible) {
        this.chart.resize()
      }
    },
    onModeSwitch() {
      this.applyScope(DEFAULT_SCOPE)
    },
    onMapIdentify(properties) {
      if (!properties || typeof properties !== 'object') {
        this.applyScope(DEFAULT_SCOPE)
        return
      }
      const district = this.pickFirstAvailable(properties, ['DistrictCN', 'district', 'District'])
      if (district) {
        this.applyScope({
          label: district,
          type: '区县级',
          params: { type: '区县级', district }
        })
        return
      }
      const city = this.pickFirstAvailable(properties, ['CityCN', 'city', 'City', '名称_nam', 'NAME'])
      if (city) {
        this.applyScope({
          label: city,
          type: '市级',
          params: { type: '市级', city }
        })
        return
      }
      this.applyScope(DEFAULT_SCOPE)
    },
    applyScope(scope = DEFAULT_SCOPE) {
      this.currentScopeLabel = scope.label || DEFAULT_SCOPE.label
      this.currentScopeType = scope.type || DEFAULT_SCOPE.type
      this.fetchTrend(scope.params || DEFAULT_SCOPE.params)
    },
    pickFirstAvailable(source, keys = []) {
      const entries = Object.keys(source || {}).map(key => ({
        key,
        lower: key.toLowerCase()
      }))
      for (const candidate of keys) {
        const lower = candidate.toLowerCase()
        const match = entries.find(entry => entry.lower === lower)
        if (match && source[match.key]) {
          return source[match.key]
        }
        if (Object.prototype.hasOwnProperty.call(source, candidate) && source[candidate]) {
          return source[candidate]
        }
      }
      return null
    }
  }
}
</script>

<style scoped>
.carbon-modal {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 11000;
}

.modal-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(2, 6, 23, 0.8);
  backdrop-filter: blur(4px);
  animation: fadeBackdrop 0.2s ease;
}

@keyframes fadeBackdrop {
  from { opacity: 0; }
  to { opacity: 1; }
}

.carbon-card {
  position: relative;
  width: min(440px, 92vw);
  background: linear-gradient(160deg, rgba(7, 11, 25, 0.96), rgba(14, 40, 68, 0.96));
  border: 1px solid rgba(102, 221, 255, 0.35);
  border-radius: 20px;
  box-shadow: 0 26px 50px rgba(0, 0, 0, 0.55), inset 0 0 30px rgba(30, 144, 255, 0.15);
  overflow: hidden;
  backdrop-filter: blur(6px);
  animation: popIn 0.25s ease;
}

@keyframes popIn {
  from { transform: translateY(24px) scale(0.95); opacity: 0; }
  to { transform: translateY(0) scale(1); opacity: 1; }
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 18px 20px 14px;
  border-bottom: 1px solid rgba(102, 221, 255, 0.2);
  background: radial-gradient(circle at 10% 10%, rgba(0, 255, 214, 0.08), transparent 60%);
}

.title-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 999px;
  border: 1px solid rgba(102, 221, 255, 0.5);
  font-size: 11px;
  letter-spacing: 0.08em;
  color: #9ad7ff;
  text-transform: uppercase;
}

.card-title {
  margin: 0;
  font-size: 20px;
  color: #e0f2ff;
  font-weight: 600;
}

.card-subtitle {
  margin: 0;
  font-size: 12px;
  color: #7db9ff;
  letter-spacing: 0.04em;
}

.close-btn {
  background: rgba(255, 255, 255, 0.05);
  border: none;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  color: #9ad7ff;
  font-size: 20px;
  cursor: pointer;
  transition: all 0.25s ease;
}

.close-btn:hover {
  background: rgba(255, 255, 255, 0.15);
  color: #ffffff;
  transform: rotate(90deg);
}

.card-body {
  padding: 18px 20px 22px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.photo-wrapper {
  position: relative;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid rgba(148, 197, 255, 0.4);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.35);
}

.photo-wrapper img {
  width: 100%;
  height: 180px;
  object-fit: cover;
  display: block;
  filter: saturate(1.1);
}

.photo-tag {
  position: absolute;
  bottom: 12px;
  right: 12px;
  padding: 4px 10px;
  font-size: 11px;
  letter-spacing: 0.08em;
  color: #0f172a;
  background: rgba(255, 255, 255, 0.85);
  border-radius: 999px;
  text-transform: uppercase;
}

.metrics {
  display: flex;
  justify-content: space-between;
  gap: 10px;
}

.metric {
  flex: 1;
  background: rgba(35, 66, 97, 0.8);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 12px;
  padding: 10px 12px;
  text-align: center;
  box-shadow: inset 0 0 20px rgba(20, 70, 120, 0.35);
}

.metric-label {
  display: block;
  font-size: 12px;
  color: #94bff5;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.metric-value {
  margin-top: 6px;
  font-size: 18px;
  font-weight: 600;
  color: #e0f2ff;
}

.trend-block {
  border: 1px solid rgba(77, 217, 255, 0.2);
  border-radius: 14px;
  padding: 14px 14px 10px;
  background: rgba(6, 18, 40, 0.7);
  box-shadow: inset 0 0 20px rgba(32, 102, 148, 0.35);
  position: relative;
}

.trend-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.trend-text {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.trend-chip {
  font-size: 12px;
  color: #4dd9ff;
  letter-spacing: 0.08em;
}

.trend-subtitle {
  margin: 0;
  font-size: 12px;
  color: #9ad7ff;
  letter-spacing: 0.04em;
}

.trend-loading {
  font-size: 12px;
  color: #8fe4ff;
  animation: blink 1.2s ease infinite;
}

@keyframes blink {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 1; }
}

.trend-chart {
  width: 100%;
  height: 180px;
}

.trend-empty {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #5a7da0;
  font-size: 13px;
  pointer-events: none;
}

.report-block {
  background: rgba(10, 20, 40, 0.8);
  border-radius: 14px;
  border: 1px solid rgba(102, 221, 255, 0.18);
  padding: 14px 16px;
  line-height: 1.6;
  box-shadow: inset 0 0 16px rgba(20, 80, 130, 0.2);
}

.report-title {
  font-size: 13px;
  color: #8dd7ff;
  letter-spacing: 0.12em;
  margin-bottom: 8px;
}

.report-content {
  margin: 0;
  font-size: 13px;
  color: #cfe5ff;
  text-align: justify;
}
</style>