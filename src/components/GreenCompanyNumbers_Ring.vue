<template>
  <div class="green-company-ring">
    <span class="card_title">{{ displayRegion }}绿色企业</span>
    <div class="ring-donut" ref="chart"></div>
    <div class="ring-caption">绿色产业上市公司数量分布 TOP10</div>
  </div>
</template>

<script>
import * as echarts from 'echarts'
import bus from '@/bus'
import { http } from '@/api/api'

export default {
  name: 'GreenCompanyNumbersRing',
  props: {
    // 中心显示的大数（备用）
    total: { type: [Number, String], default: 0 },
    // 外部传入的数据项（备用）
    items: {
      type: Array,
      default: () => ([
        // { name: '杭州', value: 145098, color: '#5AD8A6' }
      ])
    },
    // 圆环粗细：内外半径
    radius: { type: Array, default: () => ['100%', '100%'] },
    // 是否显示图例
    showLegend: { type: Boolean, default: false },
    // 中心副标题
    subtitle: { type: String, default: '' }
  },
  data () {
    return {
      chart: null,
      dataset: [],
      totalCount: 0,
      filterParams: {},
      displayRegion: '大湾区'
    }
  },
  mounted () {
    this.init()
    this.fetchIndustryStats()
    bus.$on('overview:investmentFilter', this.onFilterChange)
    window.addEventListener('resize', this.resize)
  },
  beforeDestroy () {
    this.chart && this.chart.dispose()
    bus.$off('overview:investmentFilter', this.onFilterChange)
    window.removeEventListener('resize', this.resize)
  },
  watch: {
    items: { deep: true, handler () { this.render() } },
    total () { this.render() }
  },
  methods: {
    init () {
      this.chart = echarts.init(this.$refs.chart)
      this.render()
    },
    resize () {
      if (!this.chart) return
      this.chart.resize()
    },
    onFilterChange (filters) {
      if (!filters || typeof filters !== 'object') {
        this.filterParams = {}
        this.displayRegion = '大湾区'
      } else {
        const { city, district } = filters
        this.filterParams = {
          ...(city ? { city } : {}),
          ...(district ? { district } : {})
        }
        this.displayRegion = city || district || '大湾区'
      }
      this.render()
      this.fetchIndustryStats()
    },
    fetchIndustryStats (params) {
      const query = params || this.filterParams || {}
      http.get('companies/industry-stats', { params: query })
        .then(res => {
          const payload = res?.data || {}
          const industries = Array.isArray(payload.industries) ? payload.industries : []
          this.dataset = industries.map((item, idx) => ({
            name: item?.industryName || item?.name || `行业${idx + 1}`,
            value: Number(item?.count) || 0
          }))
          this.totalCount = Number(payload.total ?? this.dataset.reduce((sum, it) => sum + (it.value || 0), 0))
          this.render()
        })
        .catch(err => {
          console.warn('[GreenCompanyRing] 获取行业统计失败:', err)
          this.dataset = []
          this.totalCount = 0
          this.render()
        })
    },
    getDisplayData () {
      if (this.dataset.length) return this.dataset
      return this.items.map(d => ({
        name: d.name,
        value: Number(d.value),
        itemStyle: d.color ? { color: d.color } : undefined
      }))
    },
    getTotalDisplay () {
      if (this.dataset.length) return this.totalCount
      const arr = this.items.map(d => Number(d.value) || 0)
      return arr.length ? arr.reduce((a, b) => a + b, 0) : Number(this.total) || 0
    },
    render () {
      if (!this.chart) return
      const el = this.$refs.chart
      const w = el ? el.clientWidth : 300
      const h = el ? el.clientHeight : 300
      const s = Math.max(120, Math.min(w, h))
      const bigFont = Math.round(Math.max(14, s * 0.1)) // 大数
      const smallFont = Math.round(Math.max(10, s * 0.05)) // 副标题
      const LegendFont = Math.round(Math.max(10, s * 0.03)) // 图例
      const data = this.getDisplayData().map(d => ({
        name: d.name,
        value: d.value,
        itemStyle: d.color ? { color: d.color } : undefined
      }))
      const totalText = (this.getTotalDisplay() ?? 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
      const subtitleText = this.subtitle || `${this.displayRegion}企业`

      const option = {
        backgroundColor: 'transparent',
        tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
        legend: this.showLegend ? {
          bottom: 8,
          itemWidth: 10,
          itemHeight: 10,
          textStyle: { color: '#C9D1D9', fontSize: LegendFont },
          top: '90%'
        } : undefined,
        // 中心文字（更灵活 than title）
        graphic: [
          {
            type: 'text',
            left: 'center',
            top: '32%',
            style: {
              text: totalText,
              fill: '#FFFFFF',
              fontSize: bigFont,
              fontWeight: 700,
              textAlign: 'center'
            }
          },
          {
            type: 'text',
            left: 'center',
            top: '51%',
            style: {
              text: subtitleText,
              fill: '#94A3B8',
              fontSize: smallFont,
              textAlign: 'center'
            }
          }
        ],
        series: [
          // 数据环
          {
            name: 'value',
            type: 'pie',
            radius: this.radius,
            z: 2,
            center: ['50%', '40%'],
            avoidLabelOverlap: true,
            label: { show: false },
            labelLine: { show: false },
            clockwise: true,
            data
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
.green-company-ring {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1px;
}
.placeholder {
  font-size: 18px;
  color: #66ddff;
  text-shadow: 0 0 8px rgba(0, 170, 255, 0.55);
  letter-spacing: 1px;
}
.ring-donut {
  position: relative;
  top: 25px;
  width: 100%;
  height: calc(100% - 30px); /* 留出标题与标签空间 */
  /* 保证在极宽或极窄情况下内容不过度拉伸： */
  max-height: 100%;
}
.card_title {
  position: absolute;     /* 让它浮在组件内部 */
  top: 10px;              /* 距离顶部 10px */
  left: 15px;              /* 距离左侧 5px */
  font-size: 24px;
  font-weight: 700;
  pointer-events: none;   /* 防止挡住鼠标事件（可选） */
  z-index: 10;            /* 确保压在图层上方 */
}
.ring-caption {
  margin-top: 0;
  font-size: 13px;
  letter-spacing: 0.1em;
  color: #8fd8ff;
  text-shadow: 0 0 10px rgba(0, 195, 255, 0.5);
  text-transform: uppercase;
  align-self: center;
  padding: 1px 10px;
  border: 1px solid rgba(0, 195, 255, 0.35);
  border-radius: 999px;
  background: radial-gradient(circle, rgba(0, 195, 255, 0.08), rgba(0, 195, 255, 0));
}
</style>

