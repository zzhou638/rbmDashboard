<template>
  <div v-if="visible" class="factory-modal">
    <div class="modal-backdrop" @click="close"></div>
    <div class="factory-card">
      <div class="card-header">
        <h3 class="card-title">工厂详细信息</h3>
        <button class="close-btn" @click="close">×</button>
      </div>
      
      <div v-if="loading" class="card-body loading">
        <div class="spinner"></div>
        <p>加载中...</p>
      </div>
      
      <div v-else-if="error" class="card-body error">
        <p>{{ error }}</p>
      </div>
      
      <div v-else-if="factoryInfo" class="card-body">
        <!-- 头部大标题区域 -->
        <div class="company-hero">
          <div class="company-title-row">
            <h2 class="company-name">{{ factoryInfo.companyName }}</h2>
            <span class="status-badge" :class="statusClass">{{ factoryInfo.companyStatus || '暂无' }}</span>
          </div>
          <div v-if="factoryInfo.stockCode" class="stock-info">
            <span class="tag">股票代码</span>
            <span class="code">{{ factoryInfo.stockCode }}</span>
          </div>
        </div>

        <div class="divider"></div>

        <div class="info-grid">
          <div class="info-item">
            <span class="label">法定代表人</span>
            <span class="value highlight">{{ factoryInfo.legalRepresentative || '暂无' }}</span>
          </div>
          
          <div class="info-item">
            <span class="label">注册资本</span>
            <span class="value highlight">{{ formatMoney(factoryInfo.registeredCapital) }}</span>
          </div>

          <div class="info-item">
            <span class="label">成立日期</span>
            <span class="value">{{ factoryInfo.registrationDate || '暂无' }}</span>
          </div>

          <div class="info-item">
            <span class="label">统一社会信用代码</span>
            <span class="value code-font">{{ factoryInfo.creditCode }}</span>
          </div>

          <div class="info-item">
            <span class="label">企业类型</span>
            <span class="value">{{ factoryInfo.companyType || '暂无' }}</span>
          </div>

          <div class="info-item">
            <span class="label">所在区域</span>
            <span class="value">{{ factoryInfo.city }} <span class="separator">/</span> {{ factoryInfo.district }}</span>
          </div>

          <div class="info-item">
            <span class="label">联系电话</span>
            <span class="value">{{ factoryInfo.publicPhone || '暂无' }}</span>
          </div>

          <div class="info-item">
            <span class="label">电子邮箱</span>
            <span class="value">{{ factoryInfo.publicEmail || '暂无' }}</span>
          </div>

          <div class="info-item full-width">
            <span class="label">企业地址</span>
            <span class="value address-text">{{ factoryInfo.companyAddress }}</span>
          </div>
          
          <div v-if="factoryInfo.businessScope" class="info-item full-width">
            <span class="label">经营范围</span>
            <span class="value text-content">{{ factoryInfo.businessScope }}</span>
          </div>

          <div v-if="factoryInfo.formerNames" class="info-item full-width footer-info">
            <span class="label">曾用名</span>
            <span class="value">{{ factoryInfo.formerNames }}</span>
          </div>

          <div v-if="factoryInfo.newName" class="info-item full-width footer-info">
            <span class="label">最新名称</span>
            <span class="value">{{ factoryInfo.newName }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { http } from '@/api/api'

export default {
  name: 'FactoryInfoCard',
  data() {
    return {
      visible: false,
      loading: false,
      error: null,
      factoryInfo: null,
      position: { x: 0, y: 0 }
    }
  },
  computed: {
    statusClass() {
      if (!this.factoryInfo) return ''
      const status = this.factoryInfo.companyStatus
      if (status === '存续' || status === '在营') return 'active'
      if (status === '注销' || status === '吊销') return 'inactive'
      return ''
    }
  },
  methods: {
    formatMoney(value) {
      if (!value && value !== 0) return '暂无'
      if (typeof value === 'number') {
        return `${(value / 10000).toFixed(2)} 万元`
      }
      return value
    },
    async show(factoryUuid) {
      this.position = { x: window.innerWidth / 2, y: window.innerHeight / 2 }
      this.visible = true
      this.loading = true
      this.error = null
      this.factoryInfo = null
      
      try {
        console.log('[FactoryInfoCard] 查询工厂:', factoryUuid)
        
        // 使用新的 GET /api/factories/detail/{uuid} 接口
        const response = await http.get(`factories/detail/${factoryUuid}`)
        
        if (response.data) {
          this.factoryInfo = response.data
          console.log('[FactoryInfoCard] 工厂信息:', this.factoryInfo)
        } else {
          throw new Error('未找到该工厂信息')
        }
      } catch (err) {
        console.error('[FactoryInfoCard] 获取工厂信息失败:', err)
        this.error = err.response?.data?.error || err.message || '获取工厂信息失败'
      } finally {
        this.loading = false
      }
    },
    close() {
      this.visible = false
      this.factoryInfo = null
      this.error = null
    }
  }
}
</script>

<style scoped>
.factory-modal {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
}

.modal-backdrop {
  position: absolute;
  inset: 0;
  background: rgba(2, 6, 23, 0.85);
  backdrop-filter: blur(8px);
  animation: fadeBackdrop 0.3s ease;
}

@keyframes fadeBackdrop {
  from { opacity: 0; }
  to { opacity: 1; }
}

.factory-card {
  position: relative;
  background: rgba(13, 26, 60, 0.95);
  border: 1px solid rgba(75, 166, 240, 0.4);
  box-shadow: 0 0 40px rgba(0, 0, 0, 0.6), 0 0 20px rgba(75, 166, 240, 0.15) inset;
  border-radius: 12px;
  width: min(800px, 94vw);
  max-height: 85vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  animation: popIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes popIn {
  from { transform: translateY(30px) scale(0.95); opacity: 0; }
  to { transform: translateY(0) scale(1); opacity: 1; }
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  border-bottom: 1px solid rgba(75, 166, 240, 0.2);
  background: linear-gradient(90deg, rgba(75, 166, 240, 0.1), transparent);
}

.card-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #66ddff;
  letter-spacing: 1px;
  text-shadow: 0 0 8px rgba(102, 221, 255, 0.4);
}

.close-btn {
  background: transparent;
  border: none;
  color: rgba(154, 215, 255, 0.6);
  font-size: 24px;
  cursor: pointer;
  padding: 4px;
  line-height: 1;
  border-radius: 4px;
  transition: all 0.2s ease;
}

.close-btn:hover {
  color: #fff;
  background: rgba(255, 255, 255, 0.1);
}

.card-body {
  padding: 24px;
  overflow-y: auto;
  flex: 1;
}

/* 滚动条样式 */
.card-body::-webkit-scrollbar {
  width: 6px;
}
.card-body::-webkit-scrollbar-track {
  background: rgba(0, 0, 0, 0.2);
}
.card-body::-webkit-scrollbar-thumb {
  background: rgba(75, 166, 240, 0.3);
  border-radius: 3px;
}
.card-body::-webkit-scrollbar-thumb:hover {
  background: rgba(75, 166, 240, 0.5);
}

/* 头部信息区域 */
.company-hero {
  margin-bottom: 20px;
}

.company-title-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
  flex-wrap: wrap;
}

.company-name {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
  color: #fff;
  line-height: 1.4;
  text-shadow: 0 0 15px rgba(75, 166, 240, 0.3);
}

.status-badge {
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
  border: 1px solid rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.8);
}

.status-badge.active {
  background: rgba(0, 255, 150, 0.15);
  color: #00ff96;
  border-color: rgba(0, 255, 150, 0.4);
  box-shadow: 0 0 8px rgba(0, 255, 150, 0.2);
}

.status-badge.inactive {
  background: rgba(255, 80, 80, 0.15);
  color: #ff5050;
  border-color: rgba(255, 80, 80, 0.4);
}

.stock-info {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}

.stock-info .tag {
  color: rgba(154, 215, 255, 0.6);
}

.stock-info .code {
  color: #66ddff;
  font-family: 'Courier New', monospace;
  font-weight: 600;
  background: rgba(75, 166, 240, 0.1);
  padding: 0 6px;
  border-radius: 2px;
}

.divider {
  height: 1px;
  background: linear-gradient(90deg, rgba(75, 166, 240, 0.3), transparent);
  margin-bottom: 24px;
}

/* 网格布局 */
.info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 20px 32px;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.info-item.full-width {
  grid-column: 1 / -1;
}

.label {
  font-size: 12px;
  color: rgba(154, 215, 255, 0.5);
  letter-spacing: 0.5px;
}

.value {
  font-size: 15px;
  color: #e7f7ff;
  line-height: 1.5;
  word-break: break-all;
}

.value.highlight {
  color: #fff;
  font-weight: 600;
  font-size: 16px;
}

.value.code-font {
  font-family: 'Courier New', monospace;
  letter-spacing: 1px;
  color: #aaddff;
}

.value.address-text {
  color: #d0eaff;
}

.value.text-content {
  color: rgba(231, 247, 255, 0.8);
  font-size: 14px;
  background: rgba(0, 0, 0, 0.2);
  padding: 12px;
  border-radius: 6px;
  border: 1px solid rgba(75, 166, 240, 0.1);
}

.separator {
  color: rgba(154, 215, 255, 0.3);
  margin: 0 4px;
}

.footer-info {
  margin-top: 8px;
  padding-top: 16px;
  border-top: 1px dashed rgba(75, 166, 240, 0.2);
}

.source-text {
  font-size: 13px;
  color: rgba(154, 215, 255, 0.5);
  font-style: italic;
}

/* 加载和错误状态 */
.card-body.loading,
.card-body.error {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 300px;
  color: #9ad7ff;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(75, 166, 240, 0.2);
  border-top-color: #66ddff;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 640px) {
  .info-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }
  
  .company-name {
    font-size: 18px;
  }
}
</style>
