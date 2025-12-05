<template>
  <div class="login-container">
    <!-- 数字孪生背景效果 -->
    <div class="background-layers">
      <div class="grid-layer"></div>
      <div class="scan-line"></div>
      <!-- 新增背景元素 -->
      <div class="particles">
        <div class="particle" v-for="n in 20" :key="n"></div>
      </div>
      <div class="tech-ring"></div>
    </div>

    <div class="login-box">
      <!-- 装饰角标 -->
      <div class="corner-decoration top-left"></div>
      <div class="corner-decoration top-right"></div>
      <div class="corner-decoration bottom-left"></div>
      <div class="corner-decoration bottom-right"></div>
      
      <div class="login-header">
        <div class="title-frame">
          <div class="logo-title">绿色金融决策仪表板</div>
          <div class="logo-subtitle-en">GREEN FINANCE DECISION DASHBOARD</div>
        </div>
      </div>
      <form class="login-form" @submit.prevent="handleLogin">
        <div class="form-group">
          <label for="account">账号</label>
          <div class="input-wrapper">
            <input
              id="account"
              v-model="loginForm.account"
              type="text"
              placeholder="请输入账号"
              required
            />
            <div class="input-border"></div>
          </div>
        </div>
        <div class="form-group">
          <label for="password">密码</label>
          <div class="input-wrapper">
            <input
              id="password"
              v-model="loginForm.password"
              type="password"
              placeholder="请输入密码"
              required
            />
            <div class="input-border"></div>
          </div>
        </div>
        <div class="form-actions">
          <button type="submit" class="login-btn" :disabled="loading">
            <span class="btn-text">{{ loading ? '登录中...' : '登 录' }}</span>
            <div class="btn-glow"></div>
          </button>
          <button type="button" class="forgot-password-btn" @click="handleForgotPassword">
            忘记密码
          </button>
        </div>
        <p v-if="errorMessage" class="error-text">{{ errorMessage }}</p>
      </form>
    </div>
  </div>
</template>

<script>
import { http } from '@/api/api'
export default {
  name: 'LoginPage',
  data() {
    return {
      loginForm: {
        account: '',
        password: ''
      },
      loading: false,
      errorMessage: ''
    }
  },
  methods: {
    async handleLogin() {
      if (this.loading) return
      const accountId = (this.loginForm.account || '').trim()
      const password = (this.loginForm.password || '').trim()
      if (!accountId || !password) {
        this.errorMessage = '请输入账号和密码'
        return
      }
      this.errorMessage = ''
      this.loading = true
      try {
        const response = await http.post(
          'user/login',
          { accountId, password }
        )
        const userInfo = response?.data || {}
        localStorage.setItem('userInfo', JSON.stringify({ ...userInfo, accountId }))
        this.$router.replace('/home')
      } catch (error) {
        const status = error?.response?.status
        const message = error?.response?.data
        if (status === 400) {
          this.errorMessage = typeof message === 'string' ? message : '用户名或密码错误'
        } else if (status === 401) {
          this.errorMessage = typeof message === 'string' ? message : '登录已过期，请重新登录'
          localStorage.removeItem('userInfo')
        } else if (status === 403) {
          if (typeof message === 'string' && message.includes('NotInitialize')) {
            this.errorMessage = '首次登录，请先完善信息'
            this.$router.replace('/profile/setup')
          } else {
            this.errorMessage = '暂无权限访问'
          }
        } else {
          this.errorMessage = '登录失败，请稍后再试'
          console.error('[login] error:', error)
        }
      } finally {
        this.loading = false
      }
    },
    handleForgotPassword() {
      // 忘记密码逻辑处理
      console.log('忘记密码')
      // 这里可以跳转到忘记密码页面或显示提示
      alert('忘记密码功能')
    }
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  margin: 0;
  padding: 0;
  background: #000000;
  position: relative;
  overflow: hidden;
  font-family: 'Arial', 'Microsoft YaHei', sans-serif;
}

/* 背景图层 */
.background-layers {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
  pointer-events: none;
  background: radial-gradient(circle at center, #0a1a2a 0%, #000000 100%);
}

.grid-layer {
  position: absolute;
  width: 100%;
  height: 100%;
  background-image: 
    linear-gradient(rgba(102, 221, 255, 0.08) 1px, transparent 1px),
    linear-gradient(90deg, rgba(102, 221, 255, 0.08) 1px, transparent 1px);
  background-size: 50px 50px;
  opacity: 0.5;
  transform: perspective(500px) rotateX(60deg) translateY(-100px) scale(2);
  transform-origin: top center;
  animation: grid-move 20s linear infinite;
}

@keyframes grid-move {
  0% { transform: perspective(500px) rotateX(60deg) translateY(0) scale(2); }
  100% { transform: perspective(500px) rotateX(60deg) translateY(50px) scale(2); }
}

.scan-line {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 3px;
  background: linear-gradient(90deg, transparent, rgba(102, 221, 255, 0.8), transparent);
  animation: scan 5s linear infinite;
  box-shadow: 0 0 15px rgba(102, 221, 255, 0.6);
}

/* 粒子效果 */
.particles {
  position: absolute;
  width: 100%;
  height: 100%;
}

.particle {
  position: absolute;
  width: 2px;
  height: 2px;
  background: #66ddff;
  border-radius: 50%;
  opacity: 0;
  animation: float-up 10s infinite linear;
}

.particle:nth-child(odd) {
  background: #ffffff;
}

/* 生成随机位置和动画延迟 */
.particle:nth-child(1) { left: 10%; animation-duration: 8s; animation-delay: 0s; }
.particle:nth-child(2) { left: 20%; animation-duration: 12s; animation-delay: 2s; }
.particle:nth-child(3) { left: 30%; animation-duration: 7s; animation-delay: 4s; }
.particle:nth-child(4) { left: 40%; animation-duration: 11s; animation-delay: 1s; }
.particle:nth-child(5) { left: 50%; animation-duration: 9s; animation-delay: 3s; }
.particle:nth-child(6) { left: 60%; animation-duration: 13s; animation-delay: 5s; }
.particle:nth-child(7) { left: 70%; animation-duration: 8s; animation-delay: 2s; }
.particle:nth-child(8) { left: 80%; animation-duration: 10s; animation-delay: 4s; }
.particle:nth-child(9) { left: 90%; animation-duration: 12s; animation-delay: 1s; }
.particle:nth-child(10) { left: 15%; animation-duration: 9s; animation-delay: 3s; }
.particle:nth-child(11) { left: 25%; animation-duration: 11s; animation-delay: 0s; }
.particle:nth-child(12) { left: 35%; animation-duration: 8s; animation-delay: 2s; }
.particle:nth-child(13) { left: 45%; animation-duration: 12s; animation-delay: 4s; }
.particle:nth-child(14) { left: 55%; animation-duration: 7s; animation-delay: 1s; }
.particle:nth-child(15) { left: 65%; animation-duration: 10s; animation-delay: 3s; }
.particle:nth-child(16) { left: 75%; animation-duration: 13s; animation-delay: 5s; }
.particle:nth-child(17) { left: 85%; animation-duration: 9s; animation-delay: 2s; }
.particle:nth-child(18) { left: 95%; animation-duration: 11s; animation-delay: 4s; }
.particle:nth-child(19) { left: 5%; animation-duration: 8s; animation-delay: 1s; }
.particle:nth-child(20) { left: 50%; animation-duration: 12s; animation-delay: 6s; }

@keyframes float-up {
  0% { transform: translateY(100vh); opacity: 0; }
  20% { opacity: 0.8; }
  80% { opacity: 0.8; }
  100% { transform: translateY(-10vh); opacity: 0; }
}

/* 科技圆环 */
.tech-ring {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 600px;
  height: 600px;
  border: 1px solid rgba(102, 221, 255, 0.1);
  border-radius: 50%;
  pointer-events: none;
}

.tech-ring::before {
  content: '';
  position: absolute;
  top: -10px;
  left: -10px;
  right: -10px;
  bottom: -10px;
  border: 1px dashed rgba(102, 221, 255, 0.2);
  border-radius: 50%;
  animation: rotate-ring 30s linear infinite;
}

.tech-ring::after {
  content: '';
  position: absolute;
  top: 50px;
  left: 50px;
  right: 50px;
  bottom: 50px;
  border: 2px solid rgba(102, 221, 255, 0.05);
  border-radius: 50%;
  border-top-color: rgba(102, 221, 255, 0.3);
  border-bottom-color: rgba(102, 221, 255, 0.3);
  animation: rotate-ring-reverse 20s linear infinite;
}

@keyframes rotate-ring {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

@keyframes rotate-ring-reverse {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(-360deg); }
}

.login-box {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 420px;
  padding: 50px 40px;
  background: rgba(10, 40, 60, 0.6);
  border: 1px solid rgba(102, 221, 255, 0.2);
  box-shadow: 0 0 50px rgba(0, 0, 0, 0.8), inset 0 0 30px rgba(102, 221, 255, 0.05);
  backdrop-filter: blur(12px);
}

/* 四角装饰 */
.corner-decoration {
  position: absolute;
  width: 20px;
  height: 20px;
  border-color: #66ddff;
  border-style: solid;
  transition: all 0.3s ease;
}

.top-left {
  top: -1px;
  left: -1px;
  border-width: 2px 0 0 2px;
}

.top-right {
  top: -1px;
  right: -1px;
  border-width: 2px 2px 0 0;
}

.bottom-left {
  bottom: -1px;
  left: -1px;
  border-width: 0 0 2px 2px;
}

.bottom-right {
  bottom: -1px;
  right: -1px;
  border-width: 0 2px 2px 0;
}

/* 悬停时角标动画 */
.login-box:hover .corner-decoration {
  width: 30px;
  height: 30px;
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.5);
}

.login-header {
  text-align: center;
  margin-bottom: 40px;
}

.logo-title {
  font-size: 28px;
  font-weight: 800;
  background: linear-gradient(180deg, #ffffff 0%, #66ddff 100%);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  text-shadow: 0 0 20px rgba(102, 221, 255, 0.4);
  letter-spacing: 4px;
  margin-bottom: 8px;
}

.logo-subtitle-en {
  font-size: 10px;
  color: rgba(102, 221, 255, 0.6);
  letter-spacing: 2px;
  text-transform: uppercase;
}

.login-form {
  width: 100%;
}

.form-group {
  margin-bottom: 25px;
}

.form-group label {
  display: block;
  margin-bottom: 10px;
  color: #66ddff;
  font-weight: 500;
  font-size: 14px;
  text-align: left;
  letter-spacing: 1px;
}

.input-wrapper {
  position: relative;
}

.form-group input {
  width: 100%;
  padding: 12px 15px;
  background: rgba(0, 0, 0, 0.3);
  border: 1px solid rgba(102, 221, 255, 0.2);
  border-radius: 2px;
  font-size: 14px;
  color: #fff;
  box-sizing: border-box;
  transition: all 0.3s;
  outline: none;
}

.form-group input::placeholder {
  color: rgba(255, 255, 255, 0.3);
}

.form-group input:focus {
  border-color: #66ddff;
  background: rgba(102, 221, 255, 0.05);
  box-shadow: 0 0 10px rgba(102, 221, 255, 0.2);
}

.form-actions {
  display: flex;
  flex-direction: column;
  gap: 15px;
  margin-top: 40px;
}

.login-btn {
  position: relative;
  width: 100%;
  padding: 14px;
  background: linear-gradient(90deg, rgba(102, 221, 255, 0.1), rgba(102, 221, 255, 0.2));
  color: #66ddff;
  border: 1px solid #66ddff;
  border-radius: 2px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.3s;
  letter-spacing: 4px;
  text-transform: uppercase;
}

.login-btn:hover:not(:disabled) {
  background: rgba(102, 221, 255, 0.3);
  box-shadow: 0 0 20px rgba(102, 221, 255, 0.4);
  text-shadow: 0 0 5px #66ddff;
}

.login-btn:disabled {
  cursor: not-allowed;
  opacity: 0.5;
  border-color: #ccc;
  color: #ccc;
}

.forgot-password-btn {
  width: 100%;
  padding: 5px;
  background: transparent;
  color: rgba(102, 221, 255, 0.6);
  border: none;
  font-size: 12px;
  cursor: pointer;
  transition: color 0.3s;
}

.forgot-password-btn:hover {
  color: #66ddff;
  text-decoration: underline;
}

.error-text {
  margin-top: 15px;
  color: #ff4d4f;
  font-size: 14px;
  text-align: center;
  text-shadow: 0 0 5px rgba(255, 77, 79, 0.5);
}
</style>

