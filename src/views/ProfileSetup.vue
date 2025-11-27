<template>
  <div class="setup-container">
    <div class="setup-box">
      <h2>完善首次登录信息</h2>
      <p class="setup-desc">
        请设置新的登录密码，并完善个人信息。提交成功后将自动跳转首页。
      </p>
      <form class="setup-form" @submit.prevent="handleSubmit">
        <div class="form-row">
          <label for="currentPassword">当前密码</label>
          <div class="input-wrap">
            <input
              id="currentPassword"
              v-model="form.currentPassword"
              type="password"
              placeholder="请输入初始密码"
              required
            />
          </div>
        </div>
        <div class="form-row">
          <label for="newPassword">新密码</label>
          <div class="input-wrap">
            <input
              id="newPassword"
              v-model="form.newPassword"
              type="password"
              placeholder="请输入新密码"
              required
            />
          </div>
        </div>
        <div class="form-row">
          <label for="gender">性别</label>
          <div class="input-wrap">
            <select id="gender" v-model="form.gender">
              <option value="">请选择</option>
              <option value="男">男</option>
              <option value="女">女</option>
              <option value="其他">其他</option>
            </select>
          </div>
        </div>
        <div class="form-row">
          <label for="phone">手机号</label>
          <div class="input-wrap">
            <input
              id="phone"
              v-model="form.phone"
              type="tel"
              placeholder="请输入手机号"
            />
          </div>
        </div>
        <div class="form-row">
          <label for="bio">个人简介</label>
          <div class="input-wrap">
            <textarea
              id="bio"
              v-model="form.bio"
              rows="4"
              placeholder="简要介绍您的工作或研究方向"
            ></textarea>
          </div>
        </div>
        <button type="submit" class="submit-btn" :disabled="loading">
          {{ loading ? '提交中...' : '提交' }}
        </button>
        <p v-if="errorMessage" class="error-text">{{ errorMessage }}</p>
        <p v-if="successMessage" class="success-text">{{ successMessage }}</p>
      </form>
    </div>
  </div>
</template>

<script>
import { http } from '@/api/api'

export default {
  name: 'ProfileSetup',
  data() {
    return {
      form: {
        currentPassword: '',
        newPassword: '',
        gender: '',
        phone: '',
        bio: ''
      },
      loading: false,
      errorMessage: '',
      successMessage: ''
    }
  },
  methods: {
    async handleSubmit() {
      if (this.loading) return
      if (!this.form.currentPassword || !this.form.newPassword) {
        this.errorMessage = '请完整填写当前密码和新密码'
        return
      }
      this.loading = true
      this.errorMessage = ''
      this.successMessage = ''
      const payload = {
        currentPassword: this.form.currentPassword,
        newPassword: this.form.newPassword
      }
      if (this.form.gender) payload.gender = this.form.gender
      if (this.form.phone) payload.phone = this.form.phone
      if (this.form.bio) payload.bio = this.form.bio
      try {
        const res = await http.post(
          'user/update-first-login',
          payload
        )
        this.successMessage = '信息更新成功，正在跳转首页...'
        const stored = localStorage.getItem('userInfo')
        const parsed = stored ? JSON.parse(stored) : {}
        localStorage.setItem('userInfo', JSON.stringify({ ...parsed, initialized: true }))
        setTimeout(() => {
          this.$router.replace('/home')
        }, 1200)
        console.log('[ProfileSetup] response:', res.data)
      } catch (error) {
        const status = error?.response?.status
        const message = error?.response?.data
        if (status === 400) {
          this.errorMessage = typeof message === 'string' ? message : '信息填写有误，请检查'
        } else if (status === 401) {
          this.errorMessage = typeof message === 'string' ? message : '登录已过期，请重新登录'
          localStorage.removeItem('userInfo')
          setTimeout(() => this.$router.replace('/'), 1200)
        } else if (status === 403) {
          this.errorMessage = '当前会话权限不足，请重新登录后再试'
        } else {
          this.errorMessage = '信息更新失败，请稍后重试'
          console.error('[ProfileSetup] error:', error)
        }
      } finally {
        this.loading = false
      }
    }
  }
}
</script>

<style scoped>
.setup-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: radial-gradient(circle at top, #0f172a 0%, #020617 60%);
  padding: 20px;
  box-sizing: border-box;
}

.setup-box {
  width: 100%;
  max-width: 520px;
  padding: 36px;
  background: rgba(15, 23, 42, 0.85);
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(2, 6, 23, 0.6);
  border: 1px solid rgba(94, 234, 212, 0.25);
  color: #e2e8f0;
}

.setup-box h2 {
  margin: 0 0 10px 0;
  font-weight: 600;
  text-align: center;
  color: #f8fafc;
}

.setup-desc {
  text-align: center;
  font-size: 14px;
  color: #94a3b8;
  margin-bottom: 24px;
}

.setup-form {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.form-row {
  display: flex;
  align-items: center;
  gap: 18px;
}

.input-wrap {
  flex: 1;
}

label {
  flex: 0 0 120px;
  margin-bottom: 0;
  font-size: 14px;
  font-weight: 500;
  color: #cbd5f5;
  text-align: right;
}

input,
select,
textarea {
  width: 100%;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid rgba(148, 163, 184, 0.3);
  background: rgba(15, 23, 42, 0.8);
  color: #f8fafc;
  font-size: 14px;
  box-sizing: border-box;
  transition: border-color 0.3s, box-shadow 0.3s;
}

input:focus,
select:focus,
textarea:focus {
  outline: none;
  border-color: rgba(94, 234, 212, 0.7);
  box-shadow: 0 0 0 1px rgba(94, 234, 212, 0.4);
}

.submit-btn {
  width: 100%;
  padding: 12px;
  border: none;
  border-radius: 8px;
  background: linear-gradient(135deg, #22d3ee, #3b82f6);
  color: #0f172a;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.3s, transform 0.2s;
}

.submit-btn:disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

.submit-btn:hover:not(:disabled) {
  opacity: 0.9;
  transform: translateY(-1px);
}

.error-text {
  color: #f87171;
  text-align: center;
  font-size: 14px;
}

.success-text {
  color: #34d399;
  text-align: center;
  font-size: 14px;
}

@media (max-width: 520px) {
  .setup-box {
    padding: 24px;
  }

  .form-row {
    flex-direction: column;
    align-items: stretch;
  }

  label {
    text-align: left;
  }
}
</style>


