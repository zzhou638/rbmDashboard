<template>
  <div class="overview-numbers">
    <div class="cards-grid">
      <div
        v-for="item in items"
        :key="item.key"
        class="card"
      >
        <div class="card__glow" :class="`corner-${item.position}`"></div>
        <div class="card__border"></div>
        <div class="card__content">
          <div class="card__label">{{ item.label }}</div>
          <div class="card__value">
            <span class="num">{{ item.value }}</span>
            <span class="unit">{{ item.unit }}</span>
          </div>
        </div>
        <div class="card__scanline"></div>
      </div>
    </div>
  </div>
  
</template>

<script>
import bus from '@/bus'
import { http } from '@/api/api'
export default {
  name: 'OverviewNumbers',
  data() {
    return {
      items: [
        { key: 'patent', label: '绿色专利', value: '20,560,123', unit: '件', position: 'lt' },
        { key: 'enterprise', label: '绿色企业', value: '20,560,123', unit: '家', position: 'rt' },
        { key: 'factory', label: '工厂数', value: '20,560,123', unit: '座', position: 'lb' },
        { key: 'investment', label: '总投资', value: '3639.4', unit: '亿元', position: 'rb' }
      ]
    }
  },
  mounted() {
    // 监听其它组件发送的更新事件
    bus.$on('overview:update', this.onOverviewUpdate)
    bus.$on('overview:investmentFilter', this.onInvestmentFilter)
    this.fetchInvestmentTotal()
    this.fetchPatentCount()
  },
  beforeDestroy() {
    bus.$off('overview:update', this.onOverviewUpdate)
    bus.$off('overview:investmentFilter', this.onInvestmentFilter)
  },
  methods: {
    fetchInvestmentTotal(params = {}) {
      http.get('green-investment/total', { params })
        .then(res => {
          const totalYuan = Number(res?.data?.total ?? res?.data ?? 0)
          this.updateInvestmentDisplay(totalYuan)
        })
        .catch(err => {
          console.warn('[overview] 获取总投资失败:', err)
          this.updateInvestmentDisplay(null)
        })
    },
    fetchPatentCount(params = {}) {
      http.get('green-patent/count', { params })
        .then(res => {
          const total = Number(res?.data?.totalCount ?? res?.data?.total ?? res?.data ?? 0)
          this.updatePatentDisplay(total)
        })
        .catch(err => {
          console.warn('[overview] 获取绿色专利失败:', err)
          this.updatePatentDisplay(null)
        })
    },
    updateItemValue(key, value) {
      this.items = this.items.map(it => {
        if (it.key === key) {
          return { ...it, value: this.formatNumber(value) }
        }
        return it
      })
    },
    onOverviewUpdate(payload) {
      if (!payload || typeof payload !== 'object') return
      // 支持两种格式：
      // 1) { patent: 123, enterprise: 456, factory: 789, investment: 1011 }
      // 2) { items: [{ key, value }, ...] }
      const map = Array.isArray(payload.items)
        ? payload.items.reduce((acc, it) => { if (it && it.key != null) acc[it.key] = it.value; return acc }, {})
        : payload

      this.items = this.items.map(it => {
        const next = { ...it }
        if (Object.prototype.hasOwnProperty.call(map, it.key)) {
          next.value = this.formatNumber(map[it.key])
        }
        return next
      })
    },
    onInvestmentFilter(filters) {
      if (!filters || typeof filters !== 'object') {
        this.fetchInvestmentTotal()
        this.fetchPatentCount()
        return
      }
      this.fetchInvestmentTotal(filters)
      this.fetchPatentCount(filters)
    },
    formatNumber(val) {
      const num = typeof val === 'number' ? val : Number(val)
      if (!isFinite(num)) return String(val ?? '')
      return num.toLocaleString('zh-CN', { maximumFractionDigits: 1 })
    },
    updateInvestmentDisplay(amountYuan) {
      let value = 'N/A'
      let unit = ''
      const num = typeof amountYuan === 'number' ? amountYuan : Number(amountYuan)
      if (isFinite(num) && num >= 0) {
        if (num >= 1e8) {
          value = num / 1e8
          unit = '亿元'
        } else {
          value = num / 1e4
          unit = '万元'
        }
      }
      this.items = this.items.map(item => {
        if (item.key === 'investment') {
          return {
            ...item,
            value: this.formatNumber(value),
            unit
          }
        }
        return item
      })
    },
    updatePatentDisplay(count) {
      let value = 'N/A'
      const num = typeof count === 'number' ? count : Number(count)
      if (isFinite(num) && num >= 0) {
        value = num
      }
      this.items = this.items.map(item => {
        if (item.key === 'patent') {
          return {
            ...item,
            value: this.formatNumber(value),
            unit: '件'
          }
        }
        return item
      })
    }
  }
}
</script>

<style scoped>
.overview-numbers {
  width: 100%;
  height: 100%;
  padding: 12px;
  box-sizing: border-box;
}

.cards-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  grid-auto-rows: 1fr;
  gap: 16px;
  height: 100%;
}

.card {
  position: relative;
  overflow: hidden;
  border-radius: 14px;
  background: radial-gradient(120% 120% at 0% 0%, rgba(0, 255, 214, 0.06) 0%, rgba(0, 117, 255, 0.06) 45%, rgba(0, 0, 0, 0.24) 100%),
              linear-gradient(180deg, rgba(15, 21, 40, 0.9), rgba(10, 14, 26, 0.9));
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.35), inset 0 0 24px rgba(0, 200, 255, 0.06);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  transition: transform 0.35s ease, box-shadow 0.35s ease;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 14px 38px rgba(0, 0, 0, 0.45), inset 0 0 28px rgba(0, 200, 255, 0.12);
}

.card__border {
  position: absolute;
  inset: 0;
  border-radius: 14px;
  padding: 1px;
  background: linear-gradient(135deg, rgba(0, 255, 214, 0.45), rgba(0, 117, 255, 0.45), rgba(177, 0, 255, 0.45));
  -webkit-mask: 
    linear-gradient(#000 0 0) content-box, 
    linear-gradient(#000 0 0);
  mask: 
    linear-gradient(#000 0 0) content-box,
    linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
          mask-composite: exclude;
  pointer-events: none;
}

.card__content {
  position: relative;
  z-index: 2;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 18px 14px;
  text-align: center;
}

.card__label {
  font-size: 14px;
  letter-spacing: 0.12em;
  color: #8fb7ff;
  text-transform: uppercase;
  text-shadow: 0 0 10px rgba(0, 174, 255, 0.35);
}

.card__value {
  margin-top: 8px;
}

.card__value .num {
  font-weight: 700;
  font-size: 24px;
  line-height: 1.1;
  background: linear-gradient(180deg, #e7f5ff 0%, #9cd4ff 60%, #5ac8ff 100%);
  -webkit-background-clip: text;
          background-clip: text;
  color: transparent;
  text-shadow: 0 0 18px rgba(22, 170, 255, 0.35);
}

.card__value .unit {
  margin-left: 6px;
  font-size: 14px;
  color: #9ad7ff;
  opacity: 0.9;
}

.card__glow {
  position: absolute;
  width: 140px;
  height: 140px;
  filter: blur(28px);
  background: radial-gradient(closest-side, rgba(0, 224, 255, 0.65), rgba(0, 224, 255, 0) 70%);
  opacity: 0.6;
  z-index: 1;
  transition: transform 0.6s ease, opacity 0.6s ease;
}

.card:hover .card__glow {
  opacity: 0.85;
  transform: scale(1.05);
}

.corner-lt { top: -40px; left: -40px; }
.corner-rt { top: -40px; right: -40px; }
.corner-lb { bottom: -40px; left: -40px; }
.corner-rb { bottom: -40px; right: -40px; }

.card__scanline {
  content: '';
  position: absolute;
  left: -50%;
  top: -120%;
  width: 200%;
  height: 220%;
  background: linear-gradient(
    120deg,
    rgba(255, 255, 255, 0) 40%,
    rgba(0, 200, 255, 0.12) 50%,
    rgba(255, 255, 255, 0) 60%
  );
  transform: rotate(8deg);
  animation: scan 5.2s linear infinite;
  pointer-events: none;
}

@keyframes scan {
  0% { transform: translateY(0) rotate(8deg); }
  100% { transform: translateY(60%) rotate(8deg); }
}

/* 响应式 */
@media (max-width: 1200px) {
  .card__value .num { font-size: 22px; }
}

@media (max-width: 992px) {
  .cards-grid { grid-template-columns: 1fr; }
}

</style>


