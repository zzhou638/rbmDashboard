<template>
  <div class="dashboard-container">
    <!-- 数字孪生背景效果 -->
    <div class="background-layers">
      <div class="grid-layer"></div>
      <div class="scan-line"></div>
    </div>
    
    <!-- 顶部信息栏 -->
    <header class="dashboard-header">

      <div class="header-left">
        <!-- 左侧数据区域：概览指标 -->
        
      </div>
      <div class="header-center">
        <div class="title-frame">
          <div class="frame-bg-texture"></div>
          <div class="decoration-glow"></div>
          <div class="frame-border">
            <div class="border-line border-line-top"></div>
            <div class="border-line border-line-bottom"></div>
            <div class="animated-line animated-line-1"></div>
          </div>
          <div class="title-content">
            <div class="logo-title">绿色金融决策仪表板</div>
            <div class="logo-subtitle-en">GREEN FINANCE DECISION DASHBOARD</div>
          </div>
        </div>
      </div>
      <div class="header-right">
        <div class="user-profile">
          <div class="user-info">
            <div class="user-name">{{ userInfo.name || 'Admin User' }}</div>
            <div class="user-role">{{ userInfo.position || '超级管理员' }}</div>
          </div>
          <div class="user-avatar">
            <div class="avatar-circle">
              <img src="https://api.dicebear.com/9.x/avataaars/svg?seed=Felix" alt="User" />
            </div>
            <div class="avatar-ring"></div>
          </div>
        </div>
        <button class="logout-btn" @click="handleLogout" title="退出登录">
          <span class="logout-icon">⏻</span>
        </button>
      </div>
    </header>

    <!-- 主内容区域 -->
    <main class="dashboard-content">
      <div class="content-layout">
        <!-- 左侧数据面板 -->
        <aside class="left-panels">
          <div class="data-panel" v-for="(panel, index) in leftPanels" :key="index">
            <div class="panel-content">
              <template v-if="index === 0">
                <OverviewNumbers />
              </template>
              <template v-else-if="index === 1">
                <GreenFinanceInvestimentTrend :trend="InvestimentTrend" />
              </template>
              <template v-if="index === 2">
                <GreenCompanyNumbersRing
                  :total="145098"
                  subtitle="大湾区企业"
                  :items="segments"
                  :radius="['56%','74%']"
                 />
              </template>
              <!-- <template v-else>
                <div class="panel-placeholder">
                  <div class="pulse-dot"></div>
                  <p>{{ panel.placeholder }}</p>
                </div>
              </template> -->
            </div>
          </div>
        </aside>

        <!-- 中间地图大屏 -->
        <section class="map-display">
          <div class="map-container">
            <div class="map-content">
              <div class="map-viewport">
                <NewMapDisplay :geojsonUrl="gbaGeojsonUrl" :isChatOpen="showChatPanel" />
              </div>
              <!-- 聊天面板：紧贴输入框上方展开 -->
              <div v-if="showChatPanel" class="chat-panel">
                <div class="chat-panel-header">
                  <span>AI 助手</span>
                  <button class="chat-close" @click="closeChatPanel">×</button>
                </div>
                <div class="chat-messages" ref="chatMessages">
                  <div v-for="(m, i) in chatMessages" :key="i" class="chat-message" :class="m.role">
                    <div class="bubble" v-html="renderMarkdown(m.content)"></div>
                  </div>
                </div>
              </div>
              <div class="chat-box">
                <input
                  v-model="chatInput"
                  type="text"
                  class="chat-input"
                  placeholder="向 AI Agent 提问... 按 Enter 发送"
                  @keyup.enter="onSendChat"
                />
                <button class="chat-send" @click="onSendChat">发送</button>
              </div>
            </div>
          </div>
        </section>

        <!-- 右侧数据面板 -->
        <aside class="right-panels">
          <div class="data-panel" v-for="(panel, index) in rightPanels" :key="index">
            <div class="panel-content">
              <template v-if="index === 0">
                <CarbonEmissionBar />
              </template>
              <template v-else-if="index === 1">
                <AverageTemperatureLine />
              </template>
              <template v-else-if="index === 2">
                <EsgReportCard :text="esgReportSummary" />
              </template>
              <!-- <template v-else>
                <div class="panel-placeholder">
                  <div class="pulse-dot"></div>
                  <p>{{ panel.placeholder }}</p>
                </div>
              </template> -->
            </div>
          </div>
        </aside>
      </div>
    </main>
  </div>
</template>

<script>
import NewMapDisplay from '@/components/NewMapDisplay.vue'
import OverviewNumbers from '@/components/overview_numbers.vue'
import GreenCompanyNumbersRing from '@/components/GreenCompanyNumbers_Ring.vue'
import CarbonEmissionBar from '@/components/CarbonEmissionBar.vue'
import AverageTemperatureLine from '@/components/AverageTemperatureLine.vue'
import EsgReportCard from '@/components/EsgReportCard.vue'
import GreenFinanceInvestimentTrend from '@/components/GreenFinanceInvestimentTrend.vue'
import axios from 'axios'
export default {
  name: 'HomePage',
  components: {
    NewMapDisplay,
    OverviewNumbers,
    GreenCompanyNumbersRing,
    GreenFinanceInvestimentTrend,
    CarbonEmissionBar,
    AverageTemperatureLine,
    EsgReportCard
  },
  data() {
    return {
      userInfo: {},
      // 直接使用静态路径，避免对 .geojson 进行 import 解析
      gbaGeojsonUrl: '/assets/geojson/GBA.geojson',
      chatInput: '',
      showChatPanel: false,
      chatMessages: [],
      useLanEndpoint: true, // 默认使用局域网端点
      lanEndpointChecked: false, // 是否已检查局域网端点
      leftPanels: [
        { title: '数据面板1', placeholder: '可视化数据区域' },
        { title: '数据面板2', placeholder: '可视化数据区域' },
        { title: '数据面板3', placeholder: '可视化数据区域' }
      ],
      rightPanels: [
        { title: '数据面板5', placeholder: '可视化数据区域' },
        { title: '数据面板6', placeholder: '可视化数据区域' },
        { title: '数据面板7', placeholder: '可视化数据区域' },
        // { title: '数据面板8', placeholder: '可视化数据区域' }
      ],
      segments: [
        { name: '软件服务页', value: 145098, color: '#4CC9F0' },
        { name: '房地产业', value: 23000,  color: '#F72585' },
        { name: '制造业', value: 18000,  color: '#7209B7' },
        { name: '交通运输', value: 16000,  color: '#3A0CA3' },
        { name: '科学研究与技术服务业', value: 12000,  color: '#4895EF' }
      ],
      // 右侧第一个数据框：各城市碳排放量（可被接口数据覆盖）
      carbonCityEmissions: [
        { city: '广州', value: 3200 },
        { city: '深圳', value: 2900 },
        { city: '佛山', value: 2100 },
        { city: '东莞', value: 1850 },
        { city: '中山', value: 1200 },
        { city: '珠海', value: 950 }
      ],
      InvestimentTrend: [
        { name: '2018', value: 145098 },
        { name: '2019', value: 23000 },
        { name: '2020', value: 18000 },
        { name: '2021', value: 16000 },
        { name: '2022', value: 12000 }
      ],
      // 右侧第二个数据框：年度平均温度（°C）
      averageTemperatureByYear: [
        { year: 2018, value: 21.8 },
        { year: 2019, value: 22.3 },
        { year: 2020, value: 22.0 },
        { year: 2021, value: 22.7 },
        { year: 2022, value: 23.1 },
        { year: 2023, value: 23.5 }
      ],
      // 右侧第三个数据框：AI ESG 摘要文本
      esgReportSummary: `本报告基于企业披露与第三方数据生成，涵盖环境（E）、社会（S）与治理（G）。\n\n环境：碳排放强度同比下降，可再生能源占比提升；水资源使用效率与固废回收率改善。\n社会：员工安全管理稳定运行，供应链合规覆盖提升；公益投入增强，促进社区共建。\n治理：董事会多元化程度提高，信息披露及时；合规与反腐机制持续完善。\n\n总体：ESG 表现稳中向好，建议继续推进低碳转型，强化供应链尽责管理，并完善 TCFD 相关披露。`
    }
  },
  mounted() {
    const storedUserInfo = localStorage.getItem('userInfo')
    if (storedUserInfo) {
      try {
        this.userInfo = JSON.parse(storedUserInfo)
      } catch (e) {
        console.error('Failed to parse userInfo', e)
      }
    }
    // 检查局域网端点是否可用
    this.checkLanEndpoint()
  },
  methods: {
    // 检查局域网端点是否可用
    checkLanEndpoint() {
      const lanUrl = 'http://10.4.183.186:8000/api/agent'
      // 使用 HEAD 请求或 GET 请求来检测端点是否可用
      axios.get(lanUrl, { timeout: 2000 })
        .then(() => {
          console.log('[Chatbox] LAN endpoint is available')
          this.useLanEndpoint = true
        })
        .catch(() => {
          console.log('[Chatbox] LAN endpoint is NOT available, falling back to API')
          this.useLanEndpoint = false
        })
        .finally(() => {
          this.lanEndpointChecked = true
        })
    },
    
    onSendChat() {
      if (!this.chatInput || !this.chatInput.trim()) return
      const text = this.chatInput.trim()
      const userMsg = { role: 'user', content: text }
      // push user message and clear input
      this.chatMessages.push(userMsg)
      this.chatInput = ''
      this.showChatPanel = true
      this.$nextTick(() => this.scrollChatToBottom())

      // 显示临时占位回复
      const placeholder = { role: 'assistant', content: '正在思考中...' }
      this.chatMessages.push(placeholder)
      this.$nextTick(() => this.scrollChatToBottom())

      // 根据端点可用性选择请求地址和参数
      let requestPromise
      if (this.useLanEndpoint) {
        // 使用局域网端点
        console.log('[Chatbox] Using LAN endpoint')
        requestPromise = axios.post('http://10.4.183.186:8000/api/agent', { query: text }, { timeout: 300000 })
      } else {
        // 使用 API 端点，支持多轮对话
        console.log('[Chatbox] Using API endpoint with history')
        // 构建历史记录（排除当前用户消息和占位符）
        const history = this.chatMessages
          .filter(m => m !== userMsg && m !== placeholder)
          .map(m => ({ role: m.role, content: m.content }))
        
        // 只有在有历史记录时才传递 history 参数
        const payload = { message: text }
        if (history.length > 0) {
          payload.history = history
        }
        
        requestPromise = axios.post('/api/agent/chat', payload, { timeout: 300000 })
      }

      requestPromise
        .then(res => {
          // 移除占位回复并推入真实回复
          const idx = this.chatMessages.indexOf(placeholder)
          if (idx !== -1) this.chatMessages.splice(idx, 1)

          let replyText = ''
          const payload = res?.data
          if (!payload) {
            replyText = 'AI Agent 未返回内容。'
          } else if (typeof payload === 'string') {
            replyText = payload
          } else if (payload.answer) {
            replyText = payload.answer
          } else if (payload.reply) {
            replyText = payload.reply
          } else if (payload.data && (payload.data.answer || payload.data.reply)) {
            replyText = payload.data.answer || payload.data.reply
          } else if (payload.message) {
            replyText = payload.message
          } else {
            replyText = JSON.stringify(payload)
          }

          this.chatMessages.push({ role: 'assistant', content: replyText })
          this.$nextTick(() => this.scrollChatToBottom())
        })
        .catch(err => {
          const idx = this.chatMessages.indexOf(placeholder)
          if (idx !== -1) this.chatMessages.splice(idx, 1)
          const errMsg = err?.response?.data?.error || err.message || '请求 AI Agent 失败'
          this.chatMessages.push({ role: 'assistant', content: `错误：${errMsg}` })
          this.$nextTick(() => this.scrollChatToBottom())
          console.error('[AI Agent] 请求失败:', err)
        })
    },
    scrollChatToBottom() {
      const box = this.$refs.chatMessages
      if (box) {
        try { box.scrollTop = box.scrollHeight } catch (e) { /* ignore */ }
      }
    },
    escapeHtml(str) {
      if (str === null || str === undefined) return ''
      return String(str).replace(/[&<>"']/g, function (s) {
        return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[s]
      })
    },
    renderMarkdown(raw) {
      if (!raw && raw !== 0) return ''
      let s = String(raw)
      // 防止 HTML 注入：先转义
      s = this.escapeHtml(s)

      // 行内代码 `code`
      s = s.replace(/`([^`]+?)`/g, '<code>$1</code>')

      // 加粗 **bold**
      s = s.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')

      // 标题 #, ##, ###
      s = s.replace(/^###\s+(.*)$/gm, '<h3>$1</h3>')
      s = s.replace(/^##\s+(.*)$/gm, '<h2>$1</h2>')
      s = s.replace(/^#\s+(.*)$/gm, '<h1>$1</h1>')

      // 将按行处理列表和段落
      const lines = s.split(/\r?\n/)
      let out = ''
      let inUl = false
      let inOl = false
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        if (/^\s*[-*]\s+/.test(line)) {
          if (inOl) { out += '</ol>'; inOl = false }
          if (!inUl) { out += '<ul>'; inUl = true }
          out += '<li>' + line.replace(/^\s*[-*]\s+/, '') + '</li>'
          continue
        }
        if (/^\s*\d+\.\s+/.test(line)) {
          if (inUl) { out += '</ul>'; inUl = false }
          if (!inOl) { out += '<ol>'; inOl = true }
          out += '<li>' + line.replace(/^\s*\d+\.\s+/, '') + '</li>'
          continue
        }
        // 空行 -> 段落分隔
        if (line.trim() === '') {
          if (inUl) { out += '</ul>'; inUl = false }
          if (inOl) { out += '</ol>'; inOl = false }
          out += ''
          continue
        }
        // 非列表、非标题的普通行，包成段落
        if (!/^<h[1-3]>/i.test(line)) {
          out += '<p>' + line + '</p>'
        } else {
          out += line
        }
      }
      if (inUl) out += '</ul>'
      if (inOl) out += '</ol>'

      return out
    },
    closeChatPanel() {
      this.showChatPanel = false
      // 清除历史消息，下次打开时重新开始新对话
      this.chatMessages = []
    },
    handleLogout() {
      // 清除用户信息
      localStorage.removeItem('userInfo')
      // 跳转到登录页
      this.$router.push('/login')
    }
  }
}
</script>

<style scoped>
.dashboard-container {
  min-height: 100vh;
  background: #000000;
  color: #66ddff;
  position: relative;
  overflow: hidden;
  padding: 0;
  font-family: 'Arial', 'Microsoft YaHei', sans-serif;
}

/* 背景图层 */
.background-layers {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
  pointer-events: none;
}

.grid-layer {
  width: 100%;
  height: 100%;
  background-image: 
    linear-gradient(rgba(102, 221, 255, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(102, 221, 255, 0.03) 1px, transparent 1px);
  background-size: 40px 40px;
  opacity: 0.5;
}

.scan-line {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 2px;
  background: linear-gradient(90deg, transparent, rgba(102, 221, 255, 0.5), transparent);
  animation: scan 3s linear infinite;
  box-shadow: 0 0 20px rgba(102, 221, 255, 0.8);
}

@keyframes scan {
  0% { transform: translateY(0); opacity: 1; }
  100% { transform: translateY(100vh); opacity: 0; }
}

/* 顶部信息栏 */
.dashboard-header {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: 2;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px; /* 去掉上下 padding，让中间梯形能顶满高度 */
  height: 80px; /* 固定标题区域高度 */
  background: transparent;
  border-bottom: none;
  backdrop-filter: none;
}

.header-left,
.header-center,
.header-right {
  flex: 1;
  display: flex;
  align-items: center;
  height: 100%; /* 确保子元素能继承高度 */
}

.header-left {
  justify-content: flex-start;
}

.header-center {
  justify-content: center;
  align-items: flex-start; /* 让梯形从顶部开始 */
}

.header-right {
  justify-content: flex-end;
}

.title-frame {
  position: relative;
  margin: 0;
  padding: 0;
  width: 50vw; /* 增加宽度，改为视口宽度的 50% */
  min-width: 700px; /* 保证最小宽度 */
  height: 100%; /* 占满高度 */
  display: flex;
  justify-content: center;
  align-items: center;
  background: linear-gradient(180deg, rgba(10, 40, 60, 0.95) 0%, rgba(0, 20, 40, 0.85) 100%);
  clip-path: polygon(0 0, 100% 0, 92% 100%, 8% 100%); /* 调整梯形角度，使其更宽展 */
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6), inset 0 0 50px rgba(102, 221, 255, 0.05);
}

.frame-bg-texture {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-image: 
    linear-gradient(rgba(102, 221, 255, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(102, 221, 255, 0.03) 1px, transparent 1px);
  background-size: 20px 20px;
  opacity: 0.5;
  pointer-events: none;
}

.decoration-glow {
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 60%;
  height: 100%;
  background: radial-gradient(ellipse at top, rgba(102, 221, 255, 0.25) 0%, transparent 70%);
  pointer-events: none;
  z-index: 0;
}

.title-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  z-index: 2;
  transform: translateY(-2px);
}

.logo-title {
  font-size: 28px; /* 进一步放大 */
  font-weight: 800;
  background: linear-gradient(180deg, #ffffff 0%, #66ddff 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  text-shadow: 0 0 20px rgba(102, 221, 255, 0.4);
  letter-spacing: 6px;
  margin-bottom: 4px;
  position: relative;
  z-index: 1;
}

.logo-subtitle-en {
  font-size: 10px;
  color: rgba(102, 221, 255, 0.6);
  letter-spacing: 4px;
  text-transform: uppercase;
  font-family: 'Arial', sans-serif;
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
}

.logo-subtitle-en::before,
.logo-subtitle-en::after {
  content: '';
  display: block;
  width: 40px;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(102, 221, 255, 0.5), transparent);
}

.status-indicator {
  display: flex;
  align-items: center;
  gap: 8px;
}

.status-dot {
  width: 8px;
  height: 8px;
  background: #66ddff;
  border-radius: 50%;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.8);
  animation: pulse-dot 2s infinite;
}

@keyframes pulse-dot {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.status-text {
  font-size: 14px;
  color: rgba(102, 221, 255, 0.8);
}

/* 主内容区域 */
.dashboard-content {
  position: relative;
  z-index: 1;
  padding: 80px 0 0 0; /* 顶部为标题区域留白，图表/地图不被覆盖 */
  box-sizing: border-box;
  height: calc(100vh - 0px);
  overflow: hidden;
}

.content-layout {
  display: grid;
  /* 1.2 : 2.6 : 1.2 约等于 24% : 52% : 24%，中间留出 gap 的空间 */
  grid-template-columns: 1.2fr 2.6fr 1.2fr;
  gap: 20px;
  height: 100%;
}

/* 左侧面板区域 */
.left-panels,
.right-panels {
  display: flex;
  flex-direction: column;
  gap: 20px;
  height: 100%;
  min-height: 0;
  padding: 0 4px 10px 0;
  box-sizing: border-box;
  overflow-y: auto;
}

/* 右侧面板外侧向右预留 5px 边距，避免贴边溢出 */
.right-panels {
  margin-right: 5px;
  padding: 0 0 10px 4px;
  /* 向左位移 5px */
}

/* 左侧面板改为 3 行网格布局：1 : 1.5 : 1.5 = 25% : 37.5% : 37.5% */
.left-panels {
  display: grid;
  grid-template-rows: 1fr 1.5fr 1.5fr;
  row-gap: 20px;
}

/* 避免网格下子项受到 flex 尺寸影响 */
.left-panels .data-panel {
  flex: initial;
}

.left-panels::-webkit-scrollbar,
.right-panels::-webkit-scrollbar {
  width: 4px;
}

.left-panels::-webkit-scrollbar-track,
.right-panels::-webkit-scrollbar-track {
  background: rgba(102, 221, 255, 0.1);
}

.left-panels::-webkit-scrollbar-thumb,
.right-panels::-webkit-scrollbar-thumb {
  background: rgba(102, 221, 255, 0.3);
  border-radius: 2px;
}

/* 数据面板 */
.data-panel {
  flex: 1 1 0;
  min-height: 0;
  background: rgba(102, 221, 255, 0.05);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 4px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.panel-content {
  flex: 1;
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.panel-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: rgba(102, 221, 255, 0.5);
  padding: 20px;
  box-sizing: border-box;
}

.panel-placeholder .pulse-dot {
  width: 12px;
  height: 12px;
  background: #66ddff;
  border-radius: 50%;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.8);
  animation: pulse-dot 2s infinite;
  margin-bottom: 15px;
}

.panel-placeholder p {
  margin: 0;
  font-size: 14px;
}

/* 中间地图大屏 */
.map-display {
  height: 100%;
}

.map-container {
  width: 100%;
  height: 100%;
  background: rgba(102, 221, 255, 0.05);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 4px;
  overflow: hidden;
}

.map-content {
  width: 100%;
  height: 100%;
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* 浮动 AI 聊天面板 */
.chat-panel {
  flex: 0 0 40%; /* 占据 40% 高度，挤压上方地图 */
  max-height: 40%; /* 强制最大高度，防止内容撑开 */
  margin: 0 10px 10px 10px;
  background: #000000;
  border: 1px solid rgba(102, 221, 255, 0.35);
  border-radius: 6px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
  display: flex;
  flex-direction: column;
  min-height: 0; /* 防止 flex 子项溢出 */
  z-index: 10;
  overflow: hidden; /* 确保内容不会撑开容器 */
}

.chat-panel-header {
  height: 40px;
  flex-shrink: 0; /* 防止头部被压缩 */
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 10px 0 12px;
  border-bottom: 1px solid rgba(102, 221, 255, 0.2);
  color: #cfefff;
}

.chat-close {
  width: 28px;
  height: 28px;
  line-height: 26px;
  text-align: center;
  border: 1px solid rgba(102, 221, 255, 0.4);
  background: transparent;
  color: #66ddff;
  border-radius: 4px;
  cursor: pointer;
}

.chat-messages {
  flex: 1 1 0; /* 关键：设置 flex-basis 为 0，强制滚动 */
  overflow-y: auto;
  padding: 10px;
  min-height: 0;
}

.chat-message { display: flex; margin-bottom: 10px; }
.chat-message.user { justify-content: flex-end; }
.chat-message.assistant { justify-content: flex-start; }
.chat-message .bubble {
  max-width: 75%;
  padding: 8px 10px;
  border-radius: 6px;
  font-size: 13px;
  line-height: 1.4;
  color: #e7f7ff;
  word-break: break-word;
}
.chat-message.user .bubble {
  background: rgba(30, 144, 255, 0.25);
  border: 1px solid rgba(30, 144, 255, 0.4);
  text-align: right;
}
.chat-message.assistant .bubble {
  background: rgba(102, 221, 255, 0.15);
  border: 1px solid rgba(102, 221, 255, 0.35);
  text-align: left;
}

/* 地图可视区域：高度略缩小，四周 10px 间距 */
.map-viewport {
  flex: 1 1 auto;
  height: auto;
  min-height: 0; /* 关键：允许 flex 子项收缩 */
  margin: 10px;
  border-radius: 4px;
  overflow: hidden;
}

/* 聊天输入框区域 */
.chat-box {
  flex: 0 0 60px;
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 10px 10px 10px;
  background: rgba(102, 221, 255, 0.05);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 4px;
  padding: 8px 10px;
  box-sizing: border-box;
  z-index: 10;
}

.chat-input {
  flex: 1;
  height: 36px;
  background: rgba(0,0,0,0.4);
  border: 1px solid rgba(102, 221, 255, 0.3);
  border-radius: 4px;
  color: #cfefff;
  padding: 0 10px;
}

.chat-send {
  height: 36px;
  padding: 0 14px;
  background: #0b3d4a;
  color: #66ddff;
  border: 1px solid rgba(102, 221, 255, 0.4);
  border-radius: 4px;
  cursor: pointer;
}

.map-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: rgba(102, 221, 255, 0.5);
  position: relative;
}

.map-icon {
  font-size: 64px;
  filter: drop-shadow(0 0 10px rgba(102, 221, 255, 0.8));
  margin-bottom: 20px;
}

.map-placeholder p {
  font-size: 18px;
  margin: 0 0 20px 0;
}

.map-grid {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-image: 
    linear-gradient(rgba(102, 221, 255, 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(102, 221, 255, 0.05) 1px, transparent 1px);
  background-size: 50px 50px;
  opacity: 0.3;
  pointer-events: none;
}

/* 顶部指标卡片 */
.top-metrics {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 20px;
  margin-bottom: 20px;
}

.metric-card {
  position: relative;
  background: rgba(102, 221, 255, 0.05);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 4px;
  padding: 20px;
  display: flex;
  align-items: center;
  gap: 15px;
  transition: all 0.3s ease;
  overflow: hidden;
}

.metric-card:hover {
  border-color: rgba(102, 221, 255, 0.5);
  box-shadow: 0 0 20px rgba(102, 221, 255, 0.2);
  transform: translateY(-2px);
}

.metric-icon {
  font-size: 32px;
  filter: drop-shadow(0 0 5px rgba(102, 221, 255, 0.8));
}

.metric-info {
  flex: 1;
}

.metric-label {
  font-size: 12px;
  color: rgba(102, 221, 255, 0.7);
  margin-bottom: 5px;
}

.metric-value {
  font-size: 24px;
  font-weight: 700;
  color: #66ddff;
  text-shadow: 0 0 10px rgba(102, 221, 255, 0.6);
  margin-bottom: 5px;
}

.metric-trend {
  font-size: 12px;
  display: flex;
  align-items: center;
  gap: 3px;
}

.metric-trend.up {
  color: #66ddff;
}

.metric-trend.down {
  color: #ff6b6b;
}

.trend-icon {
  font-weight: 700;
}

.metric-border {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(90deg, transparent, #66ddff, transparent);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.metric-card:hover .metric-border {
  opacity: 1;
}

/* 可视化区域 */
.visualization-area {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 20px;
  margin-bottom: 20px;
}

.chart-panel,
.data-panel {
  background: rgba(102, 221, 255, 0.05);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 4px;
  overflow: hidden;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px 20px;
  border-bottom: 1px solid rgba(102, 221, 255, 0.2);
}

.panel-title {
  font-size: 16px;
  font-weight: 600;
  color: #66ddff;
  text-shadow: 0 0 10px rgba(102, 221, 255, 0.5);
}

.panel-controls {
  display: flex;
  gap: 10px;
}

.control-btn {
  padding: 5px 12px;
  font-size: 12px;
  color: rgba(102, 221, 255, 0.6);
  cursor: pointer;
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 2px;
  transition: all 0.3s ease;
}

.control-btn:hover,
.control-btn.active {
  color: #66ddff;
  border-color: rgba(102, 221, 255, 0.5);
  background: rgba(102, 221, 255, 0.1);
}

.panel-badge {
  padding: 4px 10px;
  background: rgba(102, 221, 255, 0.2);
  border-radius: 12px;
  font-size: 12px;
  color: #66ddff;
}

.panel-content {
  position: relative;
  padding: 20px;
}

.chart-visualization {
  height: 300px;
  display: flex;
  align-items: flex-end;
  justify-content: space-around;
  gap: 10px;
}

.data-bars {
  display: flex;
  align-items: flex-end;
  justify-content: space-around;
  width: 100%;
  height: 100%;
  gap: 10px;
}

.bar {
  flex: 1;
  background: linear-gradient(to top, rgba(102, 221, 255, 0.8), rgba(102, 221, 255, 0.3));
  border-radius: 4px 4px 0 0;
  position: relative;
  transition: all 0.3s ease;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.3);
}

.bar:hover {
  background: linear-gradient(to top, #66ddff, rgba(102, 221, 255, 0.5));
  box-shadow: 0 0 20px rgba(102, 221, 255, 0.6);
  transform: translateY(-5px);
}

.bar-value {
  position: absolute;
  top: -25px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 12px;
  color: #66ddff;
  white-space: nowrap;
}

.data-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.data-item {
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 15px;
  background: rgba(102, 221, 255, 0.03);
  border: 1px solid rgba(102, 221, 255, 0.1);
  border-radius: 4px;
  transition: all 0.3s ease;
}

.data-item:hover {
  border-color: rgba(102, 221, 255, 0.3);
  background: rgba(102, 221, 255, 0.05);
}

.item-icon {
  font-size: 24px;
  filter: drop-shadow(0 0 5px rgba(102, 221, 255, 0.8));
}

.item-content {
  flex: 1;
}

.item-title {
  font-size: 14px;
  color: rgba(102, 221, 255, 0.7);
  margin-bottom: 5px;
}

.item-value {
  font-size: 18px;
  font-weight: 700;
  color: #66ddff;
  text-shadow: 0 0 10px rgba(102, 221, 255, 0.6);
}

.item-status {
  padding: 5px 12px;
  border-radius: 12px;
  font-size: 12px;
}

.item-status.active {
  background: rgba(102, 221, 255, 0.2);
  color: #66ddff;
}

.item-status.success {
  background: rgba(102, 221, 255, 0.2);
  color: #66ddff;
}

.item-status.warning {
  background: rgba(255, 193, 7, 0.2);
  color: #ffc107;
}

/* 底部面板 */
.bottom-panels {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}

.info-panel {
  background: rgba(102, 221, 255, 0.05);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 4px;
  overflow: hidden;
}

.distribution-chart {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.dist-item {
  display: flex;
  align-items: center;
  gap: 15px;
}

.dist-label {
  width: 80px;
  font-size: 14px;
  color: rgba(102, 221, 255, 0.7);
}

.dist-bar {
  flex: 1;
  height: 20px;
  background: rgba(102, 221, 255, 0.1);
  border-radius: 10px;
  overflow: hidden;
  position: relative;
}

.dist-fill {
  height: 100%;
  background: linear-gradient(90deg, rgba(102, 221, 255, 0.8), rgba(102, 221, 255, 0.4));
  border-radius: 10px;
  transition: width 1s ease;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.5);
}

.dist-value {
  width: 50px;
  text-align: right;
  font-size: 14px;
  font-weight: 700;
  color: #66ddff;
}

.environment-metrics {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.env-item {
  display: flex;
  align-items: center;
  gap: 15px;
}

.env-icon {
  font-size: 28px;
  filter: drop-shadow(0 0 5px rgba(102, 221, 255, 0.8));
}

.env-info {
  flex: 1;
}

.env-label {
  font-size: 12px;
  color: rgba(102, 221, 255, 0.7);
  margin-bottom: 5px;
}

.env-value {
  font-size: 20px;
  font-weight: 700;
  color: #66ddff;
  text-shadow: 0 0 10px rgba(102, 221, 255, 0.6);
}

.env-unit {
  font-size: 12px;
  color: rgba(102, 221, 255, 0.5);
  margin-top: 2px;
}

.env-chart {
  width: 100px;
  height: 6px;
  background: rgba(102, 221, 255, 0.1);
  border-radius: 3px;
  overflow: hidden;
}

.env-progress {
  height: 100%;
  background: linear-gradient(90deg, #66ddff, rgba(102, 221, 255, 0.6));
  border-radius: 3px;
  transition: width 1s ease;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.5);
}

.system-status {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.status-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 0;
  border-bottom: 1px solid rgba(102, 221, 255, 0.1);
}

.status-item:last-child {
  border-bottom: none;
}

.status-label {
  font-size: 14px;
  color: rgba(102, 221, 255, 0.7);
}

.status-value {
  display: flex;
  align-items: center;
  gap: 10px;
}

.status-text {
  font-size: 16px;
  font-weight: 700;
  color: #66ddff;
}

.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.status-indicator.good {
  background: #66ddff;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.8);
}

.status-indicator.normal {
  background: #ffc107;
  box-shadow: 0 0 10px rgba(255, 193, 7, 0.8);
}

.status-indicator.warning {
  background: #ff6b6b;
  box-shadow: 0 0 10px rgba(255, 107, 107, 0.8);
}

/* 用户资料样式 */
.user-profile {
  display: flex;
  align-items: center;
  gap: 15px;
  padding-right: 10px;
  min-width: 200px; /* 确保有足够宽度 */
  justify-content: flex-end;
}

.user-info {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  text-align: right;
  white-space: nowrap; /* 防止文字换行 */
}

.user-name {
  font-size: 16px;
  font-weight: 700;
  color: #66ddff;
  text-shadow: 0 0 8px rgba(102, 221, 255, 0.6);
  letter-spacing: 0.5px;
  margin-bottom: 4px;
}

.user-role {
  font-size: 12px;
  color: rgba(102, 221, 255, 0.9);
  background: rgba(102, 221, 255, 0.15);
  padding: 2px 8px;
  border-radius: 4px;
  border: 1px solid rgba(102, 221, 255, 0.3);
  white-space: nowrap; /* 强制不换行 */
  display: inline-block; /* 确保 padding 生效且不换行 */
}

.user-avatar {
  position: relative;
  width: 48px;
  height: 48px;
  display: flex;
  justify-content: center;
  align-items: center;
}

.avatar-circle {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: rgba(102, 221, 255, 0.1);
  border: 2px solid rgba(102, 221, 255, 0.5);
  overflow: hidden;
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 2;
  box-shadow: 0 0 15px rgba(102, 221, 255, 0.3);
}

.avatar-circle img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-text {
  font-size: 16px;
  font-weight: 700;
  color: #66ddff;
}

.avatar-ring {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  border: 1px dashed rgba(102, 221, 255, 0.4);
  animation: spin-slow 10s linear infinite;
}

@keyframes spin-slow {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* 退出按钮样式 */
.logout-btn {
  margin-left: 20px;
  width: 40px;
  height: 40px;
  border: 1px solid rgba(102, 221, 255, 0.3);
  background: rgba(102, 221, 255, 0.1);
  border-radius: 50%;
  color: #66ddff;
  font-size: 18px;
  cursor: pointer;
  display: flex;
  justify-content: center;
  align-items: center;
  transition: all 0.3s ease;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.1);
}

.logout-btn:hover {
  background: rgba(102, 221, 255, 0.3);
  border-color: #66ddff;
  box-shadow: 0 0 15px rgba(102, 221, 255, 0.5);
  transform: scale(1.1);
}

.logout-icon {
  display: block;
  line-height: 1;
}

/* 响应式设计 */
@media (max-width: 1400px) {
  .top-metrics {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .visualization-area {
    grid-template-columns: 1fr;
  }
  
  .bottom-panels {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .dashboard-header {
    flex-direction: column;
    gap: 15px;
    text-align: center;
  }
  
  .header-left,
  .header-center,
  .header-right {
    justify-content: center;
  }
  
  .top-metrics {
    grid-template-columns: 1fr;
  }
}
</style>

<style>
/* Markdown 内容样式修复 - 全局样式 (非 scoped) 以避免 ::v-deep 问题 */
.chat-message .bubble ul,
.chat-message .bubble ol {
  margin: 5px 0 10px 0;
  padding-left: 24px;
  list-style-position: outside;
}

.chat-message .bubble ul {
  list-style-type: disc;
}

.chat-message .bubble ol {
  list-style-type: decimal;
}

.chat-message .bubble li {
  margin-bottom: 4px;
  line-height: 1.5;
}

.chat-message .bubble p {
  margin: 0 0 8px 0;
}

.chat-message .bubble p:last-child {
  margin-bottom: 0;
}

.chat-message .bubble h1,
.chat-message .bubble h2,
.chat-message .bubble h3 {
  margin: 12px 0 6px 0;
  font-weight: bold;
  font-size: 1.1em;
  line-height: 1.3;
  color: #fff;
}

.chat-message .bubble strong {
  font-weight: bold;
  color: #fff;
}

.chat-message .bubble code {
  background: rgba(0, 0, 0, 0.3);
  padding: 2px 4px;
  border-radius: 3px;
  font-family: monospace;
  color: #ffeb3b;
}
</style>
