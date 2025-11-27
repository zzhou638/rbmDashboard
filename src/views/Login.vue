<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <h1>绿色金融决策仪表板</h1>
      </div>
      <form class="login-form" @submit.prevent="handleLogin">
        <div class="form-group">
          <label for="account" style="text-align: left;">账号</label>
          <input
            id="account"
            v-model="loginForm.account"
            type="text"
            placeholder="请输入账号"
            required
          />
        </div>
        <div class="form-group">
          <label for="password" style="text-align: left;">密码</label>
          <input
            id="password"
            v-model="loginForm.password"
            type="password"
            placeholder="请输入密码"
            required
          />
        </div>
        <div class="form-actions">
          <button type="submit" class="login-btn" :disabled="loading">
            {{ loading ? '登录中...' : '登录' }}
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
  background: linear-gradient(135deg, #a8e6cf 0%, #ffffff 100%);
}

.login-box {
  width: 100%;
  max-width: 400px;
  padding: 40px;
  background: white;
  border-radius: 10px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
}

.login-header {
  text-align: center;
  margin-bottom: 30px;
}

.login-header h1 {
  color: #2c3e50;
  font-size: 24px;
  font-weight: 600;
  margin: 0;
}

.login-form {
  width: 100%;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  color: #2c3e50;
  font-weight: 500;
  font-size: 14px;
}

.form-group input {
  width: 100%;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 5px;
  font-size: 14px;
  box-sizing: border-box;
  transition: border-color 0.3s;
}

.form-group input:focus {
  outline: none;
  border-color: #667eea;
}

.form-actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 30px;
}

.login-btn {
  width: 100%;
  padding: 12px;
  background: #2c3e50;
  color: white;
  border: none;
  border-radius: 5px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.3s;
}

.login-btn:hover {
  background: #34495e;
}

.login-btn:active {
  background: #1a252f;
}

.login-btn:disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

.error-text {
  margin-top: 12px;
  color: #e74c3c;
  font-size: 14px;
  text-align: center;
}

.forgot-password-btn {
  width: 100%;
  padding: 10px;
  background: transparent;
  color: #667eea;
  border: none;
  font-size: 14px;
  cursor: pointer;
  text-decoration: underline;
  transition: color 0.3s;
}

.forgot-password-btn:hover {
  color: #764ba2;
}
</style>

