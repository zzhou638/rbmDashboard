<template>
  <div v-if="visible" class="carbon-modal">
    <div class="modal-backdrop" @click="close"></div>
    <div class="carbon-card">
      <div class="card-header">
        <div class="title-group">
          <span class="chip">碳排放实地考察报告</span>
          <h3 class="card-title">{{ samplingPointData?.number || '加载中...' }}</h3>
          <p class="card-subtitle" v-if="samplingPointData?.city">
            {{ samplingPointData.city }}
          </p>
          <p class="card-subtitle" v-if="samplingPointData?.swbType">
            类型: {{ samplingPointData.swbType }} · 面积: {{ samplingPointData.areaHa }} ha
          </p>
        </div>
        <button class="close-btn" @click="close">×</button>
      </div>
      <div class="card-body">
        <div v-if="loading" class="loading-indicator">
          <div class="loading-spinner"></div>
          <p>加载中...</p>
        </div>
        <template v-else-if="samplingPointData">
          <!-- 基础水质参数 -->
          <div class="section-title">基础水质参数</div>
          <div class="metrics-grid">
            <div class="metric">
              <span class="metric-label">水温</span>
              <span class="metric-value">{{ formatValue(samplingPointData.twaterDegC, 2) }}°C</span>
            </div>
            <div class="metric">
              <span class="metric-label">pH</span>
              <span class="metric-value">{{ formatValue(samplingPointData.ph, 2) }}</span>
            </div>
            <div class="metric">
              <span class="metric-label">ORP</span>
              <span class="metric-value">{{ formatValue(samplingPointData.orp, 1) }} mV</span>
            </div>
            <div class="metric">
              <span class="metric-label">DO</span>
              <span class="metric-value">{{ formatValue(samplingPointData.doPpm, 2) }} mg/L</span>
            </div>
            <div class="metric">
              <span class="metric-label">电导率</span>
              <span class="metric-value">{{ formatValue(samplingPointData.conductivityUsCm, 0) }} μS/cm</span>
            </div>
            <div class="metric">
              <span class="metric-label">盐度</span>
              <span class="metric-value">{{ formatValue(samplingPointData.salinity, 2) }} ‰</span>
            </div>
          </div>

          <!-- 营养盐参数 -->
          <div class="section-title">营养盐浓度</div>
          <div class="metrics-grid">
            <div class="metric">
              <span class="metric-label">NO₃⁻</span>
              <span class="metric-value">{{ formatValue(samplingPointData.no3UmolL, 3) }} μmol/L</span>
            </div>
            <div class="metric">
              <span class="metric-label">NO₂⁻</span>
              <span class="metric-value">{{ formatValue(samplingPointData.no2UmolL, 3) }} μmol/L</span>
            </div>
            <div class="metric">
              <span class="metric-label">NH₄⁺</span>
              <span class="metric-value">{{ formatValue(samplingPointData.nh4UmolL, 3) }} μmol/L</span>
            </div>
            <div class="metric">
              <span class="metric-label">PO₄³⁻</span>
              <span class="metric-value">{{ formatValue(samplingPointData.po4UmolL, 3) }} μmol/L</span>
            </div>
            <div class="metric">
              <span class="metric-label">SiO₃²⁻</span>
              <span class="metric-value">{{ formatValue(samplingPointData.sio3UmolL, 2) }} μmol/L</span>
            </div>
            <div class="metric">
              <span class="metric-label">叶绿素a</span>
              <span class="metric-value">{{ formatValue(samplingPointData.chlAUgL, 2) }} μg/L</span>
            </div>
          </div>

          <!-- 温室气体通量 -->
          <div class="section-title">温室气体通量</div>
          <div class="metrics-grid">
            <div class="metric">
              <span class="metric-label">CO₂通量</span>
              <span class="metric-value">{{ formatValue(samplingPointData.fco2GCM2D, 3) }} g/m²/d</span>
            </div>
            <div class="metric">
              <span class="metric-label">CH₄通量</span>
              <span class="metric-value">{{ formatValue(samplingPointData.fch4MmolM2D, 4) }} mmol/m²/d</span>
            </div>
            <div class="metric">
              <span class="metric-label">N₂O通量</span>
              <span class="metric-value">{{ formatValue(samplingPointData.fn2oMmolM2D, 6) }} mmol/m²/d</span>
            </div>
          </div>

          <!-- 诊断信息 -->
          <div class="report-block" v-if="samplingPointData.diagnosis">
            <div class="report-title">诊断</div>
            <p class="report-content">{{ samplingPointData.diagnosis }}</p>
          </div>

          <!-- 评估信息 -->
          <div class="report-block" v-if="samplingPointData.evaluation">
            <div class="report-title">综合评估</div>
            <p class="report-content">{{ samplingPointData.evaluation }}</p>
          </div>

          <!-- 采样点照片 (移到最后) -->
          <div class="photo-wrapper" v-if="samplingPointData.imageBase64">
            <img :src="getImageSrc(samplingPointData.imageBase64)" :alt="samplingPointData.number + '实地照片'" />
            <span class="photo-tag">实地照片</span>
          </div>
        </template>
        <div v-else class="error-message">
          <p>暂无数据</p>
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
      currentScopeType: DEFAULT_SCOPE.type,
      samplingPointData: null, // 存储采样点详细数据
      samplingPointNumber: null // 存储当前采样点编号
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
    show(number) {
      this.visible = true
      this.samplingPointNumber = number
      
      // 如果传入了 number，从后端获取详细数据
      if (number) {
        this.fetchSamplingPointDetail(number)
      }
      
      this.$nextTick(() => {
        this.ensureChartInstance()
        this.renderChart()
      })
    },
    close() {
      this.visible = false
      // 关闭时清空数据
      this.samplingPointData = null
      this.samplingPointNumber = null
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
    },
    async fetchSamplingPointDetail(number) {
      this.loading = true
      try {
        console.log('[CarbonEmissionCard] 开始获取采样点数据, number:', number)
        const res = await http.get('map/sampling-point-detail', { params: { number } })
        this.samplingPointData = res.data
        console.log('[CarbonEmissionCard] 采样点数据加载成功:', res.data)
      } catch (err) {
        console.error('[CarbonEmissionCard] 获取采样点详细数据失败:', err)
        this.samplingPointData = null
      } finally {
        this.loading = false
      }
    },
    formatValue(value, decimals = 2) {
      if (value === null || value === undefined || value === '') {
        return '--'
      }
      const num = Number(value)
      if (isNaN(num)) {
        return '--'
      }
      return num.toFixed(decimals)
    },
    getImageSrc(imageData) {
      if (!imageData) return ''
      // 如果已经是完整的 data URI，直接返回
      if (imageData.startsWith('data:image')) {
        return imageData
      }
      // 如果是纯 base64 数据，添加 data URI 前缀
      // 默认假设是 JPEG 格式，也可以根据实际情况调整
      return `data:image/jpeg;base64,${imageData}`
    }
  }
}
</script>

<style scoped>
.carbon-modal {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding-top: 12vh;
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
  width: min(600px, 92vw);
  max-height: 80vh;
  overflow-y: auto;
  background: linear-gradient(160deg, rgba(7, 11, 25, 0.96), rgba(14, 40, 68, 0.96));
  border: 1px solid rgba(102, 221, 255, 0.35);
  border-radius: 20px;
  box-shadow: 0 26px 50px rgba(0, 0, 0, 0.55), inset 0 0 30px rgba(30, 144, 255, 0.15);
  backdrop-filter: blur(6px);
  animation: popIn 0.25s ease;
}

/* 自定义滚动条 */
.carbon-card::-webkit-scrollbar {
  width: 10px;
}

.carbon-card::-webkit-scrollbar-track {
  background: rgba(2, 6, 23, 0.7);
  border-radius: 5px;
  margin: 4px 0;
}

.carbon-card::-webkit-scrollbar-thumb {
  background: rgba(77, 217, 255, 0.5);
  border-radius: 5px;
  border: 2px solid rgba(7, 11, 25, 0.96);
}

.carbon-card::-webkit-scrollbar-thumb:hover {
  background: rgba(77, 217, 255, 0.7);
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
  align-items: center;
}

.chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 4px 12px;
  border-radius: 999px;
  border: 1px solid rgba(102, 221, 255, 0.5);
  font-size: 11px;
  letter-spacing: 0.08em;
  color: #9ad7ff;
  text-transform: uppercase;
  width: fit-content;
  max-width: 100%;
  align-self: center;
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
  height: auto;
  aspect-ratio: 4 / 3;
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

.section-title {
  font-size: 14px;
  font-weight: 600;
  color: #4dd9ff;
  letter-spacing: 0.08em;
  margin: 8px 0 12px 0;
  padding-bottom: 6px;
  border-bottom: 1px solid rgba(77, 217, 255, 0.2);
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 8px;
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

.loading-indicator {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  color: #9ad7ff;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(77, 217, 255, 0.2);
  border-top-color: #4dd9ff;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 12px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-indicator p {
  margin: 0;
  font-size: 14px;
  color: #8fe4ff;
}

.error-message {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  color: #7db9ff;
  text-align: center;
}

.error-message p {
  margin: 0;
  font-size: 14px;
}
</style>