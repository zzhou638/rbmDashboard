<template>
  <div class="esg-card">
    <div class="esg-header">
      <div class="header-main">
        <div class="title-block">
          <h3 class="card-title">ESG 区域评级</h3>
          <span class="region-tag">{{ currentRegionLabel }}</span>
        </div>
        <div class="meta-block">
          <span class="meta-item">样本: {{ companyCountText }}</span>
          <span v-if="loading" class="loading-pulse">Updating...</span>
        </div>
      </div>
    </div>

    <div class="content-body">
      <!-- Left: Total Score Circle -->
      <div class="chart-container">
        <div class="circle-wrapper">
          <svg viewBox="0 0 100 100" class="progress-svg">
            <!-- Background Circle -->
            <circle cx="50" cy="50" r="40" class="bg-ring" />
            <!-- Progress Circle -->
            <circle 
              cx="50" 
              cy="50" 
              r="40" 
              class="fg-ring" 
              :stroke-dasharray="totalDashArray"
              transform="rotate(-90 50 50)"
            />
          </svg>
          <div class="circle-content">
            <span class="total-num">{{ formatScore(scores.averageEsgTotalScore) }}</span>
            <span class="total-label">综合得分</span>
          </div>
        </div>
      </div>

      <!-- Right: Metrics List -->
      <div class="metrics-container">
        <div v-for="item in scoreMetrics" :key="item.key" class="metric-row">
          <div class="metric-info">
            <span class="metric-name" :style="{ color: item.color }">{{ item.key }} · {{ item.label }}</span>
            <span class="metric-val">{{ item.value }}</span>
          </div>
          <div class="metric-track">
            <div class="metric-bar" :style="{ width: item.percent + '%', backgroundColor: item.color }"></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { http } from '@/api/api'
import bus from '@/bus'

const DEFAULT_REGION = {
  label: '大湾区',
  type: '全部区域',
  params: {}
}

export default {
  name: 'EsgReportCard',
  props: {
    text: {
      type: String,
      default: ''
    }
  },
  data() {
    return {
      loading: false,
      scores: this.createEmptyScores(),
      currentRegionLabel: DEFAULT_REGION.label,
      currentRegionType: DEFAULT_REGION.type,
      lastQueryKey: this.buildQueryKey(DEFAULT_REGION.params)
    }
  },
  computed: {
    scoreMetrics() {
      return [
        {
          key: 'E',
          label: '环境',
          value: this.formatScore(this.scores.averageEScore),
          percent: this.calcPercent(this.scores.averageEScore),
          color: '#00e676'
        },
        {
          key: 'S',
          label: '社会',
          value: this.formatScore(this.scores.averageSScore),
          percent: this.calcPercent(this.scores.averageSScore),
          color: '#2979ff'
        },
        {
          key: 'G',
          label: '治理',
          value: this.formatScore(this.scores.averageGScore),
          percent: this.calcPercent(this.scores.averageGScore),
          color: '#ffab00'
        }
      ]
    },
    totalDashArray() {
      const r = 40
      const c = 2 * Math.PI * r
      const val = this.scores.averageEsgTotalScore || 0
      const percent = Math.max(0, Math.min(100, val))
      const dash = (percent / 100) * c
      return `${dash} ${c}`
    },
    companyCountText() {
      const count = Number(this.scores.companyCount)
      if (!Number.isFinite(count) || count <= 0) return '—'
      return count.toLocaleString()
    }
  },
  mounted() {
    this.fetchScores(DEFAULT_REGION.params)
    bus.$on('map:identify', this.onMapIdentify)
    bus.$on('mode:switch', this.onModeSwitch)
  },
  beforeDestroy() {
    bus.$off('map:identify', this.onMapIdentify)
    bus.$off('mode:switch', this.onModeSwitch)
  },
  methods: {
    createEmptyScores() {
      return {
        averageEScore: 0,
        averageSScore: 0,
        averageGScore: 0,
        averageEsgTotalScore: 0,
        companyCount: 0
      }
    },
    calcPercent(value) {
      const num = Number(value)
      if (!Number.isFinite(num)) return 0
      return Math.max(0, Math.min(100, Number(num.toFixed(1))))
    },
    formatScore(value) {
      const num = Number(value)
      if (!Number.isFinite(num)) return '--'
      return num.toFixed(2)
    },
    buildQueryKey(params = {}) {
      const city = params.city ? `city:${params.city}` : ''
      const district = params.district ? `district:${params.district}` : ''
      return [city, district].filter(Boolean).join('|') || 'all'
    },
    async fetchScores(params = {}) {
      const queryParams = {}
      if (params.city) queryParams.city = params.city
      if (params.district) queryParams.district = params.district
      const queryKey = this.buildQueryKey(queryParams)
      if (queryKey === this.lastQueryKey && this.scores.companyCount) return
      this.lastQueryKey = queryKey
      this.loading = true
      try {
        const res = await http.get('esg-cnrds/average-scores', { params: queryParams })
        const payload = res?.data || {}
        this.scores = {
          averageEScore: Number(payload.averageEScore) || 0,
          averageSScore: Number(payload.averageSScore) || 0,
          averageGScore: Number(payload.averageGScore) || 0,
          averageEsgTotalScore: Number(payload.averageEsgTotalScore) || 0,
          companyCount: Number(payload.companyCount) || 0
        }
      } catch (err) {
        console.error('[EsgReportCard] 获取 ESG 分数失败:', err)
        this.scores = this.createEmptyScores()
      } finally {
        this.loading = false
      }
    },
    onModeSwitch() {
      this.applyRegion(DEFAULT_REGION)
    },
    onMapIdentify(properties) {
      const descriptor = this.mapPropertiesToRegion(properties)
      this.applyRegion(descriptor)
    },
    applyRegion(descriptor = DEFAULT_REGION) {
      this.currentRegionLabel = descriptor.label || DEFAULT_REGION.label
      this.currentRegionType = descriptor.type || DEFAULT_REGION.type
      this.fetchScores(descriptor.params || DEFAULT_REGION.params)
    },
    mapPropertiesToRegion(properties) {
      if (!properties || typeof properties !== 'object') {
        return DEFAULT_REGION
      }
      const district = this.pickFirstAvailable(properties, ['DistrictCN', 'district', 'District'])
      if (district) {
        return {
          label: district,
          type: '区级',
          params: { district }
        }
      }
      const city = this.pickFirstAvailable(properties, ['CityCN', 'city', 'City', '名称_nam', 'NAME'])
      if (city) {
        return {
          label: city,
          type: '市级',
          params: { city }
        }
      }
      return DEFAULT_REGION
    },
    pickFirstAvailable(source, keys = []) {
      const normalized = Object.keys(source || {}).reduce((acc, key) => {
        acc[key.toLowerCase()] = key;
        return acc;
      }, {});
      for (const candidate of keys) {
        if (!candidate) continue;
        const lower = candidate.toLowerCase();
        const actualKey = normalized[lower] || candidate;
        const value = source[actualKey];
        if (value) return value;
      }
      return null;
    },
  },
};
</script>

<style scoped>
.esg-card {
  display: flex;
  flex-direction: column;
  height: calc(100% - 38px);
  padding: 0 12px;
  background: transparent;
  border: none;
  box-shadow: none;
  color: #fff;
  font-family: "Helvetica Neue", Helvetica, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", Arial, sans-serif;
}

.esg-header {
  margin-bottom: 0;
  padding-bottom: 10px;
  flex-shrink: 0;
}

.header-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title-block {
  display: flex;
  align-items: center;
  gap: 10px;
}

.card-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #e6f7ff;
  letter-spacing: 0.5px;
  text-shadow: 0 0 8px rgba(24, 144, 255, 0.4);
}

.region-tag {
  padding: 2px 8px;
  background: rgba(24, 144, 255, 0.15);
  border: 1px solid rgba(24, 144, 255, 0.3);
  border-radius: 4px;
  font-size: 11px;
  color: #69c0ff;
}

.meta-block {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 12px;
  color: #8c8c8c;
}

.loading-pulse {
  color: #1890ff;
  animation: pulse 1.5s infinite;
}

@keyframes pulse {
  0% { opacity: 0.5; }
  50% { opacity: 1; }
  100% { opacity: 0.5; }
}

.content-body {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  padding-top: 0;
  margin-top: 20px; /* 向下移动 20px */
}

/* Circle Chart */
.chart-container {
  flex: 0 0 100px;
  display: flex;
  justify-content: center;
  align-items: center;
}

.circle-wrapper {
  position: relative;
  width: 100px;
  height: 100px;
}

.progress-svg {
  width: 100%;
  height: 100%;
  transform: rotate(0deg);
}

.bg-ring {
  fill: none;
  stroke: rgba(255, 255, 255, 0.1);
  stroke-width: 6;
}

.fg-ring {
  fill: none;
  stroke: #1890ff;
  stroke-width: 6;
  stroke-linecap: round;
  transition: stroke-dasharray 0.8s cubic-bezier(0.4, 0, 0.2, 1);
  filter: drop-shadow(0 0 6px rgba(24, 144, 255, 0.6));
}

.circle-content {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
}

.total-num {
  font-size: 26px;
  font-weight: 700;
  color: #fff;
  line-height: 1.1;
  text-shadow: 0 0 12px rgba(24, 144, 255, 0.8);
  font-family: "DIN Alternate", "Roboto Condensed", sans-serif;
}

.total-label {
  font-size: 11px;
  color: #a6a6a6;
  margin-top: 4px;
  letter-spacing: 1px;
}

/* Metrics List */
.metrics-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 14px;
}

.metric-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.metric-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 13px;
}

.metric-name {
  font-weight: 500;
  opacity: 0.9;
}

.metric-val {
  font-weight: 600;
  color: #fff;
  font-family: "DIN Alternate", "Roboto Condensed", sans-serif;
  letter-spacing: 0.5px;
}

.metric-track {
  height: 4px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 2px;
  overflow: hidden;
}

.metric-bar {
  height: 100%;
  border-radius: 2px;
  transition: width 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: 0 0 8px currentColor;
}
</style>

