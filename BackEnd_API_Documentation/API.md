````markdown
# GF 项目 API 接口技术文档

## 文档说明

本文档遵循阿里巴巴开发规范，详细描述了 GF (Green Finance) 项目的 RESTful API 接口信息。

**基础信息：**
- **服务地址**：`http://www.zhougis.cn:8085`
- **API 版本**：v1.0
- **文档更新日期**：2025-11-20
- **技术栈**：Spring Boot 3.1.0 + MySQL 9.3 + JPA/Hibernate
- **前端地址**：`http://www.zhougis.cn:8085`
- **架构模式**：MVC 三层架构（Controller-Service-Repository）

---

## 目录

1. [通用说明](#通用说明)
2. [用户管理接口](#用户管理接口)
3. [管理员接口](#管理员接口)
4. [上市公司信息接口](#上市公司信息接口)
5. [工厂信息接口](#工厂信息接口)
6. [地图数据接口](#地图数据接口)
7. [事实数据表接口](#事实数据表接口)
   - 7.1 [碳排放数据接口](#碳排放数据接口)
   - 7.2 [财务面板数据接口](#财务面板数据接口)
   - 7.3 [环境处罚事件接口](#环境处罚事件接口)
   - 7.4 [环境补助事件接口](#环境补助事件接口)
   - 7.5 [ESG评分接口](#esg评分接口)
   - 7.6 [绿色投资数据接口](#绿色投资数据接口)
   - 7.7 [绿色专利数据接口](#绿色专利数据接口)
   - 7.8 [综合专利数据接口](#综合专利数据接口)
   - 7.9 [污染环保费用接口](#污染环保费用接口)
8. [附录](#附录)

---

## 通用说明

### 1. 认证方式

本系统支持两种认证方式，优先级为：**API Key 认证 > Session 认证**

#### 1.1 API Key 认证（推荐）

通过在请求头中携带 API Key 进行身份验证：

- **请求头名称**：`X-API-Key`
- **认证流程**：
  1. 管理员通过 `/api/admin/generate-api-key` 接口为用户分配 API Key
  2. 客户端在每次请求时携带 `X-API-Key` 请求头
  3. 服务器通过 `ApiKeyAuthService` 验证 API Key 是否存在且有效（`is_valid=true`）

**请求示例：**
```bash
curl -H "X-API-Key: your_api_key_here" \
  http://www.zhougis.cn:8085/api/companies/locations
```

**优点：**
- 无状态认证，适合分布式部署
- 便于第三方系统集成
- 支持长期有效的访问令牌
- 更适合 API 调用场景

**适用场景：**
- 所有查询（GET）接口均支持 API Key 认证
- 适合外部系统接入和数据查询

#### 1.2 Session 认证（传统方式）

通过基于 Cookie 的会话机制进行身份验证：

- **Cookie 名称**：`SESSION_ID`
- **会话有效期**：
  - 首次登录：5分钟（需完善个人信息）
  - 正常登录：2小时
- **认证流程**：
  1. 用户通过登录接口获取会话凭证
  2. 后续请求需携带包含 `SESSION_ID` 的 Cookie
  3. 服务器通过 `UserLoginSessionService` 验证会话有效性

**适用场景：**
- 所有写操作（POST、PUT、DELETE）必须使用 Session 认证
- Web 端用户登录场景

### 2. 接口认证策略

根据阿里巴巴开发规范，系统对不同类型的操作采用不同的认证策略：

| 操作类型 | 认证方式 | 说明 |
|---------|---------|------|
| 查询操作（GET） | API Key 或 Session | 支持双认证，优先使用 API Key |
| 创建操作（POST） | 仅 Session | 需要登录用户身份验证 |
| 更新操作（PUT） | 仅 Session | 需要登录用户身份验证 |
| 删除操作（DELETE） | 仅 Session | 需要登录用户身份验证 |
| 管理员操作 | Session（超级管理员） | 需要特定管理员权限 |

### 3. 响应状态码

遵循 RESTful 标准和阿里巴巴规范：

| 状态码 | 说明 | 使用场景 |
|--------|------|---------|
| 200 | OK - 请求成功 | GET、PUT、DELETE 成功 |
| 201 | Created - 创建成功 | POST 创建资源成功 |
| 400 | Bad Request - 请求参数错误 | 参数验证失败 |
| 401 | Unauthorized - 未授权 | 未登录或 Session/API Key 无效 |
| 403 | Forbidden - 权限不足 | 首次登录未初始化或非管理员操作 |
| 404 | Not Found - 资源不存在 | 查询的资源不存在 |
| 500 | Internal Server Error | 服务器内部错误 |

### 4. 通用响应格式

**成功响应示例：**
```json
{
  "data": {...},
  "message": "success"
}
```

或直接返回数据：
```json
[...]
```

**失败响应示例：**
```json
{
  "error": "错误信息描述"
}
```

或字符串消息：
```
"错误信息描述"
```

### 5. 跨域配置

所有接口均配置了 CORS：
```java
@CrossOrigin(origins = "http://www.zhougis.cn:8085", allowCredentials = "true")
```

- **允许来源**：`http://www.zhougis.cn:8085`
- **支持凭证**：`true`（允许携带 Cookie）

---

## 用户管理接口

**基础路径**：`/api/user`  
**控制器**：`UserController`  
**业务层**：`UserService`, `UserLoginSessionService`, `EmailService`

### 2.1 用户登录

**接口描述**：用户登录接口，验证账号和密码，成功后返回会话凭证和用户资料信息。支持首次登录检测。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/user/login`
- **是否需要认证**：否
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| accountId | String | 是 | 用户账号（邮箱格式） |
| password | String | 是 | 密码（明文，服务端使用 BCrypt 验证） |

**请求示例：**
```json
{
  "accountId": "user@example.com",
  "password": "password123"
}
```

**响应示例：**

成功响应（正常登录）：
```json
{
  "name": "张三",
  "organization": "某某公司",
  "department": "研发部",
  "position": "工程师",
  "bio": "个人简介..."
}
```

**响应头**：
- `Set-Cookie: SESSION_ID=<token>; Path=/; Domain=www.zhougis.cn; Max-Age=7200; HttpOnly`

失败响应（首次登录）：
```
HTTP 403 Forbidden
"NotInitialize"
```

失败响应（账号或密码错误）：
```
HTTP 400 Bad Request
"用户名或密码错误"
```

**业务逻辑：**
1. 根据 accountId 查询用户信息
2. 使用 BCrypt.checkpw() 验证密码
3. 检查 createdAt 和 updatedAt 判断是否首次登录
4. 首次登录：Session 有效期 5 分钟，返回 403
5. 正常登录：Session 有效期 2 小时，返回用户资料

**技术要点：**
- 密码加密：BCrypt
- Session 管理：基于 Redis 或内存
- Cookie 配置：HttpOnly、Secure（生产环境）

---

### 2.2 用户注册

**接口描述**：新用户注册接口，系统自动生成随机密码并通过邮件发送。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/user/register`
- **是否需要认证**：否
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| accountId | String | 是 | 用户账号（必须为有效邮箱格式） |
| name | String | 是 | 用户姓名 |
| organization | String | 是 | 所属机构 |
| department | String | 是 | 部门 |
| position | String | 是 | 职位 |

**请求示例：**
```json
{
  "accountId": "newuser@example.com",
  "name": "李四",
  "organization": "某某大学",
  "department": "计算机学院",
  "position": "研究员"
}
```

**响应示例：**

成功响应：
```
HTTP 200 OK
"Register success."
```

失败响应（邮箱格式错误）：
```
HTTP 400 Bad Request
"AccountId must be a valid email address."
```

失败响应（用户已存在）：
```
HTTP 400 Bad Request
"User already exists."
```

**业务逻辑：**
1. 验证邮箱格式（正则表达式：`^[A-Za-z0-9+_.-]+@(.+)$`）
2. 验证必填字段完整性
3. 检查用户是否已存在
4. 使用 `PasswordGenerator.generateStrongPassword()` 生成随机密码
5. 使用 BCrypt 对密码进行哈希处理
6. 创建 User 和 UserProfile 记录
7. 通过 `EmailService` 发送注册成功邮件（包含密码）

**注意事项：**
- 邮件发送失败不影响注册流程
- 密码通过明文邮件发送，需提示用户首次登录后修改
- 用户默认角色为 "USER"

---

### 2.3 更新首次登录信息

**接口描述**：首次登录用户完善个人信息接口，包括修改密码、性别、手机号、个人简介等。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/user/update-first-login`
- **是否需要认证**：是（Session）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| currentPassword | String | 是 | 当前密码 |
| newPassword | String | 是 | 新密码 |
| gender | String | 否 | 性别 |
| phone | String | 否 | 手机号 |
| bio | String | 否 | 个人简介 |

**请求示例：**
```json
{
  "currentPassword": "old_password",
  "newPassword": "new_password_123",
  "gender": "男",
  "phone": "13800138000",
  "bio": "热爱环保事业"
}
```

**响应示例：**

成功响应：
```
HTTP 200 OK
"信息更新成功"
```

失败响应（未登录）：
```
HTTP 401 Unauthorized
"未登录"
```

失败响应（密码错误）：
```
HTTP 400 Bad Request
"当前密码错误"
```

**业务逻辑：**
1. 从 Cookie 中提取 SESSION_ID
2. 通过 `UserLoginSessionService` 验证会话并获取 accountId
3. 调用 `UserService.updateFirstLoginInfo()` 更新用户信息
4. 更新 User 表的 updatedAt 字段（标记非首次登录）

---

### 2.4 修改密码接口

**接口描述**：用户修改密码接口，通过用户名和旧密码验证身份后，更新为新密码。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/user/change-password`
- **是否需要认证**：否（通过用户名和旧密码验证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| username | String | 是 | 用户名（账号ID） |
| oldPassword | String | 是 | 旧密码（明文） |
| newPassword | String | 是 | 新密码（明文） |

**请求示例：**
```json
{
  "username": "user@example.com",
  "oldPassword": "old_password_123",
  "newPassword": "new_password_456"
}
```

**响应示例：**

成功响应：
```
HTTP 200 OK
"密码修改成功"
```

失败响应（用户名为空）：
```
HTTP 400 Bad Request
"用户名不能为空"
```

失败响应（旧密码为空）：
```
HTTP 400 Bad Request
"旧密码不能为空"
```

失败响应（新密码为空）：
```
HTTP 400 Bad Request
"新密码不能为空"
```

失败响应（用户不存在）：
```
HTTP 400 Bad Request
"用户不存在"
```

失败响应（旧密码错误）：
```
HTTP 400 Bad Request
"旧密码错误"
```

**业务逻辑：**
1. 参数校验：验证用户名、旧密码、新密码不为空
2. 根据用户名从数据库查询用户信息
3. 使用 BCrypt.checkpw() 验证旧密码是否匹配数据库中的密文
4. 验证通过后，使用 BCrypt 对新密码进行哈希加密
5. 更新数据库中的密码字段
6. 返回成功响应

**技术要点：**
- 密码加密：BCrypt（盐值自动生成）
- 密码验证：BCrypt.checkpw(明文, 密文)
- 数据表：`users`（字段：username, password, created_at, updated_at, role）

**安全建议：**
- 建议新密码长度至少 8 位
- 建议包含大小写字母、数字和特殊字符
- 生产环境建议添加密码强度校验
- 建议添加修改密码频率限制

---

### 2.5 密码哈希工具接口

**接口描述**：用于测试的密码哈希工具接口，将明文密码转换为 BCrypt 哈希值。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/user/hash-password`
- **是否需要认证**：否
- **Content-Type**：`text/plain`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| body | String | 是 | 明文密码 |

**响应示例：**

成功响应：
```
HTTP 200 OK
"$2a$10$abcdefghijklmnopqrstuvwxyz..."
```

**注意事项：**
- 此接口仅用于开发测试
- 生产环境应移除或限制访问

---

## 管理员接口

**基础路径**：`/api/admin`  
**控制器**：`ApiKeyAdminController`  
**业务层**：`ApiKeyGenerationService`, `ApiKeyAuthService`  
**超级管理员邮箱**：`zzhou638@connect.hkust-gz.edu.cn`

### 3.1 生成 API Key

**接口描述**：超级管理员为用户生成 API Key 并通过邮件发送。支持 API Key 或 Session 认证管理员身份。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/admin/generate-api-key`
- **是否需要认证**：是（仅超级管理员）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| userName | String | 是 | 用户姓名 |
| email | String | 是 | 用户邮箱（必须为有效邮箱格式） |
| expirationDays | Integer | 否 | API Key 有效天数（默认值由系统配置） |

**请求示例：**
```json
{
  "userName": "张三",
  "email": "zhangsan@example.com",
  "expirationDays": 365
}
```

**响应示例：**

成功响应：
```json
{
  "message": "API Key 生成成功，已尝试发送至用户邮箱。如邮件发送失败，请手动告知用户。",
  "apiKey": "generated_api_key_string",
  "userName": "张三",
  "email": "zhangsan@example.com"
}
```

失败响应（权限不足）：
```
HTTP 403 Forbidden
"权限不足：只有超级管理员才能生成 API Key"
```

失败响应（生成失败）：
```
HTTP 500 Internal Server Error
"API Key 生成失败：<错误详情>"
```

**业务逻辑：**
1. 验证请求者是否为超级管理员（支持 API Key 或 Session 认证）
2. 调用 `ApiKeyGenerationService.generateAndSendApiKey()` 生成 API Key
3. 保存到 `api_access_keys` 表
4. 通过 `EmailService` 发送邮件
5. 返回生成的 API Key（即使邮件发送失败）

**权限验证逻辑：**
- 优先检查 `X-API-Key` 请求头
- 如果存在，验证 API Key 是否有效且属于超级管理员
- 否则，从 Cookie 中提取 SESSION_ID 验证
- 获取用户邮箱，对比是否为超级管理员邮箱

**技术要点：**
- API Key 生成算法：UUID 或自定义加密
- 邮件发送：异步处理，失败不影响生成流程
- 安全性：返回的 API Key 应妥善保管

---

## 上市公司信息接口

**基础路径**：`/api/companies`  
**控制器**：`ListedCompanyController`  
**业务层**：`ListedCompanyService`, `DimCompanyService`  
**数据表**：`listed_company`, `dim_company`

### 4.1 获取所有公司地理位置信息

**接口描述**：获取所有上市公司的地理位置信息（经纬度、名称等）。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/companies/locations`
- **是否需要认证**：是

**请求参数**：无

**响应示例：**
```json
[
  {
    "companyUuid": "uuid-123",
    "fullNameCn": "深圳某某科技股份有限公司",
    "officeLng": 114.05,
    "officeLat": 22.54,
    "stockName": "某某科技",
    "stockCode": "688001",
    "industryName": "计算机、通信和其他电子设备制造业"
  }
]
```

---

### 2.2 根据 UUID 获取公司详细信息

**接口描述**：根据公司唯一标识获取公司详细信息。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/companies/identify/{companyUuid}`
- **是否需要认证**：是

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| companyUuid | String | 是 | 公司唯一标识 |

**请求示例：**
```
GET /api/companies/identify/abc-123-def-456
```

**响应示例：**
```json
{
  "companyUuid": "abc-123-def-456",
  "stockCode": "688001",
  "stockName": "某某科技",
  "fullNameCn": "深圳某某科技股份有限公司",
  "industryName": "计算机、通信和其他电子设备制造业",
  "officeAddress": "广东省深圳市南山区...",
  "officeLng": 114.05,
  "officeLat": 22.54,
  "boardSecretary": "张三",
  "secretaryPhone": "0755-12345678",
  "website": "www.example.com"
}
```

---

### 2.3 精确搜索公司

**接口描述**：根据公司全称精确匹配查询公司信息。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/companies/search/exact`
- **是否需要认证**：是

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | String | 是 | 公司全称（精确匹配） |

**请求示例：**
```
GET /api/companies/search/exact?name=深圳某某科技股份有限公司
```

**响应示例：**
```json
[
  {
    "companyUuid": "abc-123",
    "fullNameCn": "深圳某某科技股份有限公司",
    "stockCode": "688001",
    "industryName": "计算机、通信和其他电子设备制造业"
  }
]
```

---

### 2.4 模糊搜索公司

**接口描述**：根据关键词模糊搜索公司（支持公司名称、股票代码、股票名称）。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/companies/search`
- **是否需要认证**：是

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| keyword | String | 是 | 搜索关键词 |

**请求示例：**
```
GET /api/companies/search?keyword=科技
```

**响应示例：**
```json
[
  {
    "companyUuid": "abc-123",
    "fullNameCn": "深圳某某科技股份有限公司",
    "stockCode": "688001"
  },
  {
    "companyUuid": "def-456",
    "fullNameCn": "广州某某科技有限公司",
    "stockCode": "688002"
  }
]
```

---

### 2.5 按多边形查询公司地点

**接口描述**：根据用户绘制的多边形区域，查询该区域内的所有上市公司地点信息。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/companies/find-companies-by-polygon`
- **是否需要认证**：是
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| coordinates | Array | 是 | 多边形坐标数组，格式：`[[[lng1, lat1], [lng2, lat2], ...]]` |

**请求示例：**
```json
{
  "coordinates": [
    [
      [113.9, 22.5],
      [114.1, 22.5],
      [114.1, 22.6],
      [113.9, 22.6],
      [113.9, 22.5]
    ]
  ]
}
```

**响应示例：**
```json
[
  {
    "companyUuid": "abc-123",
    "fullNameCn": "深圳某某科技股份有限公司",
    "officeLng": 114.05,
    "officeLat": 22.54,
    "stockName": "某某科技",
    "stockCode": "688001"
  }
]
```

**特殊说明：**
- 坐标点 < 2：返回全部企业
- 坐标点 < 3：返回 400 错误（无法形成多边形）
- 坐标点 ≥ 3：执行多边形过滤查询

---

### 2.6 按多边形统计公司数量

**接口描述**：统计指定多边形区域内的公司数量。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/companies/count-companies-by-polygon`
- **是否需要认证**：否（当前版本暂未启用认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| coordinates | Array | 是 | 多边形坐标数组 |

**请求示例：**
```json
{
  "coordinates": [
    [
      [113.9, 22.5],
      [114.1, 22.5],
      [114.1, 22.6],
      [113.9, 22.6],
      [113.9, 22.5]
    ]
  ]
}
```

**响应示例：**
```json
23
```

---

## 公司维度表接口

### 3.1 多条件查询公司信息

**接口描述**：根据多个查询条件组合查询上市公司维度表（`dim_company`）数据。所有参数均为可选，支持灵活组合查询。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/companies/dim-company/search`
- **是否需要认证**：是

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（支持模糊查询） |
| fullNameCn | String | 否 | 公司全称（支持模糊查询） |
| industryName | String | 否 | 行业名称（支持模糊查询） |
| marketType | String | 否 | 市场类型（精确匹配，如：主板/中小板/创业板） |
| exchangeName | String | 否 | 交易所名称（精确匹配） |
| listYear | Integer | 否 | 上市年份（精确匹配） |
| companyStatus | String | 否 | 公司状态（精确匹配） |

**请求示例：**

1. 查询所有公司（不传任何参数）：
```
GET /api/companies/dim-company/search
```

2. 按行业和市场类型查询：
```
GET /api/companies/dim-company/search?industryName=计算机&marketType=创业板
```

3. 按上市年份查询：
```
GET /api/companies/dim-company/search?listYear=2020
```

4. 组合查询：
```
GET /api/companies/dim-company/search?industryName=电子&exchangeName=深圳证券交易所&listYear=2021
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "secShortName": "某某科技",
    "fullNameCn": "深圳某某科技股份有限公司",
    "fullNameEn": "Shenzhen Example Technology Co., Ltd.",
    "industryCode": "C39",
    "industryName": "计算机、通信和其他电子设备制造业",
    "creditCode": "91440300XXXXXXXXXX",
    "legalRepresentative": "张三",
    "companyStatus": "存续",
    "registeredAddress": "广东省深圳市南山区...",
    "officeAddress": "广东省深圳市南山区...",
    "officeLng": 114.05,
    "officeLat": 22.54,
    "marketType": "科创板",
    "exchangeName": "上海证券交易所",
    "firstListedDate": "2020-07-22",
    "listYear": 2020,
    "boardSecretary": "李四",
    "secretaryPhone": "0755-12345678",
    "secretaryEmail": "secretary@example.com",
    "securitiesRepresentative": "王五",
    "registeredCapital": 100000000.00,
    "website": "www.example.com",
    "businessScope": "集成电路设计、开发...",
    "dataSource": "listed_companies_information.xlsx",
    "remark": null
  }
]
```

**特殊说明：**
- 所有参数均为可选
- 如果不传任何参数，将返回所有公司数据
- 字符串类型参数支持模糊匹配（使用 SQL `LIKE` 查询）
- 数值类型和精确类型参数（如 `listYear`、`marketType`）使用精确匹配

---

### 3.2 根据股票代码查询单个公司

**接口描述**：根据股票代码精确查询单个公司的完整信息。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/companies/dim-company/{stockName}`
- **是否需要认证**：是

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |

**请求示例：**
```
GET /api/companies/dim-company/688001
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "secShortName": "某某科技",
  "fullNameCn": "深圳某某科技股份有限公司",
  "fullNameEn": "Shenzhen Example Technology Co., Ltd.",
  "industryCode": "C39",
  "industryName": "计算机、通信和其他电子设备制造业",
  "creditCode": "91440300XXXXXXXXXX",
  "legalRepresentative": "张三",
  "companyStatus": "存续",
  "registeredAddress": "广东省深圳市南山区...",
  "officeAddress": "广东省深圳市南山区...",
  "officeLng": 114.05,
  "officeLat": 22.54,
  "marketType": "科创板",
  "exchangeName": "上海证券交易所",
  "firstListedDate": "2020-07-22",
  "listYear": 2020,
  "boardSecretary": "李四",
  "secretaryPhone": "0755-12345678",
  "secretaryEmail": "secretary@example.com",
  "securitiesRepresentative": "王五",
  "registeredCapital": 100000000.00,
  "website": "www.example.com",
  "businessScope": "集成电路设计、开发...",
  "dataSource": "listed_companies_information.xlsx",
  "remark": null
}
```

未找到响应（404）：
```
HTTP 404 Not Found
```

---

## 地图数据接口

**基础路径**：`/api/map`  
**控制器**：`MapController`  
**业务层**：无（直接读取静态资源）  
**数据来源**：`static/geojson/` 目录下的 GeoJSON 文件

### 6.1 获取粤港澳大湾区 GeoJSON 数据

**接口描述**：根据指定的尺度（scale）参数，获取粤港澳大湾区不同层级的地理边界 GeoJSON 数据，用于地图可视化展示。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/map/gba_boundary`
- **是否需要认证**：是（支持 API Key 或 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| scale | String | 是 | 地理尺度，可选值：`Boundary`（大湾区边界）、`City`（城市级别）、`District`（区县级别）、`Factory`（工厂点位） |

**请求示例：**

1. 获取大湾区整体边界：
```
GET /api/map/gba_boundary?scale=Boundary
```

2. 获取城市级别边界：
```
GET /api/map/gba_boundary?scale=City
```

3. 获取区县级别边界：
```
GET /api/map/gba_boundary?scale=District
```

4. 获取工厂点位数据：
```
GET /api/map/gba_boundary?scale=Factory
```

**响应示例：**

成功响应（200）：
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "深圳市",
        "code": "440300"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [113.75, 22.45],
            [114.62, 22.45],
            [114.62, 22.86],
            [113.75, 22.86],
            [113.75, 22.45]
          ]
        ]
      }
    }
  ]
}
```

失败响应（400 - 缺少 scale 参数）：
```json
{
  "error": "scale parameter is required"
}
```

失败响应（404 - 文件不存在）：
```json
{
  "error": "GeoJSON file not found for scale: InvalidScale"
}
```

失败响应（401 - 未授权）：
```json
{
  "error": "未授权：无效的会话或API Key"
}
```

失败响应（500 - 读取文件失败）：
```json
{
  "error": "failed to read geojson: <错误详情>"
}
```

**业务逻辑：**
1. 验证用户身份（API Key 或 Session）
2. 验证 `scale` 参数是否为空
3. 根据 `scale` 构建文件路径：`static/geojson/GBA_{scale}.geojson`
4. 检查文件是否存在
5. 读取并返回 GeoJSON 内容

**技术要点：**
- 文件路径格式：`static/geojson/GBA_Boundary.geojson`、`GBA_City.geojson`、`GBA_District.geojson`、`GBA_Factory.geojson`
- 使用 `ClassPathResource` 读取 classpath 下的静态资源
- 响应 Content-Type：`application/json`
- 字符编码：UTF-8

**认证策略：**
- 优先使用 `X-API-Key` 请求头进行 API Key 认证
- 如果未提供 API Key，则从 Cookie 中提取 `SESSION_ID` 进行 Session 认证
- 两种认证方式任一有效即可访问

**可用的 scale 值：**

| scale 值 | 说明 | 文件名 |
|----------|------|--------|
| Boundary | 粤港澳大湾区整体边界 | GBA_Boundary.geojson |
| City | 城市级别行政区划 | GBA_City.geojson |
| District | 区县级别行政区划 | GBA_District.geojson |
| Factory | 工厂点位信息 | GBA_Factory.geojson |

---

## 工厂信息接口

**基础路径**：`/api/factories`  
**控制器**：`FactoriesController`  
**业务层**：`FactoriesInformationService`  
**数据表**：`factories_information`

### 5.1 获取所有工厂信息

**接口描述**：获取所有工厂的详细信息，包括企业基本信息、地理位置等。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/factories/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）
- **Content-Type**：`application/json`

**请求参数**：无

**请求示例：**
```
GET /api/factories/all
```

**响应示例：**
```json
[
  {
    "factoryUuid": "factory-uuid-001",
    "companyName": "深圳某某制造有限公司",
    "companyAddress": "广东省深圳市宝安区某某工业园",
    "creditCode": "91440300XXXXXXXXXX",
    "legalRepresentative": "张三",
    "publicPhone": "0755-12345678",
    "publicEmail": "contact@example.com",
    "registrationDate": "2010-06-15",
    "registeredCapital": "5000万元",
    "companyStatus": "存续",
    "businessScope": "电子产品制造、销售...",
    "formerNames": null,
    "newName": null,
    "companyType": "有限责任公司",
    "city": "深圳市",
    "district": "宝安区",
    "lon": 113.88,
    "lat": 22.65,
    "stockCode": "688001"
  }
]
```

**字段说明：**

| 字段名 | 类型 | 说明 |
|--------|------|------|
| factoryUuid | String | 工厂唯一标识 |
| companyName | String | 企业名称 |
| companyAddress | String | 企业地址 |
| creditCode | String | 统一社会信用代码 |
| legalRepresentative | String | 法定代表人 |
| publicPhone | String | 公开电话 |
| publicEmail | String | 公开邮箱 |
| registrationDate | String | 注册日期（yyyy-MM-dd） |
| registeredCapital | String | 注册资本 |
| companyStatus | String | 企业状态（如：存续、注销等） |
| businessScope | String | 经营范围 |
| formerNames | String | 曾用名 |
| newName | String | 新名称 |
| companyType | String | 企业类型 |
| city | String | 所在城市 |
| district | String | 所在区域 |
| lon | Double | 经度 |
| lat | Double | 纬度 |
| stockCode | String | 关联股票代码 |

---

### 5.2 多条件查询工厂

**接口描述**：根据多个可选条件组合查询工厂信息，支持灵活的多条件筛选。所有参数均为可选，支持任意组合。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/factories/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（精确匹配） |
| companyName | String | 否 | 公司名称（支持模糊查询） |
| city | String | 否 | 城市（精确匹配） |
| district | String | 否 | 区县（精确匹配） |
| creditCode | String | 否 | 统一社会信用代码（精确匹配） |
| legalRepresentative | String | 否 | 法定代表人（支持模糊查询） |
| companyType | String | 否 | 公司类型（精确匹配） |
| companyStatus | String | 否 | 企业状态（精确匹配） |

**请求示例：**

1. 按城市查询：
```json
{
  "city": "深圳市"
}
```

2. 按公司名称模糊查询：
```json
{
  "companyName": "科技"
}
```

3. 按股票代码查询：
```json
{
  "stockName": "688001"
}
```

4. 组合查询（城市+企业状态）：
```json
{
  "city": "深圳市",
  "companyStatus": "存续"
}
```

5. 多条件组合查询：
```json
{
  "city": "深圳市",
  "district": "宝安区",
  "companyType": "有限责任公司",
  "companyStatus": "存续"
}
```

6. 查询所有（不传任何参数）：
```json
{}
```

**响应示例：**
```json
[
  {
    "factoryUuid": "factory-uuid-001",
    "companyName": "深圳某某制造有限公司",
    "companyAddress": "广东省深圳市宝安区某某工业园",
    "creditCode": "91440300XXXXXXXXXX",
    "legalRepresentative": "张三",
    "publicPhone": "0755-12345678",
    "publicEmail": "contact@example.com",
    "registrationDate": "2010-06-15",
    "registeredCapital": "5000万元",
    "companyStatus": "存续",
    "businessScope": "电子产品制造、销售...",
    "formerNames": null,
    "newName": null,
    "companyType": "有限责任公司",
    "city": "深圳市",
    "district": "宝安区",
    "lon": 113.88,
    "lat": 22.65,
    "stockCode": "688001"
  }
]
```

**业务逻辑：**
1. 使用 JPA Specification 构建动态查询条件
2. 精确匹配字段：stockName、city、district、creditCode、companyType、companyStatus
3. 模糊匹配字段：companyName、legalRepresentative（使用 SQL LIKE '%keyword%'）
4. 如果不传任何参数，返回所有工厂数据
5. 所有条件之间为 AND 关系（同时满足）

**技术要点：**
- 使用 Spring Data JPA Specification 实现动态查询
- Repository 需继承 `JpaSpecificationExecutor<FactoriesInformation>`
- 自动过滤 null 和空字符串参数
- 支持灵活的条件组合

---

### 5.3 按多边形查询工厂

**接口描述**：根据用户绘制的多边形区域，查询该区域内的所有工厂信息。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/factories/find-factories-by-polygon`
- **是否需要认证**：是（支持 API Key 或 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| coordinates | Array | 是 | 多边形坐标数组，格式：`[[[lng1, lat1], [lng2, lat2], ...]]` |

**请求示例：**
```json
{
  "coordinates": [
    [
      [113.9, 22.5],
      [114.1, 22.5],
      [114.1, 22.6],
      [113.9, 22.6],
      [113.9, 22.5]
    ]
  ]
}
```

**响应示例：**
```json
[
  {
    "factoryUuid": "factory-uuid-001",
    "companyName": "深圳某某制造有限公司",
    "companyAddress": "广东省深圳市宝安区某某工业园",
    "creditCode": "91440300XXXXXXXXXX",
    "legalRepresentative": "张三",
    "publicPhone": "0755-12345678",
    "publicEmail": "contact@example.com",
    "registrationDate": "2010-06-15",
    "registeredCapital": "5000万元",
    "companyStatus": "存续",
    "businessScope": "电子产品制造、销售...",
    "formerNames": null,
    "newName": null,
    "companyType": "有限责任公司",
    "city": "深圳市",
    "district": "宝安区",
    "lon": 113.95,
    "lat": 22.55,
    "stockCode": "688001"
  }
]
```

**特殊说明：**
- 坐标点 < 2：返回全部工厂
- 坐标点 < 3：返回 400 错误（无法形成多边形）
- 坐标点 ≥ 3：执行多边形过滤查询

---

### 5.4 按多边形统计工厂数量

**接口描述**：统计指定多边形区域内的工厂数量。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/factories/count-factories-by-polygon`
- **是否需要认证**：是（支持 API Key 或 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| coordinates | Array | 是 | 多边形坐标数组，格式：`[[[lng1, lat1], [lng2, lat2], ...]]` |

**请求示例：**
```json
{
  "coordinates": [
    [
      [113.9, 22.5],
      [114.1, 22.5],
      [114.1, 22.6],
      [113.9, 22.6],
      [113.9, 22.5]
    ]
  ]
}
```

**响应示例：**
```json
15
```

**特殊说明：**
- 坐标点 < 2：返回全部工厂数量
- 坐标点 < 3：返回 400 错误（无法形成多边形）
- 坐标点 ≥ 3：执行多边形过滤统计

---

## 事实数据表接口

### 7.1 碳排放数据接口

**基础路径**：`/api/carbon`  
**控制器**：`FactCarbonEmissionController`  
**业务层**：`FactCarbonEmissionService`  
**数据表**：`fact_carbon_emission`

#### 7.1.1 创建碳排放数据

**接口描述**：创建新的碳排放数据记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/carbon`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Integer | 否 | 记录索引（自增主键，创建时可省略） |
| name | String | 是 | 公司名称或排放源名称 |
| year | Integer | 是 | 年份 |
| type | String | 是 | 排放类型 |
| max | Double | 否 | 最大排放量 |
| mean | Float | 否 | 平均排放量 |
| min | Double | 否 | 最小排放量 |
| sum | Double | 否 | 总排放量 |

**请求示例：**
```json
{
  "name": "某某企业",
  "year": 2023,
  "type": "CO2",
  "max": 1500.5,
  "mean": 1200.3,
  "min": 900.0,
  "sum": 14400.0
}
```

**响应示例：**

成功响应（201）：
```json
{
  "index": 1,
  "name": "某某企业",
  "year": 2023,
  "type": "CO2",
  "max": 1500.5,
  "mean": 1200.3,
  "min": 900.0,
  "sum": 14400.0
}
```

失败响应（401）：
```
HTTP 401 Unauthorized
"未授权：需要登录后才能创建数据"
```

失败响应（400）：
```
HTTP 400 Bad Request
"创建失败：<错误详情>"
```

---

#### 7.1.2 更新碳排放数据

**接口描述**：根据索引更新碳排放数据记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/carbon/{index}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Integer | 是 | 记录索引（主键） |

**请求参数：**（同创建接口）

**请求示例：**
```
PUT /api/carbon/1
```
```json
{
  "name": "某某企业",
  "year": 2023,
  "type": "CO2",
  "max": 1600.0,
  "mean": 1250.5,
  "min": 950.0,
  "sum": 15000.0
}
```

**响应示例：**

成功响应（200）：
```json
{
  "index": 1,
  "name": "某某企业",
  "year": 2023,
  "type": "CO2",
  "max": 1600.0,
  "mean": 1250.5,
  "min": 950.0,
  "sum": 15000.0
}
```

失败响应（404）：
```
HTTP 404 Not Found
"更新失败：记录不存在"
```

---

#### 7.1.3 删除碳排放数据

**接口描述**：根据索引删除碳排放数据记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/carbon/{index}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Integer | 是 | 记录索引（主键） |

**请求示例：**
```
DELETE /api/carbon/1
```

**响应示例：**

成功响应（200）：
```
HTTP 200 OK
"删除成功"
```

失败响应（404）：
```
HTTP 404 Not Found
"删除失败：记录不存在"
```

---

#### 7.1.4 查询碳排放数据

**接口描述**：根据多个可选条件查询碳排放数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/carbon/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| name | String | 否 | 公司名称（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |
| type | String | 否 | 排放类型（精确匹配） |

**请求示例：**

1. 按名称查询：
```
GET /api/carbon/search?name=某某企业
```

2. 按年份和类型查询：
```
GET /api/carbon/search?year=2023&type=CO2
```

3. 组合查询：
```
GET /api/carbon/search?name=某某&year=2023&type=CO2
```

**响应示例：**
```json
[
  {
    "index": 1,
    "name": "某某企业",
    "year": 2023,
    "type": "CO2",
    "max": 1600.0,
    "mean": 1250.5,
    "min": 950.0,
    "sum": 15000.0
  }
]
```

---

#### 7.1.5 根据索引查询单条数据

**接口描述**：根据记录索引查询单条碳排放数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/carbon/{index}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Integer | 是 | 记录索引（主键） |

**请求示例：**
```
GET /api/carbon/1
```

**响应示例：**

成功响应（200）：
```json
{
  "index": 1,
  "name": "某某企业",
  "year": 2023,
  "type": "CO2",
  "max": 1600.0,
  "mean": 1250.5,
  "min": 950.0,
  "sum": 15000.0
}
```

未找到响应（404）：
```
HTTP 404 Not Found
```

---

#### 7.1.6 获取所有碳排放数据

**接口描述**：获取所有碳排放数据记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/carbon/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/carbon/all
```

**响应示例：**
```json
[
  {
    "index": 1,
    "name": "某某企业",
    "year": 2023,
    "type": "CO2",
    "max": 1600.0,
    "mean": 1250.5,
    "min": 950.0,
    "sum": 15000.0
  },
  {
    "index": 2,
    "name": "另一企业",
    "year": 2022,
    "type": "CH4",
    "max": 800.0,
    "mean": 650.0,
    "min": 500.0,
    "sum": 7800.0
  }
]
```

---

### 7.2 财务面板数据接口

**基础路径**：`/api/financial`  
**控制器**：`FactFinPanelAnnualController`  
**业务层**：`FactFinPanelAnnualService`  
**数据表**：`fact_fin_panel_annual`

#### 7.2.1 创建财务数据

**接口描述**：创建新的上市公司年度财务面板数据记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/financial`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键之一） |
| year | Integer | 是 | 年份（主键之一） |
| secShortName | String | 否 | 股票简称 |
| industryCodeA | String | 否 | 行业代码 |
| industryNameA | String | 否 | 行业名称 |
| companyFullName | String | 否 | 公司全称 |
| provinceName | String | 否 | 省份名称 |
| provinceCode | String | 否 | 省份代码 |
| cityName | String | 否 | 城市名称 |
| cityCode | String | 否 | 城市代码 |
| companyNature | String | 否 | 公司性质 |
| foundYear | Integer | 否 | 成立年份 |
| listYear | Integer | 否 | 上市年份 |
| operatingRevenue | BigDecimal | 否 | 营业收入 |
| operatingCost | BigDecimal | 否 | 营业成本 |
| sellingExpense | BigDecimal | 否 | 销售费用 |
| adminExpense | BigDecimal | 否 | 管理费用 |
| rdExpense | BigDecimal | 否 | 研发费用 |
| financeExpense | BigDecimal | 否 | 财务费用 |
| totalProfit | BigDecimal | 否 | 利润总额 |
| netProfit | BigDecimal | 否 | 净利润 |
| currentRatio | BigDecimal | 否 | 流动比率 |
| quickRatio | BigDecimal | 否 | 速动比率 |
| cashRatio | BigDecimal | 否 | 现金比率 |
| debtAssetRatio | BigDecimal | 否 | 资产负债率 |
| currentAssetsRatio | BigDecimal | 否 | 流动资产比率 |
| cashAssetsRatio | BigDecimal | 否 | 现金资产比率 |
| inventoryTurnoverA | BigDecimal | 否 | 存货周转率 |
| apTurnoverA | BigDecimal | 否 | 应付账款周转率 |
| totalAssetsTurnoverA | BigDecimal | 否 | 总资产周转率 |
| operatingProfitMargin | BigDecimal | 否 | 营业利润率 |
| sellingExpenseRatio | BigDecimal | 否 | 销售费用率 |
| adminExpenseRatio | BigDecimal | 否 | 管理费用率 |
| financeExpenseRatio | BigDecimal | 否 | 财务费用率 |
| rdExpenseRatio | BigDecimal | 否 | 研发费用率 |
| netProfitGrowthA | BigDecimal | 否 | 净利润增长率 |
| pe1 | BigDecimal | 否 | 市盈率 |
| ps1 | BigDecimal | 否 | 市销率 |
| pb | BigDecimal | 否 | 市净率 |
| tobinQA | BigDecimal | 否 | 托宾Q值 |
| zScore | BigDecimal | 否 | Z分数 |
| herfindahl3Index | BigDecimal | 否 | 赫芬达尔指数 |

**请求示例：**
```json
{
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "industryCodeA": "C39",
  "industryNameA": "计算机、通信和其他电子设备制造业",
  "companyFullName": "深圳某某科技股份有限公司",
  "provinceName": "广东省",
  "provinceCode": "440000",
  "cityName": "深圳市",
  "cityCode": "440300",
  "operatingRevenue": 5000000000.00,
  "netProfit": 500000000.00,
  "rdExpense": 300000000.00
}
```

**响应示例：**

成功响应（201）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "operatingRevenue": 5000000000.00,
  "netProfit": 500000000.00,
  "rdExpense": 300000000.00
}
```

失败响应（401）：
```
HTTP 401 Unauthorized
"未授权：需要登录后才能创建数据"
```

---

#### 7.2.2 更新财务数据

**接口描述**：根据股票代码和年份更新财务数据记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/financial/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求参数：**（同创建接口）

**请求示例：**
```
PUT /api/financial/688001/2023
```
```json
{
  "operatingRevenue": 5500000000.00,
  "netProfit": 550000000.00,
  "rdExpense": 350000000.00
}
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "operatingRevenue": 5500000000.00,
  "netProfit": 550000000.00,
  "rdExpense": 350000000.00
}
```

失败响应（404）：
```
HTTP 404 Not Found
"更新失败：记录不存在"
```

---

#### 7.2.3 删除财务数据

**接口描述**：根据股票代码和年份删除财务数据记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/financial/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
DELETE /api/financial/688001/2023
```

**响应示例：**

成功响应（200）：
```
HTTP 200 OK
"删除成功"
```

失败响应（404）：
```
HTTP 404 Not Found
"删除失败：记录不存在"
```

---

#### 7.2.4 查询财务数据

**接口描述**：根据多个可选条件查询财务面板数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/financial/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |
| industryCodeA | String | 否 | 行业代码（支持模糊查询） |
| provinceCode | String | 否 | 省份代码（支持模糊查询） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/financial/search?stockName=688001
```

2. 按年份和行业查询：
```
GET /api/financial/search?year=2023&industryCodeA=C39
```

3. 组合查询：
```
GET /api/financial/search?stockName=688&year=2023&provinceCode=440000
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "secShortName": "某某科技",
    "industryCodeA": "C39",
    "industryNameA": "计算机、通信和其他电子设备制造业",
    "provinceName": "广东省",
    "operatingRevenue": 5500000000.00,
    "netProfit": 550000000.00,
    "rdExpense": 350000000.00
  }
]
```

---

#### 7.2.5 根据股票代码和年份查询单条数据

**接口描述**：根据股票代码和年份精确查询单条财务数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/financial/{stockName}/{year}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
GET /api/financial/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "industryCodeA": "C39",
  "companyFullName": "深圳某某科技股份有限公司",
  "operatingRevenue": 5500000000.00,
  "netProfit": 550000000.00,
  "rdExpense": 350000000.00,
  "pe1": 25.5,
  "pb": 3.2
}
```

未找到响应（404）：
```
HTTP 404 Not Found
```

---

#### 7.2.6 获取所有财务数据

**接口描述**：获取所有财务面板数据记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/financial/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/financial/all
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "operatingRevenue": 5500000000.00,
    "netProfit": 550000000.00
  },
  {
    "stockName": "688002",
    "year": 2023,
    "operatingRevenue": 3000000000.00,
    "netProfit": 300000000.00
  }
]
```

---

### 7.3 环境处罚事件接口

**基础路径**：`/api/env-penalty`  
**控制器**：`FactEnvPenaltyEventController`  
**业务层**：`FactEnvPenaltyEventService`  
**数据表**：`fact_env_penalty_event`

#### 7.3.1 创建环境处罚事件记录

**接口描述**：创建新的环境处罚事件记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/env-penalty`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键之一，注意拼写为stokeName） |
| year | Integer | 是 | 年份（主键之一） |
| penaltyAmount | BigDecimal | 是 | 处罚金额 |

**请求示例：**
```json
{
  "stokeName": "688001",
  "year": 2023,
  "penaltyAmount": 500000.00
}
```

**响应示例：**

成功响应（201）：
```json
{
  "stokeName": "688001",
  "year": 2023,
  "penaltyAmount": 500000.00
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.3.2 更新环境处罚事件记录

**接口描述**：根据股票代码和年份更新环境处罚事件记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/env-penalty/{stokeName}/{year}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| penaltyAmount | BigDecimal | 是 | 处罚金额 |

**请求示例：**
```
PUT /api/env-penalty/688001/2023
```
```json
{
  "stokeName": "688001",
  "year": 2023,
  "penaltyAmount": 600000.00
}
```

**响应示例：**

成功响应（200）：
```json
{
  "stokeName": "688001",
  "year": 2023,
  "penaltyAmount": 600000.00
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.3.3 删除环境处罚事件记录

**接口描述**：根据股票代码和年份删除环境处罚事件记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/env-penalty/{stokeName}/{year}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
DELETE /api/env-penalty/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.3.4 搜索环境处罚事件记录

**接口描述**：根据股票代码或年份搜索环境处罚事件记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/env-penalty/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 否 | 股票代码（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/env-penalty/search?stokeName=688001
```

2. 按年份查询：
```
GET /api/env-penalty/search?year=2023
```

3. 组合查询：
```
GET /api/env-penalty/search?stokeName=688001&year=2023
```

**响应示例：**
```json
[
  {
    "stokeName": "688001",
    "year": 2023,
    "penaltyAmount": 600000.00
  },
  {
    "stokeName": "688001",
    "year": 2022,
    "penaltyAmount": 450000.00
  }
]
```

---

#### 7.3.5 根据主键查询环境处罚事件记录

**接口描述**：根据股票代码和年份精确查询单条环境处罚事件记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/env-penalty/{stokeName}/{year}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
GET /api/env-penalty/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "stokeName": "688001",
  "year": 2023,
  "penaltyAmount": 600000.00
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.3.6 查询所有环境处罚事件记录

**接口描述**：获取所有环境处罚事件记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/env-penalty/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/env-penalty/all
```

**响应示例：**
```json
[
  {
    "stokeName": "688001",
    "year": 2023,
    "penaltyAmount": 600000.00
  },
  {
    "stokeName": "688002",
    "year": 2023,
    "penaltyAmount": 350000.00
  }
]
```

---

### 7.4 环境补助事件接口

**基础路径**：`/api/env-subsidy`  
**控制器**：`FactEnvSubsidyEventController`  
**业务层**：`FactEnvSubsidyEventService`  
**数据表**：`fact_env_subsidy_event`

#### 7.4.1 创建环境补助事件记录

**接口描述**：创建新的环境补助事件记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/env-subsidy`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Long | 否 | 记录索引（自增主键，创建时可省略） |
| stokeName | String | 是 | 股票代码 |
| statisticDate | String | 是 | 统计日期 |
| item | String | 是 | 补助项目名称 |
| subsidyAmount | BigDecimal | 是 | 补助金额 |

**请求示例：**
```json
{
  "stokeName": "688001",
  "statisticDate": "2023-12-31",
  "item": "环保技术改造补助",
  "subsidyAmount": 1000000.00
}
```

**响应示例：**

成功响应（201）：
```json
{
  "index": 1,
  "stokeName": "688001",
  "statisticDate": "2023-12-31",
  "item": "环保技术改造补助",
  "subsidyAmount": 1000000.00
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.4.2 更新环境补助事件记录

**接口描述**：根据记录索引更新环境补助事件记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/env-subsidy/{index}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Long | 是 | 记录索引（主键） |

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码 |
| statisticDate | String | 是 | 统计日期 |
| item | String | 是 | 补助项目名称 |
| subsidyAmount | BigDecimal | 是 | 补助金额 |

**请求示例：**
```
PUT /api/env-subsidy/1
```
```json
{
  "stokeName": "688001",
  "statisticDate": "2023-12-31",
  "item": "环保技术改造补助",
  "subsidyAmount": 1200000.00
}
```

**响应示例：**

成功响应（200）：
```json
{
  "index": 1,
  "stokeName": "688001",
  "statisticDate": "2023-12-31",
  "item": "环保技术改造补助",
  "subsidyAmount": 1200000.00
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.4.3 删除环境补助事件记录

**接口描述**：根据记录索引删除环境补助事件记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/env-subsidy/{index}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Long | 是 | 记录索引（主键） |

**请求示例：**
```
DELETE /api/env-subsidy/1
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.4.4 搜索环境补助事件记录

**接口描述**：根据股票代码、统计日期或补助项目名称搜索环境补助事件记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/env-subsidy/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 否 | 股票代码（支持模糊查询） |
| statisticDate | String | 否 | 统计日期（支持模糊查询） |
| item | String | 否 | 补助项目名称（支持模糊查询） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/env-subsidy/search?stokeName=688001
```

2. 按统计日期查询：
```
GET /api/env-subsidy/search?statisticDate=2023
```

3. 按补助项目查询：
```
GET /api/env-subsidy/search?item=环保
```

4. 组合查询：
```
GET /api/env-subsidy/search?stokeName=688001&statisticDate=2023
```

**响应示例：**
```json
[
  {
    "index": 1,
    "stokeName": "688001",
    "statisticDate": "2023-12-31",
    "item": "环保技术改造补助",
    "subsidyAmount": 1200000.00
  },
  {
    "index": 2,
    "stokeName": "688001",
    "statisticDate": "2023-06-30",
    "item": "节能减排补助",
    "subsidyAmount": 800000.00
  }
]
```

---

#### 7.4.5 根据索引查询环境补助事件记录

**接口描述**：根据记录索引精确查询单条环境补助事件记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/env-subsidy/{index}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| index | Long | 是 | 记录索引（主键） |

**请求示例：**
```
GET /api/env-subsidy/1
```

**响应示例：**

成功响应（200）：
```json
{
  "index": 1,
  "stokeName": "688001",
  "statisticDate": "2023-12-31",
  "item": "环保技术改造补助",
  "subsidyAmount": 1200000.00
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.4.6 查询所有环境补助事件记录

**接口描述**：获取所有环境补助事件记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/env-subsidy/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/env-subsidy/all
```

**响应示例：**
```json
[
  {
    "index": 1,
    "stokeName": "688001",
    "statisticDate": "2023-12-31",
    "item": "环保技术改造补助",
    "subsidyAmount": 1200000.00
  },
  {
    "index": 2,
    "stokeName": "688002",
    "statisticDate": "2023-12-31",
    "item": "清洁能源补助",
    "subsidyAmount": 900000.00
  }
]
```

---

### 7.5 ESG评分接口

**基础路径**：`/api/esg-score`  
**控制器**：`FactEsgScoreAnnualController`  
**业务层**：`FactEsgScoreAnnualService`  
**数据表**：`fact_esg_score_annual`

#### 7.5.1 创建ESG年度评分记录

**接口描述**：创建新的ESG年度评分记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/esg-score`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| id | Long | 否 | 记录ID（自增主键，创建时可省略） |
| stockName | String | 是 | 股票代码 |
| year | Long | 是 | 年份 |
| secShortName | String | 否 | 股票简称 |
| esgScore | Double | 是 | ESG评分 |
| dataSource | String | 否 | 数据来源 |

**请求示例：**
```json
{
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "esgScore": 85.5,
  "dataSource": "华证ESG评级"
}
```

**响应示例：**

成功响应（201）：
```json
{
  "id": 1,
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "esgScore": 85.5,
  "dataSource": "华证ESG评级"
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.5.2 更新ESG年度评分记录

**接口描述**：根据记录ID更新ESG年度评分记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/esg-score/{id}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| id | Long | 是 | 记录ID（主键） |

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码 |
| year | Long | 是 | 年份 |
| secShortName | String | 否 | 股票简称 |
| esgScore | Double | 是 | ESG评分 |
| dataSource | String | 否 | 数据来源 |

**请求示例：**
```
PUT /api/esg-score/1
```
```json
{
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "esgScore": 87.0,
  "dataSource": "华证ESG评级"
}
```

**响应示例：**

成功响应（200）：
```json
{
  "id": 1,
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "esgScore": 87.0,
  "dataSource": "华证ESG评级"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.5.3 删除ESG年度评分记录

**接口描述**：根据记录ID删除ESG年度评分记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/esg-score/{id}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| id | Long | 是 | 记录ID（主键） |

**请求示例：**
```
DELETE /api/esg-score/1
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.5.4 搜索ESG年度评分记录

**接口描述**：根据股票代码、年份、股票简称或数据来源搜索ESG评分记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/esg-score/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（支持模糊查询） |
| year | Long | 否 | 年份（精确匹配） |
| secShortName | String | 否 | 股票简称（支持模糊查询） |
| dataSource | String | 否 | 数据来源（支持模糊查询） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/esg-score/search?stockName=688001
```

2. 按年份查询：
```
GET /api/esg-score/search?year=2023
```

3. 按数据来源查询：
```
GET /api/esg-score/search?dataSource=华证
```

4. 组合查询：
```
GET /api/esg-score/search?stockName=688001&year=2023
```

**响应示例：**
```json
[
  {
    "id": 1,
    "stockName": "688001",
    "year": 2023,
    "secShortName": "某某科技",
    "esgScore": 87.0,
    "dataSource": "华证ESG评级"
  },
  {
    "id": 2,
    "stockName": "688001",
    "year": 2022,
    "secShortName": "某某科技",
    "esgScore": 84.5,
    "dataSource": "华证ESG评级"
  }
]
```

---

#### 7.5.5 根据ID查询ESG年度评分记录

**接口描述**：根据记录ID精确查询单条ESG评分记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/esg-score/{id}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| id | Long | 是 | 记录ID（主键） |

**请求示例：**
```
GET /api/esg-score/1
```

**响应示例：**

成功响应（200）：
```json
{
  "id": 1,
  "stockName": "688001",
  "year": 2023,
  "secShortName": "某某科技",
  "esgScore": 87.0,
  "dataSource": "华证ESG评级"
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.5.6 查询所有ESG年度评分记录

**接口描述**：获取所有ESG年度评分记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/esg-score/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/esg-score/all
```

**响应示例：**
```json
[
  {
    "id": 1,
    "stockName": "688001",
    "year": 2023,
    "secShortName": "某某科技",
    "esgScore": 87.0,
    "dataSource": "华证ESG评级"
  },
  {
    "id": 2,
    "stockName": "688002",
    "year": 2023,
    "secShortName": "另一科技",
    "esgScore": 82.5,
    "dataSource": "华证ESG评级"
  }
]
```

---

### 7.6 绿色投资数据接口

**基础路径**：`/api/green-investment`  
**控制器**：`FactGreenInvestmentAnnualController`  
**业务层**：`FactGreenInvestmentAnnualService`  
**数据表**：`fact_green_investment_annual`

#### 7.6.1 创建绿色投资年度记录

**接口描述**：创建新的企业绿色投资年度数据记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/green-investment`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键之一） |
| year | Integer | 是 | 年份（主键之一） |
| greenInvestmentAmount | BigDecimal | 否 | 绿色投资金额 |
| greenCapexRatio | BigDecimal | 否 | 绿色资本支出比率 |
| investmentCategory | String | 否 | 投资类别（如：清洁能源、节能减排等） |
| projectCount | Integer | 否 | 项目数量 |
| dataSource | String | 否 | 数据来源 |
| remark | String | 否 | 备注 |

**请求示例：**
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenInvestmentAmount": 50000000.00,
  "greenCapexRatio": 0.25,
  "investmentCategory": "清洁能源",
  "projectCount": 5,
  "dataSource": "企业年报",
  "remark": "光伏发电项目"
}
```

**响应示例：**

成功响应（201）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenInvestmentAmount": 50000000.00,
  "greenCapexRatio": 0.25,
  "investmentCategory": "清洁能源",
  "projectCount": 5,
  "dataSource": "企业年报",
  "remark": "光伏发电项目"
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.6.2 更新绿色投资年度记录

**接口描述**：根据股票代码和年份更新绿色投资数据记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/green-investment/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求参数：**（同创建接口）

**请求示例：**
```
PUT /api/green-investment/688001/2023
```
```json
{
  "greenInvestmentAmount": 55000000.00,
  "greenCapexRatio": 0.28,
  "investmentCategory": "清洁能源",
  "projectCount": 6,
  "dataSource": "企业年报",
  "remark": "光伏发电及储能项目"
}
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenInvestmentAmount": 55000000.00,
  "greenCapexRatio": 0.28,
  "investmentCategory": "清洁能源",
  "projectCount": 6,
  "dataSource": "企业年报",
  "remark": "光伏发电及储能项目"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.6.3 删除绿色投资年度记录

**接口描述**：根据股票代码和年份删除绿色投资数据记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/green-investment/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
DELETE /api/green-investment/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.6.4 搜索绿色投资年度记录

**接口描述**：根据股票代码、年份或投资类别搜索绿色投资数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/green-investment/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |
| investmentCategory | String | 否 | 投资类别（支持模糊查询） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/green-investment/search?stockName=688001
```

2. 按年份查询：
```
GET /api/green-investment/search?year=2023
```

3. 按投资类别查询：
```
GET /api/green-investment/search?investmentCategory=清洁能源
```

4. 组合查询：
```
GET /api/green-investment/search?stockName=688001&year=2023
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "greenInvestmentAmount": 55000000.00,
    "greenCapexRatio": 0.28,
    "investmentCategory": "清洁能源",
    "projectCount": 6,
    "dataSource": "企业年报",
    "remark": "光伏发电及储能项目"
  },
  {
    "stockName": "688001",
    "year": 2022,
    "greenInvestmentAmount": 45000000.00,
    "greenCapexRatio": 0.22,
    "investmentCategory": "清洁能源",
    "projectCount": 4,
    "dataSource": "企业年报",
    "remark": "风力发电项目"
  }
]
```

---

#### 7.6.5 根据主键查询绿色投资年度记录

**接口描述**：根据股票代码和年份精确查询单条绿色投资数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/green-investment/{stockName}/{year}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
GET /api/green-investment/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenInvestmentAmount": 55000000.00,
  "greenCapexRatio": 0.28,
  "investmentCategory": "清洁能源",
  "projectCount": 6,
  "dataSource": "企业年报",
  "remark": "光伏发电及储能项目"
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.6.6 查询所有绿色投资年度记录

**接口描述**：获取所有绿色投资年度数据记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/green-investment/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/green-investment/all
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "greenInvestmentAmount": 55000000.00,
    "greenCapexRatio": 0.28,
    "investmentCategory": "清洁能源",
    "projectCount": 6
  },
  {
    "stockName": "688002",
    "year": 2023,
    "greenInvestmentAmount": 30000000.00,
    "greenCapexRatio": 0.18,
    "investmentCategory": "节能减排",
    "projectCount": 3
  }
]
```

---

### 7.7 绿色专利数据接口

**基础路径**：`/api/green-patent`  
**控制器**：`FactGreenPatentAnnualController`  
**业务层**：`FactGreenPatentAnnualService`  
**数据表**：`fact_green_patent_annual`

#### 7.7.1 创建绿色专利年度记录

**接口描述**：创建新的企业绿色专利年度统计记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/green-patent`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键之一） |
| year | Integer | 是 | 年份（主键之一） |
| greenPatentInventionCount | Integer | 否 | 绿色发明专利数量 |
| greenPatentUtilityCount | Integer | 否 | 绿色实用新型专利数量 |
| greenPatentTotalCount | Integer | 否 | 绿色专利总数 |
| dataSourceInvention | String | 否 | 发明专利数据来源 |
| dataSourceUtility | String | 否 | 实用新型专利数据来源 |
| remark | String | 否 | 备注 |

**请求示例：**
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenPatentInventionCount": 25,
  "greenPatentUtilityCount": 18,
  "greenPatentTotalCount": 43,
  "dataSourceInvention": "国家知识产权局",
  "dataSourceUtility": "国家知识产权局",
  "remark": "主要为节能环保技术专利"
}
```

**响应示例：**

成功响应（201）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenPatentInventionCount": 25,
  "greenPatentUtilityCount": 18,
  "greenPatentTotalCount": 43,
  "dataSourceInvention": "国家知识产权局",
  "dataSourceUtility": "国家知识产权局",
  "remark": "主要为节能环保技术专利"
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.7.2 更新绿色专利年度记录

**接口描述**：根据股票代码和年份更新绿色专利数据记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/green-patent/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求参数：**（同创建接口）

**请求示例：**
```
PUT /api/green-patent/688001/2023
```
```json
{
  "greenPatentInventionCount": 28,
  "greenPatentUtilityCount": 20,
  "greenPatentTotalCount": 48,
  "dataSourceInvention": "国家知识产权局",
  "dataSourceUtility": "国家知识产权局",
  "remark": "新增清洁能源专利"
}
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenPatentInventionCount": 28,
  "greenPatentUtilityCount": 20,
  "greenPatentTotalCount": 48,
  "dataSourceInvention": "国家知识产权局",
  "dataSourceUtility": "国家知识产权局",
  "remark": "新增清洁能源专利"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.7.3 删除绿色专利年度记录

**接口描述**：根据股票代码和年份删除绿色专利数据记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/green-patent/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
DELETE /api/green-patent/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.7.4 搜索绿色专利年度记录

**接口描述**：根据股票代码或年份搜索绿色专利数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/green-patent/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/green-patent/search?stockName=688001
```

2. 按年份查询：
```
GET /api/green-patent/search?year=2023
```

3. 组合查询：
```
GET /api/green-patent/search?stockName=688001&year=2023
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "greenPatentInventionCount": 28,
    "greenPatentUtilityCount": 20,
    "greenPatentTotalCount": 48,
    "dataSourceInvention": "国家知识产权局",
    "dataSourceUtility": "国家知识产权局",
    "remark": "新增清洁能源专利"
  },
  {
    "stockName": "688001",
    "year": 2022,
    "greenPatentInventionCount": 20,
    "greenPatentUtilityCount": 15,
    "greenPatentTotalCount": 35,
    "dataSourceInvention": "国家知识产权局",
    "dataSourceUtility": "国家知识产权局",
    "remark": null
  }
]
```

---

#### 7.7.5 根据主键查询绿色专利年度记录

**接口描述**：根据股票代码和年份精确查询单条绿色专利数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/green-patent/{stockName}/{year}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
GET /api/green-patent/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "greenPatentInventionCount": 28,
  "greenPatentUtilityCount": 20,
  "greenPatentTotalCount": 48,
  "dataSourceInvention": "国家知识产权局",
  "dataSourceUtility": "国家知识产权局",
  "remark": "新增清洁能源专利"
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.7.6 查询所有绿色专利年度记录

**接口描述**：获取所有绿色专利年度数据记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/green-patent/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/green-patent/all
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "greenPatentInventionCount": 28,
    "greenPatentUtilityCount": 20,
    "greenPatentTotalCount": 48
  },
  {
    "stockName": "688002",
    "year": 2023,
    "greenPatentInventionCount": 15,
    "greenPatentUtilityCount": 12,
    "greenPatentTotalCount": 27
  }
]
```

---

### 7.8 综合专利数据接口

**基础路径**：`/api/patent`  
**控制器**：`FactPatentAnnualController`  
**业务层**：`FactPatentAnnualService`  
**数据表**：`fact_patent_annual`

#### 7.8.1 创建综合专利年度记录

**接口描述**：创建新的企业综合专利年度统计记录（包含所有类型专利）。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/patent`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键之一） |
| year | Integer | 是 | 年份（主键之一） |
| patentTotalCount | Integer | 否 | 专利总数 |
| patentInventionCount | Integer | 否 | 发明专利数量 |
| patentUtilityCount | Integer | 否 | 实用新型专利数量 |
| patentDesignCount | Integer | 否 | 外观设计专利数量 |
| dataSource | String | 否 | 数据来源 |
| remark | String | 否 | 备注 |

**请求示例：**
```json
{
  "stockName": "688001",
  "year": 2023,
  "patentTotalCount": 156,
  "patentInventionCount": 85,
  "patentUtilityCount": 58,
  "patentDesignCount": 13,
  "dataSource": "国家知识产权局",
  "remark": "全年新增专利"
}
```

**响应示例：**

成功响应（201）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "patentTotalCount": 156,
  "patentInventionCount": 85,
  "patentUtilityCount": 58,
  "patentDesignCount": 13,
  "dataSource": "国家知识产权局",
  "remark": "全年新增专利"
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.8.2 更新综合专利年度记录

**接口描述**：根据股票代码和年份更新综合专利数据记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/patent/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求参数：**（同创建接口）

**请求示例：**
```
PUT /api/patent/688001/2023
```
```json
{
  "patentTotalCount": 165,
  "patentInventionCount": 90,
  "patentUtilityCount": 60,
  "patentDesignCount": 15,
  "dataSource": "国家知识产权局",
  "remark": "更新补充新增专利"
}
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "patentTotalCount": 165,
  "patentInventionCount": 90,
  "patentUtilityCount": 60,
  "patentDesignCount": 15,
  "dataSource": "国家知识产权局",
  "remark": "更新补充新增专利"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.8.3 删除综合专利年度记录

**接口描述**：根据股票代码和年份删除综合专利数据记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/patent/{stockName}/{year}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
DELETE /api/patent/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.8.4 搜索综合专利年度记录

**接口描述**：根据股票代码或年份搜索综合专利数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/patent/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 否 | 股票代码（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/patent/search?stockName=688001
```

2. 按年份查询：
```
GET /api/patent/search?year=2023
```

3. 组合查询：
```
GET /api/patent/search?stockName=688001&year=2023
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "patentTotalCount": 165,
    "patentInventionCount": 90,
    "patentUtilityCount": 60,
    "patentDesignCount": 15,
    "dataSource": "国家知识产权局",
    "remark": "更新补充新增专利"
  },
  {
    "stockName": "688001",
    "year": 2022,
    "patentTotalCount": 142,
    "patentInventionCount": 78,
    "patentUtilityCount": 52,
    "patentDesignCount": 12,
    "dataSource": "国家知识产权局",
    "remark": null
  }
]
```

---

#### 7.8.5 根据主键查询综合专利年度记录

**接口描述**：根据股票代码和年份精确查询单条综合专利数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/patent/{stockName}/{year}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stockName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
GET /api/patent/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "stockName": "688001",
  "year": 2023,
  "patentTotalCount": 165,
  "patentInventionCount": 90,
  "patentUtilityCount": 60,
  "patentDesignCount": 15,
  "dataSource": "国家知识产权局",
  "remark": "更新补充新增专利"
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.8.6 查询所有综合专利年度记录

**接口描述**：获取所有综合专利年度数据记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/patent/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/patent/all
```

**响应示例：**
```json
[
  {
    "stockName": "688001",
    "year": 2023,
    "patentTotalCount": 165,
    "patentInventionCount": 90,
    "patentUtilityCount": 60,
    "patentDesignCount": 15
  },
  {
    "stockName": "688002",
    "year": 2023,
    "patentTotalCount": 98,
    "patentInventionCount": 52,
    "patentUtilityCount": 38,
    "patentDesignCount": 8
  }
]
```

---

### 7.9 污染环保费用接口

**基础路径**：`/api/pollution-fee`  
**控制器**：`FactPollutionFeeAnnualController`  
**业务层**：`FactPollutionFeeAnnualService`  
**数据表**：`fact_pollution_fee_annual`

#### 7.9.1 创建污染/环保费用年度记录

**接口描述**：创建新的企业污染治理或环保投入费用年度记录。

**请求信息：**
- **请求方式**：POST
- **请求路径**：`/api/pollution-fee`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键之一，注意拼写为stokeName） |
| year | Integer | 是 | 年份（主键之一） |
| item | String | 是 | 费用项目名称 |
| environmentAmount | BigDecimal | 是 | 环保费用金额 |

**请求示例：**
```json
{
  "stokeName": "688001",
  "year": 2023,
  "item": "污水处理设施运营费用",
  "environmentAmount": 8500000.00
}
```

**响应示例：**

成功响应（201）：
```json
{
  "stokeName": "688001",
  "year": 2023,
  "item": "污水处理设施运营费用",
  "environmentAmount": 8500000.00
}
```

失败响应（401）：
```json
{
  "error": "未授权：需要有效的会话"
}
```

---

#### 7.9.2 更新污染/环保费用年度记录

**接口描述**：根据股票代码和年份更新污染/环保费用数据记录。

**请求信息：**
- **请求方式**：PUT
- **请求路径**：`/api/pollution-fee/{stokeName}/{year}`
- **是否需要认证**：是（仅 Session 认证）
- **Content-Type**：`application/json`

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| item | String | 是 | 费用项目名称 |
| environmentAmount | BigDecimal | 是 | 环保费用金额 |

**请求示例：**
```
PUT /api/pollution-fee/688001/2023
```
```json
{
  "stokeName": "688001",
  "year": 2023,
  "item": "污水处理设施运营及维护费用",
  "environmentAmount": 9200000.00
}
```

**响应示例：**

成功响应（200）：
```json
{
  "stokeName": "688001",
  "year": 2023,
  "item": "污水处理设施运营及维护费用",
  "environmentAmount": 9200000.00
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.9.3 删除污染/环保费用年度记录

**接口描述**：根据股票代码和年份删除污染/环保费用数据记录。

**请求信息：**
- **请求方式**：DELETE
- **请求路径**：`/api/pollution-fee/{stokeName}/{year}`
- **是否需要认证**：是（仅 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
DELETE /api/pollution-fee/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "message": "删除成功"
}
```

失败响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.9.4 搜索污染/环保费用年度记录

**接口描述**：根据股票代码或年份搜索污染/环保费用数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/pollution-fee/search`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 否 | 股票代码（支持模糊查询） |
| year | Integer | 否 | 年份（精确匹配） |

**请求示例：**

1. 按股票代码查询：
```
GET /api/pollution-fee/search?stokeName=688001
```

2. 按年份查询：
```
GET /api/pollution-fee/search?year=2023
```

3. 组合查询：
```
GET /api/pollution-fee/search?stokeName=688001&year=2023
```

**响应示例：**
```json
[
  {
    "stokeName": "688001",
    "year": 2023,
    "item": "污水处理设施运营及维护费用",
    "environmentAmount": 9200000.00
  },
  {
    "stokeName": "688001",
    "year": 2022,
    "item": "废气处理设施运营费用",
    "environmentAmount": 7800000.00
  }
]
```

---

#### 7.9.5 根据主键查询污染/环保费用年度记录

**接口描述**：根据股票代码和年份精确查询单条污染/环保费用数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/pollution-fee/{stokeName}/{year}`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**路径参数：**

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| stokeName | String | 是 | 股票代码（主键） |
| year | Integer | 是 | 年份（主键） |

**请求示例：**
```
GET /api/pollution-fee/688001/2023
```

**响应示例：**

成功响应（200）：
```json
{
  "stokeName": "688001",
  "year": 2023,
  "item": "污水处理设施运营及维护费用",
  "environmentAmount": 9200000.00
}
```

未找到响应（404）：
```json
{
  "error": "记录不存在"
}
```

---

#### 7.9.6 查询所有污染/环保费用年度记录

**接口描述**：获取所有污染/环保费用年度数据记录。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/pollution-fee/all`
- **是否需要认证**：是（支持 API Key 或 Session 认证）

**请求参数**：无

**请求示例：**
```
GET /api/pollution-fee/all
```

**响应示例：**
```json
[
  {
    "stokeName": "688001",
    "year": 2023,
    "item": "污水处理设施运营及维护费用",
    "environmentAmount": 9200000.00
  },
  {
    "stokeName": "688002",
    "year": 2023,
    "item": "固体废物处理费用",
    "environmentAmount": 5600000.00
  }
]
```

---

## 地图接口

### 5.1 获取大湾区边界数据

**接口描述**：获取粤港澳大湾区地理边界的 GeoJSON 数据。

**请求信息：**
- **请求方式**：GET
- **请求路径**：`/api/map/gba_boundary`
- **是否需要认证**：否

**请求参数**：无

**响应示例：**
```json
{
  "type": "FeatureCollection",
  "features": [...]
}
```

---

## 附录

### A. 数据字典

#### A.1 `dim_company` 表字段说明

| 字段名 | 类型 | 说明 |
|--------|------|------|
| stockName | varchar(20) | 股票代码（主键） |
| secShortName | varchar(100) | 股票简称 |
| fullNameCn | varchar(255) | 公司全称（中文） |
| fullNameEn | varchar(255) | 公司全称（英文） |
| industryCode | varchar(50) | 行业代码 |
| industryName | varchar(255) | 行业名称 |
| creditCode | varchar(64) | 统一社会信用代码 |
| legalRepresentative | varchar(100) | 法定代表人 |
| companyStatus | varchar(50) | 公司状态 |
| registeredAddress | varchar(500) | 注册地址 |
| officeAddress | varchar(500) | 办公地址 |
| officeLng | decimal(12,6) | 办公地点经度 |
| officeLat | decimal(12,6) | 办公地点纬度 |
| marketType | varchar(50) | 市场类型 |
| exchangeName | varchar(50) | 交易所名称 |
| firstListedDate | date | 首次上市日期 |
| listYear | year | 上市年份 |
| boardSecretary | varchar(100) | 董事会秘书 |
| secretaryPhone | varchar(50) | 董秘联系电话 |
| secretaryEmail | varchar(100) | 董秘邮箱 |
| securitiesRepresentative | varchar(100) | 证券事务代表 |
| registeredCapital | decimal(20,2) | 注册资本 |
| website | varchar(255) | 公司网站 |
| businessScope | text | 经营范围 |
| dataSource | varchar(100) | 数据来源 |
| remark | varchar(500) | 备注 |

### B. 错误码说明

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| 401 | 未登录或会话无效 | 请先登录或重新登录 |
| 404 | 资源不存在 | 检查请求的资源 ID 是否正确 |
| 400 | 请求参数错误 | 检查请求参数格式和内容 |
| 500 | 服务器内部错误 | 联系系统管理员 |

### C. 更新日志

| 版本号 | 更新日期 | 更新内容 | 更新人 |
|--------|----------|----------|--------|
| v1.0 | 2025-11-18 | 初始版本，新增公司维度表查询接口 | 系统 |

---

## 联系方式

如有疑问或建议，请联系开发团队：
- 邮箱：dev@example.com
- 技术支持：support@example.com

---

**文档结束**
