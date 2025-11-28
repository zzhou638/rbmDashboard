<template>
  <div class="esg-chart-container">
    <div ref="chart" class="chart"></div>
  </div>
</template>

<script>
import echarts from 'echarts'
import { http } from '@/api/api'

export default {
  name: 'ESGHistoryChart',
  props: {
    stockName: {
      type: String,
      required: true
    }
  },
  data() {
    return {
      chart: null,
      loading: false,
      chartData: []
    }
  },
  watch: {
    stockName: {
      handler(val) {
        if (val) {
          this.fetchData()
        }
      },
      immediate: true
    }
  },
  mounted() {
    this.$nextTick(() => {
      this.initChart()
      window.addEventListener('resize', this.handleResize)
    })
  },
  beforeDestroy() {
    if (this.chart) {
      this.chart.dispose()
      this.chart = null
    }
    window.removeEventListener('resize', this.handleResize)
  },
  methods: {
    handleResize() {
      if (this.chart) {
        this.chart.resize()
      }
    },
    async fetchData() {
      if (!this.stockName) return
      
      this.loading = true
      try {
        const res = await http.get(`esg-cnrds/history`, {
          params: { stockName: this.stockName }
        })
        
        if (res.data && Array.isArray(res.data)) {
          // 按年份升序排序
          this.chartData = res.data.sort((a, b) => a.year - b.year)
          this.updateChart()
        }
      } catch (e) {
        console.error('[ESG Chart] Fetch data failed:', e)
      } finally {
        this.loading = false
      }
    },
    initChart() {
      if (!this.$refs.chart) return
      
      if (!this.chart) {
        this.chart = echarts.init(this.$refs.chart)
      }
      this.updateChart()
    },
    updateChart() {
      if (!this.chart) return
      
      const years = this.chartData.map(item => item.year)
      const totalScores = this.chartData.map(item => item.esgTotalScore)
      const ranks = this.chartData.map(item => item.esgRank)
      const eScores = this.chartData.map(item => item.escore)
      const sScores = this.chartData.map(item => item.sscore)
      const gScores = this.chartData.map(item => item.gscore)

      const option = {
        backgroundColor: 'transparent',
        tooltip: {
          trigger: 'axis',
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          borderColor: '#4ba6f0',
          textStyle: {
            color: '#fff'
          },
          axisPointer: {
            type: 'cross'
          }
        },
        legend: {
          data: ['ESG总分', 'ESG排名', 'E得分', 'S得分', 'G得分'],
          textStyle: {
            color: 'rgba(255, 255, 255, 0.7)'
          },
          top: 0,
          right: 10,
          itemWidth: 12,
          itemHeight: 8
        },
        grid: {
          top: 40,
          right: 50, // 增加右侧间距，防止“排名”标签被遮挡
          bottom: 20,
          left: 40,
          containLabel: true
        },
        xAxis: {
          type: 'category',
          data: years,
          axisLine: {
            lineStyle: {
              color: 'rgba(75, 166, 240, 0.3)'
            }
          },
          axisLabel: {
            color: 'rgba(154, 215, 255, 0.8)',
            fontFamily: 'DIN Pro'
          },
          axisTick: { show: false }
        },
        yAxis: [
          {
            type: 'value',
            name: '评分',
            nameTextStyle: { color: 'rgba(154, 215, 255, 0.6)' },
            splitLine: {
              lineStyle: {
                color: 'rgba(75, 166, 240, 0.1)',
                type: 'dashed'
              }
            },
            axisLabel: {
              color: 'rgba(154, 215, 255, 0.6)',
              fontFamily: 'DIN Pro'
            }
          },
          {
            type: 'value',
            name: '排名',
            nameTextStyle: { color: 'rgba(255, 255, 255, 0.6)' },
            inverse: true, // 排名越小越好，所以反转坐标轴
            splitLine: { show: false },
            axisLabel: {
              color: 'rgba(255, 255, 255, 0.6)',
              fontFamily: 'DIN Pro'
            }
          }
        ],
        series: [
          {
            name: 'ESG总分',
            data: totalScores,
            type: 'bar',
            barWidth: 14,
            itemStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{
                offset: 0,
                color: '#00f2ff'
              }, {
                offset: 1,
                color: 'rgba(0, 242, 255, 0.1)'
              }]),
              borderRadius: [3, 3, 0, 0]
            },
            z: 10
          },
          {
            name: 'ESG排名',
            data: ranks,
            type: 'line',
            yAxisIndex: 1,
            smooth: true,
            symbol: 'circle',
            symbolSize: 8,
            itemStyle: {
              color: '#00ff96',
              borderColor: '#fff',
              borderWidth: 2
            },
            lineStyle: {
              width: 3,
              color: '#00ff96',
              type: 'dashed'
            }
          },
          {
            name: 'E得分',
            data: eScores,
            type: 'bar',
            barWidth: 14,
            itemStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{
                offset: 0,
                color: '#00ff96'
              }, {
                offset: 1,
                color: 'rgba(0, 255, 150, 0.1)'
              }]),
              borderRadius: [3, 3, 0, 0]
            }
          },
          {
            name: 'S得分',
            data: sScores,
            type: 'bar',
            barWidth: 14,
            itemStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{
                offset: 0,
                color: '#d946ef'
              }, {
                offset: 1,
                color: 'rgba(217, 70, 239, 0.1)'
              }]),
              borderRadius: [3, 3, 0, 0]
            }
          },
          {
            name: 'G得分',
            data: gScores,
            type: 'bar',
            barWidth: 14,
            itemStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{
                offset: 0,
                color: '#facc15'
              }, {
                offset: 1,
                color: 'rgba(250, 204, 21, 0.1)'
              }]),
              borderRadius: [3, 3, 0, 0]
            }
          }
        ]
      }

      this.chart.setOption(option)
    }
  }
}
</script>

<style scoped>
.esg-chart-container {
  width: 100%;
  height: 280px;
  margin-top: 16px;
  background: rgba(2, 6, 23, 0.3);
  border: 1px solid rgba(75, 166, 240, 0.1);
  border-radius: 8px;
  padding: 16px;
  position: relative;
}

.chart {
  width: 100%;
  height: 100%;
}

/* 添加一个科技感的角落装饰 */
.esg-chart-container::before {
  content: '';
  position: absolute;
  top: -1px;
  left: -1px;
  width: 10px;
  height: 10px;
  border-top: 2px solid #00f2ff;
  border-left: 2px solid #00f2ff;
  border-top-left-radius: 8px;
}

.esg-chart-container::after {
  content: '';
  position: absolute;
  bottom: -1px;
  right: -1px;
  width: 10px;
  height: 10px;
  border-bottom: 2px solid #00f2ff;
  border-right: 2px solid #00f2ff;
  border-bottom-right-radius: 8px;
}
</style>
