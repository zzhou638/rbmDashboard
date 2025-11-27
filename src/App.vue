<template>
  <div id="app" :class="{ 'login-page': $route.path === '/', 'dashboard-page': $route.path === '/home' }">
    <router-view/>
  </div>
</template>

<script>
export default {
  name: 'App'
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  margin: 0;
  padding: 0;
}

#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}

#app.login-page,
#app.dashboard-page {
  margin-top: 0;
}

#app:not(.login-page):not(.dashboard-page) {
  margin-top: 60px;
}
</style>
