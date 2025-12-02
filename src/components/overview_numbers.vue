<template>
  <div class="overview-numbers">
    <div class="cards-grid">
      <div
        v-for="item in items"
        :key="item.key"
        class="card"
      >
        <!-- 四个角的装饰 -->
        <div class="card__bracket card__bracket--lt"></div>
        <div class="card__bracket card__bracket--rt"></div>
        <div class="card__bracket card__bracket--lb"></div>
        <div class="card__bracket card__bracket--rb"></div>

        <!-- 顶部和底部的装饰条 -->
        <div class="card__decoration-top"></div>
        <div class="card__decoration-bottom"></div>

        <div class="card__content">
          <div class="card__label">{{ item.label }}</div>
          <div class="card__value">
            <span class="num">{{ item.value }}</span>
            <span class="unit">{{ item.unit }}</span>
          </div>
        </div>
        
        <!-- 扫描线效果 -->
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
        { key: 'patent', label: '绿色专利', value: '20,560,123', unit: '件' },
        { key: 'enterprise', label: '绿色企业', value: '20,560,123', unit: '家' },
        { key: 'factory', label: '工厂数', value: '20,560,123', unit: '座' },
        { key: 'investment', label: '总投资', value: '3639.4', unit: '亿元' }
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
  padding: 0 12px 12px 12px; /* Reduced top padding */
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
  /* 移除 overflow: hidden 以允许装饰元素溢出（如果需要），但这里我们保持在内部 */
  /* overflow: hidden; */
  background: rgba(10, 14, 26, 0.6); /* 半透明深色背景 */
  /* backdrop-filter: blur(4px); */ /* 可选：毛玻璃效果 */
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  transition: all 0.3s ease;
}

/* 
  半开放式边框设计 
  使用绝对定位的 div 来模拟四个角的括号
*/
.card__bracket {
  position: absolute;
  width: 15px;
  height: 15px;
  border: 2px solid rgba(0, 200, 255, 0.6); /* 默认淡蓝色 */
  transition: all 0.3s ease;
  box-shadow: 0 0 5px rgba(0, 200, 255, 0.3);
}

/* 左上角 */
.card__bracket--lt {
  top: 0;
  left: 0;
  border-right: none;
  border-bottom: none;
  border-top-left-radius: 4px; /* 轻微圆角 */
}

/* 右上角 */
.card__bracket--rt {
  top: 0;
  right: 0;
  border-left: none;
  border-bottom: none;
  border-top-right-radius: 4px;
}

/* 左下角 */
.card__bracket--lb {
  bottom: 0;
  left: 0;
  border-right: none;
  border-top: none;
  border-bottom-left-radius: 4px;
}

/* 右下角 */
.card__bracket--rb {
  bottom: 0;
  right: 0;
  border-left: none;
  border-top: none;
  border-bottom-right-radius: 4px;
}

/* 悬停效果：边框变亮，可能稍微变大 */
.card:hover .card__bracket {
  border-color: rgba(0, 255, 214, 1); /* 亮青色 */
  box-shadow: 0 0 10px rgba(0, 255, 214, 0.6);
  width: 20px;
  height: 20px;
}

/* 顶部和底部的装饰条 (类似图片中的上下箭头或线条) */
.card__decoration-top,
.card__decoration-bottom {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  width: 40%;
  height: 2px;
  background: linear-gradient(90deg, transparent, rgba(0, 200, 255, 0.3), transparent);
}

.card__decoration-top {
  top: 4px;
}

.card__decoration-bottom {
  bottom: 4px;
  /* 可以加一个小箭头效果，这里简化为线条 */
  height: 3px;
  background: linear-gradient(90deg, transparent, rgba(0, 200, 255, 0.5), transparent);
  clip-path: polygon(0 0, 100% 0, 50% 100%); /* 倒三角形 */
  width: 20px;
  height: 4px;
}


.card__content {
  position: relative;
  z-index: 2;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 10px;
  text-align: center;
  width: 100%;
}

.card__label {
  font-size: 14px;
  letter-spacing: 0.1em;
  color: #8fb7ff;
  text-transform: uppercase;
  margin-bottom: 0px; /* Reduced from 4px */
  text-shadow: 0 0 5px rgba(0, 174, 255, 0.3);
}

.card__value {
  display: flex;
  align-items: baseline;
  justify-content: center;
}

.card__value .num {
  font-family: 'Bahnschrift', 'Roboto', sans-serif;
  font-weight: 700;
  font-size: 24px; /* Reduced from 28px */
  line-height: 1;
  color: #fff;
  /* 简单的白色发光效果，或者保留之前的渐变 */
  text-shadow: 0 0 10px rgba(0, 200, 255, 0.6);
  background: linear-gradient(180deg, #ffffff 0%, #b0e0ff 100%);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.card__value .unit {
  margin-left: 4px;
  font-size: 12px;
  color: #9ad7ff;
  opacity: 0.8;
}

/* 扫描线动画 */
.card__scanline {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(to bottom, transparent, rgba(0, 255, 214, 0.05), transparent);
  transform: translateY(-100%);
  animation: scan 3s linear infinite;
  pointer-events: none;
  z-index: 1;
}

@keyframes scan {
  0% { transform: translateY(-100%); }
  100% { transform: translateY(100%); }
}

/* 响应式 */
@media (max-width: 1200px) {
  .card__value .num { font-size: 24px; }
}

@media (max-width: 992px) {
  .cards-grid { grid-template-columns: 1fr; }
}
</style>


