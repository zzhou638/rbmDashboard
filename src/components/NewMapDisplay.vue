<template>
  <div class="new-map-display">
    <div id="mb-map" ref="mapContainer"></div>
    
    <!-- 工厂信息卡片 -->
    <FactoryInfoCard ref="factoryCard" />
    <CompanyInfoCard ref="companyCard" />
    <CarbonEmissionCard ref="carbonCard" />
    
    <!-- 数据切换面板 -->
    <div class="mode-switch-panel" :class="{ 'chat-open': isChatOpen }">
      <div class="mode-buttons">
        <div class="panel-glow"></div>
        <div class="panel-border"></div>
        <button v-for="mode in modes" :key="mode.value" :class="['mode-btn', { active: currentMode === mode.value }]"
          @click="switchMode(mode.value)">
          <span class="mode-text">{{ mode.label }}</span>
          <div class="mode-indicator"></div>
        </button>
      </div>
    </div>

    <!-- 图层控制面板 (左上角) -->
    <div class="layer-control-panel" v-if="currentMode !== 'location'">
      <div class="layer-buttons">
        <button 
          v-for="layer in layers" 
          :key="layer.value" 
          :class="['layer-btn', { active: activeLayers.includes(layer.value) }]"
          @click="toggleLayer(layer.value)"
        >
          <span class="layer-icon" :class="layer.iconClass"></span>
          <span class="layer-text">{{ layer.label }}</span>
          <div class="layer-indicator"></div>
        </button>
      </div>
    </div>

    <!-- 地点图例（仅在 location 模式显示） -->
    <div class="map-legend" :class="{ hidden: currentMode !== 'location' }">
      <ul>
        <li>
          <span class="legend-dot dot-factory" aria-hidden="true"></span>
          <span class="legend-label">工厂</span>
        </li>
        <li>
          <span class="legend-dot dot-company" aria-hidden="true"></span>
          <span class="legend-label">企业</span>
        </li>
        <li>
          <span class="legend-dot dot-sampling" aria-hidden="true"></span>
          <span class="legend-label">采样点</span>
        </li>
      </ul>
    </div>
    
    <!-- 底图切换按钮（仅在3D模式显示，右上角） -->
    <div class="basemap-toggle-panel" v-if="is3DMode">
      <div class="basemap-segmented-control">
        <div 
          class="segment-option" 
          :class="{ active: baseMapType === 'satellite' }"
          @click="setBaseMapType('satellite')"
        >
          <span class="segment-icon">🛰️</span>
          <span class="segment-text">卫星</span>
        </div>
        <div 
          class="segment-option" 
          :class="{ active: baseMapType === 'streets' }"
          @click="setBaseMapType('streets')"
        >
          <span class="segment-icon">🗺️</span>
          <span class="segment-text">街道</span>
        </div>
        <div class="segment-glider" :class="baseMapType"></div>
      </div>
    </div>

    <!-- Hover Tooltip for City/District Names -->
    <div 
      v-if="hoverTooltip.visible" 
      class="map-hover-tooltip"
      :style="{ left: hoverTooltip.x + 'px', top: hoverTooltip.y + 'px' }"
    >
      {{ hoverTooltip.text }}
    </div>

  </div>
</template>

<script>
import mapboxgl from 'mapbox-gl'
import { http } from '@/api/api'
import bus from '@/bus'
import FactoryInfoCard from './FactoryInfoCard.vue'
import CarbonEmissionCard from './CarbonEmissionCard.vue'
import CompanyInfoCard from './CompanyInfoCard.vue'
import { PUBLIC_KEY } from '@/public_token/mapboxgl.js'

export default {
  name: 'NewMapDisplay',
  components: {
    FactoryInfoCard,
    CarbonEmissionCard,
    CompanyInfoCard
  },
  props: {
    isChatOpen: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      map: null,
      mapLoaded: false, // 标记地图样式是否加载完成
      boundary: null,
      labelFeatures: null,
      allPointsData: null, // 所有点位数据
      factoryData: null, // 工厂点数据（用于兼容）
      companyData: null, // 企业点数据（用于兼容）
      carbonData: null, // 采样点数据（用于兼容）
      buildingData: null, // 建筑物数据
      is3DMode: false, // 是否处于3D建筑物模式
      buildingMarkers: [], // 建筑物标签标记数组 (deprecated, using visibleMarkers map now)
      visibleMarkers: new Map(), // 当前显示的标记 Map<featureId, Marker>
      maxVisibleMarkers: 10, // 最大显示数量


      blankStyle: null,
      currentMode: 'city', // 当前选中的模式
      currentScale: 'City',
      modes: [
        { value: 'city', label: '市级', scale: 'City' },
        { value: 'district', label: '区级', scale: 'District' },
        { value: 'location', label: '地点', scale: 'Location' }
      ],
      activeLayers: [], // 当前激活的图层
      carbonLayerData: null,
      tempLayerData: null,
      layers: [
        { value: 'carbon', label: '碳排放', iconClass: 'icon-carbon' },
        { value: 'temperature', label: '温度', iconClass: 'icon-temp' }
      ],
      baseMapType: 'satellite', // 底图类型: 'satellite' 或 'streets'
      hoverTooltip: {
        visible: false,
        x: 0,
        y: 0,
        text: ''
      },
      hoveredFeatureId: null  // Track currently hovered feature ID
    }
  },
  watch: {
    isChatOpen() {
      this.$nextTick(() => {
        if (this.map) {
          this.map.resize()
        }
      })
    }
  },
  async mounted() {
    // Preload boundary data for City and District on initialization
    console.log('[Init] Preloading boundary data for City and District')
    await Promise.all([
      this.preloadBoundaryData('City'),
      this.preloadBoundaryData('District')
    ])
    console.log('[Init] Boundary data preloading complete')
    
    // 空白样式
    const blankStyle = {
      version: 8,
      name: 'blank',
      glyphs: "mapbox://fonts/mapbox/{fontstack}/{range}.pbf", // 需要有效 token
      sources: {},
      // 光照配置 - fill-extrusion 图层必需
      light: {
        anchor: 'viewport',
        color: '#ffffff',
        intensity: 0.4,
        position: [1.5, 90, 80]
      },
      layers: [
        {
          id: 'background',
          type: 'background',
          paint: {
            'background-color': '#020617' // 大屏背景色
          }
        }
      ]
    };
    this.blankStyle = blankStyle;
    this.initMap()
    
    // 确保容器初次渲染后尺寸就绪
    this.$nextTick(() => {
      setTimeout(() => { if (this.map) this.map.resize() }, 0)
    })

    // 恢复加载边界和点位数据
    this.fetchBoundaryByScale('City')
    this.fetchMapData()
    // 加载建筑物数据
    this.fetchBuildingData()
  },
  beforeDestroy() {
    this.clearBuildingMarkers()
    if (this.map) {
      this.map.remove()
    }
  },
  methods: {
    initMap() {
      mapboxgl.accessToken = PUBLIC_KEY
      const map = new mapboxgl.Map({
        container: this.$refs.mapContainer,
        // style: 'mapbox://styles/mapbox/dark-v11',
        style: this.blankStyle,
        center: [113.45, 23.17],
        zoom: 9, // 初始视角稍微拉远一点，看全大湾区
        pitch: 0, // 初始 2D 视角
        bearing: 0, // 地图旋转角度
        maxPitch: 85 // 允许更大的倾斜角度
      })

      map.on('load', () => {
        this.mapLoaded = true
        console.log('[Map] 地图加载完成')
        
        // 渲染所有点位（统一图层，根据type动态设置颜色）
        if (this.allPointsData) {
          this.renderAllPoints()
        }
        // 渲染边界面（在点位上层）
        if (this.boundary) {
          this.renderBoundary()
        }
        // 渲染建筑物（如果有数据）
        if (this.buildingData) {
          this.renderBuildings()
        }
      })
      this.$nextTick(() => setTimeout(() => map.resize(), 0))
      this.map = map
    },
    // Save boundary data to sessionStorage
    saveBoundaryToCache(scale, data) {
      try {
        const key = `boundary_${scale}`
        sessionStorage.setItem(key, JSON.stringify(data))
        console.log(`[Cache] Saved ${scale} boundary data to sessionStorage`)
      } catch (e) {
        console.warn('[Cache] Failed to save to sessionStorage:', e)
      }
    },
    
    // Load boundary data from sessionStorage
    loadBoundaryFromCache(scale) {
      try {
        const key = `boundary_${scale}`
        const cached = sessionStorage.getItem(key)
        if (cached) {
          console.log(`[Cache] Loaded ${scale} boundary data from sessionStorage`)
          return JSON.parse(cached)
        }
      } catch (e) {
        console.warn('[Cache] Failed to load from sessionStorage:', e)
      }
      return null
    },
    
    // Preload boundary data for a specific scale
    async preloadBoundaryData(scale) {
      console.log('[Preload] Fetching boundary data for scale:', scale)
      try {
        const res = await http.get('map/gba_boundary', { params: { scale } })
        console.log('[Preload] Boundary data received for scale:', scale, 'Features:', res.data?.features?.length)
        this.saveBoundaryToCache(scale, res.data)
        return res.data
      } catch (err) {
        console.error(`[Preload] Failed to load ${scale} boundary data:`, err)
        return null
      }
    },
    
    fetchBoundaryByScale(scale) {
      console.log('[Fetch Boundary] Loading boundary data for scale:', scale)
      
      // Try to load from cache first
      let boundaryData = this.loadBoundaryFromCache(scale)
      
      if (boundaryData) {
        console.log('[Fetch Boundary] Using cached data for scale:', scale)
        this.boundary = boundaryData
        this.updateOverviewCounts(boundaryData)
        
        if (this.mapLoaded) {
          console.log('[Fetch Boundary] Map is loaded, rendering boundary and labels')
          if (this.allPointsData && !this.map.getLayer('all-points')) {
            this.renderAllPoints()
          }
          this.renderBoundary()
        }
      } else {
        // Fallback: fetch from server if not cached
        console.log('[Fetch Boundary] No cache found, fetching from server for scale:', scale)
        http.get('map/gba_boundary', { params: { scale } })
          .then(res => {
            console.log('[Fetch Boundary] Boundary data received for scale:', scale, 'Features:', res.data?.features?.length)
            this.boundary = res.data
            this.saveBoundaryToCache(scale, res.data)
            this.updateOverviewCounts(res.data)

            if (this.mapLoaded) {
              console.log('[Fetch Boundary] Map is loaded, rendering boundary and labels')
              if (this.allPointsData && !this.map.getLayer('all-points')) {
                this.renderAllPoints()
              }
              this.renderBoundary()
            } else {
              console.warn('[Fetch Boundary] Map not loaded yet, boundary will render when map loads')
            }
          })
          .catch(err => {
            console.error('加载边界数据失败:', err)
          })
      }
    },
    fetchMapData() {
      console.log('[Map Data] 开始加载地图数据...')
      
      // 获取所有点位数据 - GET /api/map/data
      http.get('map/data')
        .then(res => {
          const allData = res.data
          console.log('[Map Data] 所有数据加载成功:', {
            type: allData?.type,
            totalFeatures: allData?.features?.length
          })
          
          if (!allData || !allData.features) {
            console.warn('[Map Data] 数据格式错误')
            return
          }
          
          // 保存完整的数据集
          // 规范化 type 字段，兼容后端不同命名
          try {
            allData.features.forEach(f => {
              if (!f || !f.properties) return
              let t = f.properties.type
              if (t == null) {
                // 尝试常见备用字段
                t = f.properties.type_name || f.properties.kind || f.properties.category || f.properties.TYPE || f.properties.Type
              }
              if (t != null) {
                const s = String(t).toLowerCase()
                if (s.includes('factory') || s.includes('工厂') || s.includes('厂')) {
                  f.properties.type = 'factory'
                } else if (s.includes('company') || s.includes('enterprise') || s.includes('企业') || s.includes('companyname')) {
                  f.properties.type = 'company'
                } else if (s.includes('sampling') || s.includes('sample') || s.includes('采样') || s.includes('samplingpoint') || s.includes('采样点')) {
                  f.properties.type = 'samplingPoint'
                } else {
                  // 若无法识别，保留原始小写值以便后续调试
                  f.properties.type = s
                }
              }
            })
          } catch (e) {
            console.warn('[Map Data] 规范化 type 字段失败', e)
          }

          this.allPointsData = allData

          // 统计各类型数量
          const typeCounts = {}
          allData.features.forEach(feature => {
            const type = feature.properties?.type || 'unknown'
            typeCounts[type] = (typeCounts[type] || 0) + 1
          })
          
          console.log('[Map Data] 点位类型统计:', typeCounts)
          
          // 如果地图已加载，立即渲染所有点位
          if (this.mapLoaded) {
            this.renderAllPoints()
          }
        })
        .catch(err => {
          console.error('[Map Data] 加载地图数据失败:', err)
        })
    },
    fetchBuildingData() {
      console.log('[Building Data] 开始加载建筑物数据...')
      http.get('map/company-buildings')
        .then(res => {
          this.buildingData = res.data
          console.log('[Building Data] 建筑物数据加载成功, feature count:', this.buildingData?.features?.length)
          if (this.buildingData?.features?.length > 0) {
             console.log('[Building Data] Sample feature:', this.buildingData.features[0])
             console.log('[Building Data] Sample properties:', this.buildingData.features[0].properties)
             console.log('[Building Data] Sample geometry type:', this.buildingData.features[0].geometry?.type)
          }
          
          // 数据加载完成后，如果是3D模式则渲染
          console.log('[Building Data] mapLoaded:', this.mapLoaded, 'currentMode:', this.currentMode, 'is3DMode:', this.is3DMode)
          if (this.mapLoaded && this.is3DMode) {
            console.log('[Building Data] 地图已加载且处于3D模式，渲染建筑物...')
            this.renderBuildings()
          } else {
            console.log('[Building Data] 数据已加载，但未处于3D模式或地图未加载，暂不渲染')
          }
        })
        .catch(err => {
          console.error('[Building Data] 加载建筑物数据失败:', err)
        })
    },
    renderBuildings() {
      console.log('[Render Buildings] Called, checking conditions...')
      
      if (!this.map) return
      if (!this.buildingData || !this.buildingData.features || this.buildingData.features.length === 0) {
        console.log('[Render Buildings] buildingData is null or empty, aborting')
        return
      }
      
      const sourceId = 'buildings-source'
      const layerId = 'buildings-layer'

      // 1. 确保光照设置 (Crucial for 3D rendering)
      if (this.map.style) {
        // 即使有光照配置，也强制重置一下，确保参数正确
        this.map.setLight({
          anchor: 'viewport',
          color: '#ffffff',
          intensity: 0.4,
          position: [1.5, 90, 80]
        })
      }

      try {
        // 2. 处理数据源
        const source = this.map.getSource(sourceId)
        if (source) {
          console.log('[Render Buildings] Updating existing source data')
          source.setData(this.buildingData)
        } else {
          console.log('[Render Buildings] Adding new source')
          this.map.addSource(sourceId, {
            type: 'geojson',
            data: this.buildingData
          })
        }

        // 3. 处理图层
        const heightMultiplier = 8
        if (this.map.getLayer(layerId)) {
          console.log('[Render Buildings] Layer exists, ensuring visibility')
          this.map.setLayoutProperty(layerId, 'visibility', 'visible')
        } else {
          console.log('[Render Buildings] Adding new layer')
          this.map.addLayer({
            id: layerId,
            type: 'fill-extrusion',
            source: sourceId,
            paint: {
              'fill-extrusion-color': [
                'match',
                ['get', 'pt_type'],
                'factory', '#FF4D4F',
                'company', '#FADB14',
                '#00FFFF'
              ],
              'fill-extrusion-height': ['*', ['coalesce', ['get', 'height'], 20], heightMultiplier],
              'fill-extrusion-base': 0,
              'fill-extrusion-opacity': 0.9
            },
            layout: {
              'visibility': 'visible'
            }
          })
          
          // 移到顶层
          this.map.moveLayer(layerId)
        }
        
        // 渲染持久化标签
        this.renderBuildingMarkers()
        
      } catch (e) {
        console.error('[Render Buildings] Error handling layer/source:', e)
      }
      
      // 确保点位在最上层
      if (this.map.getLayer('all-points')) {
        this.map.moveLayer('all-points')
      }
    },
    // 计算建筑物最密集的区域中心点
    findDensestBuildingArea() {
      if (!this.buildingData?.features?.length) return null
      
      // 获取所有建筑物的中心点
      const centers = []
      this.buildingData.features.forEach(f => {
        const coords = f.geometry?.coordinates
        if (coords && coords[0]) {
          // 计算多边形的中心点
          let sumLng = 0, sumLat = 0, count = 0
          coords[0].forEach(c => {
            if (Array.isArray(c) && c.length >= 2) {
              sumLng += c[0]
              sumLat += c[1]
              count++
            }
          })
          if (count > 0) {
            centers.push([sumLng / count, sumLat / count])
          }
        }
      })
      
      console.log('[Dense Area] Total buildings:', centers.length)
      
      if (centers.length === 0) return null
      
      // 使用网格法找到最密集的区域
      // 将区域划分为网格，计算每个网格内的建筑物数量
      const gridSize = 0.01  // 约1公里的网格
      const gridCounts = {}
      
      centers.forEach(([lng, lat]) => {
        // 计算网格索引
        const gridX = Math.floor(lng / gridSize)
        const gridY = Math.floor(lat / gridSize)
        const key = `${gridX},${gridY}`
        
        if (!gridCounts[key]) {
          gridCounts[key] = { count: 0, sumLng: 0, sumLat: 0, buildings: [] }
        }
        gridCounts[key].count++
        gridCounts[key].sumLng += lng
        gridCounts[key].sumLat += lat
        gridCounts[key].buildings.push([lng, lat])
      })
      
      // 找到建筑物最多的网格
      let maxCount = 0
      let densestGrid = null
      
      Object.values(gridCounts).forEach(data => {
        if (data.count > maxCount) {
          maxCount = data.count
          densestGrid = data
        }
      })
      
      if (densestGrid && maxCount > 0) {
        const centerLng = densestGrid.sumLng / densestGrid.count
        const centerLat = densestGrid.sumLat / densestGrid.count
        console.log('[Dense Area] Densest grid has', maxCount, 'buildings at', [centerLng, centerLat])
        return [centerLng, centerLat]
      }
      
      // 如果没有找到密集区域，返回所有建筑物的中心
      let totalLng = 0, totalLat = 0
      centers.forEach(([lng, lat]) => {
        totalLng += lng
        totalLat += lat
      })
      return [totalLng / centers.length, totalLat / centers.length]
    },
    updateOverviewCounts(geojson) {
      const ring = this.getOuterRingFromGeojson(geojson)
      if (!ring || ring.length < 3) return
      const payload = {
        type: 'Polygon',
        coordinates: [ring]
      }
      http.post('companies/count-companies-by-polygon', payload)
        .then(res => {
          bus.$emit('overview:update', { items: [{ key: 'enterprise', value: res.data }] })
        })
        .catch(err => console.warn('[Companies Count] 请求失败:', err))
      http.post('factories/count-factories-by-polygon', payload)
        .then(res => {
          bus.$emit('overview:update', { items: [{ key: 'factory', value: res.data }] })
        })
        .catch(err => console.warn('[Factories Count] 请求失败:', err))
    },
    getOuterRingFromGeojson(geojson) {
      if (!geojson) return null
      const feature = Array.isArray(geojson.features) ? geojson.features[0] : geojson
      const geometry = feature?.geometry || feature
      if (!geometry) return null
      if (geometry.type === 'Polygon') {
        return Array.isArray(geometry.coordinates) ? geometry.coordinates[0] : null
      }
      if (geometry.type === 'MultiPolygon') {
        return Array.isArray(geometry.coordinates) ? geometry.coordinates[0]?.[0] : null
      }
      return null
    },

    renderBoundary() {
      if (!this.map || !this.boundary) return;
      
      // Remove highlight layer before recreating boundary layers
      this.removeHighlightLayer();
      
      // Also hide tooltip
      this.hoverTooltip.visible = false;
      
      const sourceId = 'gba-boundary'
      const labelSourceId = 'gba-label-source'
      const removeIfExists = id => {
        if (this.map.getLayer(id)) {
          this.map.removeLayer(id)
          console.log(`[Render Boundary] Removed layer: ${id}`)
        }
      }

      // 先删除所有使用该 source 的图层
      console.log('[Render Boundary] Removing existing layers...')
      removeIfExists('gba-label')
      removeIfExists('gba-fill')
      removeIfExists('gba-line')
      
      // 再删除 source
        if (this.map.getSource(sourceId)) {
          this.map.removeSource(sourceId)
          console.log('[Render Boundary] Removed source:', sourceId)
        }
      if (this.map.getSource(labelSourceId)) {
        this.map.removeSource(labelSourceId)
        console.log('[Render Boundary] Removed source:', labelSourceId)
        }

      // 生成一个带统一标签字段的副本，保证不同数据源的名称属性能被 label layer 读取
      let boundaryData = this.boundary
      try {
        boundaryData = JSON.parse(JSON.stringify(this.boundary))
        const features = boundaryData.type === 'FeatureCollection' ? boundaryData.features : [boundaryData]
        const nameCandidates = ['名称_nam', 'name', '名称', 'NAME', 'name_cn', 'nam']
        features.forEach(f => {
          if (!f || !f.properties) return
          for (const k of nameCandidates) {
            const v = f.properties[k]
            if (v) {
              f.properties.labelName = v
              break
            }
          }
          // fallback to empty string to avoid nulls
          if (!f.properties.labelName) f.properties.labelName = ''
        })
      } catch (e) {
        console.warn('复制 boundary 数据用于标签失败，使用原始数据', e)
        boundaryData = this.boundary
      }

        this.map.addSource(sourceId, {
          type: 'geojson',
          data: boundaryData
      })
      
      // Regenerate label features based on current boundary data and scale
      // This ensures labels are always up-to-date when switching layers
      const currentLabelFeatures = this.buildLabelPoints(this.boundary, this.currentScale)
      console.log('[Render Boundary] Regenerated label features for scale:', this.currentScale, 'Count:', currentLabelFeatures?.features?.length || 0)
      
      if (currentLabelFeatures?.features?.length > 0) {
        console.log('[Render Boundary] Sample label feature:', currentLabelFeatures.features[0])
      }
      this.map.addSource(labelSourceId, {
        type: 'geojson',
        data: currentLabelFeatures || { type: 'FeatureCollection', features: [] }
        })

      // GBA面要素
      this.map.addLayer({
        id: "gba-fill",
        type: "fill",
        source: sourceId,
        filter: ['any',
          ['==', ['geometry-type'], 'Polygon'],
          ['==', ['geometry-type'], 'MultiPolygon']
        ],
        paint: {
          'fill-color': '#62b1ff',
          'fill-opacity': 0.25
        }
      })

      // GBA线要素
        this.map.addLayer({
        id: "gba-line",
        type: "line",
          source: sourceId,
        filter: ["any",
          ['==', ['geometry-type'], 'Polygon'],
          ['==', ['geometry-type'], 'MultiPolygon'],
          ['==', ['geometry-type'], 'LineString'],
          ['==', ['geometry-type'], 'MultiLineString']
        ],
          paint: {
          'line-color': '#62b1ff',
          'line-width': 2
          }
        })

      // GBA Label
      // 城市名称标注（基于属性：labelName）
      console.log('[Render Boundary] Adding label layer')
        this.map.addLayer({
        id: 'gba-label',
        type: 'symbol',
        source: labelSourceId,
        minzoom: 0,  // Show at all zoom levels
        maxzoom: 24,
        filter: ['any',
          ['==', ['geometry-type'], 'Point']  // Label source contains Point features, not Polygon
        ],
        layout: {
          // 取我们预先生成的统一标签字段：labelName
          'text-field': ['get', 'labelName'],
          'text-font': ['Noto Sans Regular', 'Arial Unicode MS Regular'],  // Fonts with Chinese support
          'text-size': 18,  // Increased size
          'symbol-placement': 'point',
          'text-allow-overlap': true,
          'text-ignore-placement': true,  // Force display
          'text-anchor': 'center',
          'visibility': 'visible'
        },
          paint: {
          'text-color': '#FFFFFF',  // White text
          'text-halo-color': '#000000',  // Black halo
          'text-halo-width': 2
          }
      });
      
      // Move label layer to top to ensure it's not covered by other layers
      this.map.moveLayer('gba-label');
      
      console.log('[Render Boundary] Label layer added successfully');
      
      // Comprehensive debug checks
      const labelLayer = this.map.getLayer('gba-label');
      console.log('[Render Boundary] Label layer exists:', !!labelLayer);
      console.log('[Render Boundary] Label layer type:', labelLayer?.type);
      console.log('[Render Boundary] Label layer visibility:', this.map.getLayoutProperty('gba-label', 'visibility'));
      console.log('[Render Boundary] Label layer text-field:', this.map.getLayoutProperty('gba-label', 'text-field'));
      console.log('[Render Boundary] Label layer text-size:', this.map.getLayoutProperty('gba-label', 'text-size'));
      console.log('[Render Boundary] Label layer text-color:', this.map.getPaintProperty('gba-label', 'text-color'));
      
      // Check source data
      const labelSource = this.map.getSource(labelSourceId);
      if (labelSource && labelSource._data) {
        console.log('[Render Boundary] Label source data features:', labelSource._data.features?.length);
      }
      const bbox = this.computeGeoJSONBounds(this.boundary)
      console.log('fitBounds bbox:', bbox)
      if (bbox) {
        // fitBounds 后保持 3D 视角（pitch）
        this.map.fitBounds(bbox, { 
          padding: 40, 
          duration: 0,
          pitch: this.is3DMode ? 80 : 0,  // 仅在 3D 模式下保持倾斜，否则为 0
          bearing: 0
        })
      }
      
      // 在市级或区级模式下渲染建筑物 3D 图层（如果数据已加载且处于3D模式）
      if ((this.currentMode === 'city' || this.currentMode === 'district') && this.is3DMode && this.buildingData && this.buildingData.features && this.buildingData.features.length > 0) {
        console.log('[renderBoundary] 建筑物数据已存在且处于3D模式，开始渲染...')
        this.renderBuildings()
      } else {
        console.log('[renderBoundary] 暂不渲染建筑物 (is3DMode=' + this.is3DMode + ')')
      }
      
      // 确保点图层始终在最顶层
      if (this.map.getLayer('all-points')) {
        this.map.moveLayer('all-points')
        console.log('[Layer Order] 点图层已移至顶层')
      }
      
      // 使用 map idle 事件确保标签图层在所有渲染完成后移至最顶层
      this.map.once('idle', () => {
        if (this.map && this.map.getLayer('gba-label')) {
          this.map.moveLayer('gba-label')
          console.log('[Layer Order] 标签图层已移至最顶层 (idle事件触发)')
        } else {
          console.warn('[Layer Order] 标签图层不存在，无法移至顶层')
        }
      })
      
      // 绑定点击事件
      this.bindIdentify()
      
      // 绑定悬浮提示事件
      this.bindHoverTooltip()
    },
    computeGeoJSONBounds(geojson) {
      try {
        const coords = []
        const push = c => coords.push(c)
        const walk = g => {
          if (!g) return
          const t = g.type
          if (t === "Point") push(g.coordinates)
          else if (t === 'MultiPoint' || t === 'LineString') g.coordinates.forEach(push)
          else if (t === 'MultiLineString' || t === 'Polygon') g.coordinates.flat(1).forEach(push)
          else if (t === 'MultiPolygon') g.coordinates.flat(2).forEach(push)
          else if (t === 'GeometryCollection') g.geometries.forEach(walk)
        }

        if (geojson.type === 'FeatureCollection') geojson.features.forEach(f => walk(f.geometry))
        else if (geojson.type === 'Feature') walk(geojson.geometry)
        else walk(geojson)
        if (!coords.length) return null

        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        coords.forEach(([x, y]) => {
          if (x < minX) minX = x
          if (y < minY) minY = y
          if (x > maxX) maxX = x
          if (y > maxY) maxY = y
        })
        return [[minX, minY], [maxX, maxY]]
      } catch (e) {
        console.error('计算GeoJSON边界失败:', e)
        return null
      }
    },
    switchMode(mode) {
      if (this.currentMode === mode) return
      this.currentMode = mode
      const target = this.modes.find(item => item.value === mode)
      const scale = target ? target.scale : 'City'
      this.currentScale = scale
      
      // 发送模式切换事件给 CarbonEmissionBar 组件
      bus.$emit('mode:switch', mode);
      
      // 地点模式：先恢复 2D 视角，再显示点位
      if (mode === 'location') {
        // 确保城市边界显示
        if (!this.boundary) {
          this.fetchBoundaryByScale('City')
        }
        
        // 1. 立即隐藏建筑物和标记
        if (this.map.getLayer('buildings-layer')) {
          this.map.setLayoutProperty('buildings-layer', 'visibility', 'none')
        }
        this.clearBuildingMarkers()
        this.is3DMode = false

        // 2. 添加卫星底图图层
        this.addMapboxBaseLayer('satellite')
        
        // 3. 隐藏边界填充图层，避免遮挡卫星底图
        if (this.map.getLayer('gba-fill')) {
          this.map.setLayoutProperty('gba-fill', 'visibility', 'none')
        }

        // 4. 隐藏所有点位（防止在 3D 视角下显示）
        if (this.map.getLayer('all-points')) {
          this.map.setLayoutProperty('all-points', 'visibility', 'none')
        }

        // 5. 飞向 2D 视图
        this.map.flyTo({
          pitch: 0,
          bearing: 0,
          zoom: 10, // 稍微拉近一点
          duration: 1500
        })

        // 6. 动画结束后显示点位
        this.map.once('moveend', () => {
          if (this.currentMode === 'location') {
             if (this.map.getLayer('all-points')) {
               this.map.setLayoutProperty('all-points', 'visibility', 'visible')
             } else if (this.allPointsData) {
               this.renderAllPoints()
             }
          }
        })

      } else {
        // 其他模式：隐藏所有点位，更新边界
        if (this.map.getLayer('all-points')) {
          this.map.setLayoutProperty('all-points', 'visibility', 'none')
        }
        
        // 移除卫星底图图层(如果从地点模式切换过来)
        this.removeMapboxBaseLayer()
        
        // 恢复边界填充图层的显示
        if (this.map.getLayer('gba-fill')) {
          this.map.setLayoutProperty('gba-fill', 'visibility', 'visible')
        }
        
        // 检查是否重新点击了当前模式（市级或区级）
        const isReClickingSameMode = this.currentMode === mode && (mode === 'city' || mode === 'district')
        
        // 如果重新点击相同模式且处于3D模式，退出3D模式
        if (isReClickingSameMode && this.is3DMode) {
          console.log('[Mode Switch] 重新点击相同模式，退出3D模式')
          this.is3DMode = false
          this.clearBuildingMarkers()
          
          // 隐藏建筑物
          if (this.map.getLayer('buildings-layer')) {
            this.map.setLayoutProperty('buildings-layer', 'visibility', 'none')
          }
          
          // 飞回2D视图
          this.map.flyTo({
            pitch: 0,
            bearing: 0,
            zoom: 9,
            duration: 1500
          })
        }
        
        // 市级和区级模式显示建筑物，其他模式隐藏
        if (mode === 'city' || mode === 'district') {
          // 重新加载建筑物数据，防止渲染黑屏问题
          this.fetchBuildingData()
          
          if (this.is3DMode) {
            if (this.map.getLayer('buildings-layer')) {
              this.map.setLayoutProperty('buildings-layer', 'visibility', 'visible')
            }
            // 恢复标记
            this.updateVisibleMarkers()
          }
        } else {
          // 其他非location模式，确保建筑物隐藏
          this.is3DMode = false
          this.clearBuildingMarkers()
          
          this.map.flyTo({
            pitch: 0,
            zoom: 9,
            duration: 1500
          })
          
          if (this.map.getLayer('buildings-layer')) {
            this.map.setLayoutProperty('buildings-layer', 'visibility', 'none')
          }
        }
        
        this.fetchBoundaryByScale(scale)
        
        // 关闭所有卡片
        this.$refs.companyCard && this.$refs.companyCard.close && this.$refs.companyCard.close()
        this.$refs.factoryCard && this.$refs.factoryCard.close && this.$refs.factoryCard.close()
        this.$refs.carbonCard && this.$refs.carbonCard.close && this.$refs.carbonCard.close()
      }
    },
    
    // 处理建筑物点击逻辑
    handleBuildingClick(properties) {
      if (!properties) return;
      
      const type = properties.pt_type;
      console.log('[Building Click] Type:', type, 'Properties:', properties);
      
      if (type === 'company') {
        let stockCode = properties.pt_stock_n;
        if (stockCode) {
          // Ensure it's a string and pad to 6 digits (corrected from 8)
          stockCode = String(stockCode).padStart(6, '0');
          console.log('[Building Click] Opening Company Card with Stock Code:', stockCode);
          this.$refs.companyCard.show(stockCode);
        } else {
          console.warn('[Building Click] Company building missing pt_stock_n');
          // Fallback to name if available
          const name = properties.pt_name || properties.name;
          if (name) this.$refs.companyCard.show(name);
        }
      } else if (type === 'factory') {
        // 使用工厂名称查询
        const factoryName = properties.pt_name || properties.name;
        if (factoryName) {
          console.log('[Building Click] Opening Factory Card with Name:', factoryName);
          this.$refs.factoryCard.show(factoryName);
        } else {
          console.warn('[Building Click] Factory building missing pt_name/name', properties);
        }
      } else {
        // Fallback for other types or unknown types
        const name = properties.pt_name || properties.name;
        if (name) {
             console.log('[Building Click] Opening Company Card with Name (Fallback):', name);
             this.$refs.companyCard.show(name);
        }
      }
    },

    // 点击事件，点击地图输出对应的属性
    bindIdentify() {
      if (!this.map) return;
      // 先解绑，避免重复绑定多次
      this.map.off('click', this._onMapClick);

      // 保存回调引用
      this._onMapClick = (e) => {
        const px = e.point;
        const tolerance = 5; // 加一点容差，提高命中率
        // 使用二维数组 bbox：[[minX,minY],[maxX,maxY]]
        const bbox = [
          [px.x - tolerance, px.y - tolerance],
          [px.x + tolerance, px.y + tolerance]
        ];

        // 根据当前模式决定查询哪些图层
        let features;
        if (this.currentMode === 'location') {
          // 地点模式：查询所有点图层
          
          // 查询所有点位
          const pointFeatures = this.map.queryRenderedFeatures(bbox, { layers: ['all-points'] });
          if (pointFeatures && pointFeatures.length) {
            const f = pointFeatures[0];
            const pointType = f.properties?.type;
            console.log('[Map Identify] 命中点位:', { type: pointType, properties: f.properties });
            
            // 根据点位类型显示对应的卡片
            if (pointType === 'samplingPoint') {
              // 提取采样点的 number 字段
              const number = f.properties.number || f.properties.Number || f.properties.NUMBER
              if (number) {
                console.log('[Map Identify] 采样点 number:', number)
                this.$refs.carbonCard && this.$refs.carbonCard.show && this.$refs.carbonCard.show(number)
              } else {
                console.warn('[Map Identify] 采样点缺少 number 字段', f.properties)
              }
              return
            } else if (pointType === 'company') {
              const stockName = f.properties.stock_name || f.properties.stockName || f.properties.stock_code;
              if (stockName) {
                this.$refs.companyCard.show(stockName);
                return
              }
            } else if (pointType === 'factory') {
              const factoryUuid = f.properties.factory_uu || f.properties.factoryUuid || f.properties.factory_uuid || f.properties.uuid;
              if (factoryUuid) {
                this.$refs.factoryCard.show(factoryUuid);
                return
              }
            }
          }

          // 如果都没命中，可以考虑关闭卡片（可选，或者点击空白处关闭）
          // this.$refs.carbonCard && this.$refs.carbonCard.close()
          // this.$refs.companyCard && this.$refs.companyCard.close()
          // this.$refs.factoryCard && this.$refs.factoryCard.close()
        } else {
          // 如果处于3D模式，优先查询建筑物
          if (this.is3DMode) {
            const buildingFeatures = this.map.queryRenderedFeatures(bbox, { layers: ['buildings-layer'] });
            if (buildingFeatures && buildingFeatures.length) {
              const f = buildingFeatures[0];
              this.handleBuildingClick(f.properties);
              return; // 阻止向下穿透到面图层
            }
          }

          // 市级和区级模式：查询面图层
          features = this.map.queryRenderedFeatures(bbox, { layers: ['gba-fill', 'gba-line'] });

          if (features && features.length) {
            const f = features[0];
            console.log('[Map Identify - Boundary] 命中面要素:', f);
            if (f && f.properties) {
              console.log('[Map Identify - Boundary] 属性:', f.properties);
              this.emitRegionFilter(f.properties);
              
              // 发送事件给 CarbonEmissionBar 组件
              bus.$emit('map:identify', f.properties);
            }

            // 提取边界坐标（按 GeoJSON 标准 [lng, lat]）
            try {
              const coords = this.extractCoordinatesFromFeature(f);
              
              // 如果是市级模式，且未处于3D模式，点击城市进入 3D 模式
              if (this.currentMode === 'city' && !this.is3DMode) {
                console.log('[Map Identify] 点击城市，准备进入3D模式:', f.properties);
                this.enter3DMode(f);
              }
              
              // 如果是区级模式，且未处于3D模式，点击区进入 3D 模式
              if (this.currentMode === 'district' && !this.is3DMode) {
                console.log('[Map Identify] 点击区，准备进入3D模式:', f.properties);
                this.enter3DMode(f);
              }

              if (coords && coords.length) {
                const requestBody = {
                  type: 'Polygon',
                  coordinates: [coords]
                };
                // 同时请求企业和工厂数量
                http.post('companies/count-companies-by-polygon', requestBody)
                  .then(res => {
                    console.log('[Map Identify] 企业数量:', res.data);
                    bus.$emit('overview:update', { items: [{ key: 'enterprise', value: res.data }] });
                  })
                  .catch(err => {
                    console.warn('[Map Identify] 企业请求失败:', err);
                  });
                
                http.post('factories/count-factories-by-polygon', requestBody)
                  .then(res => {
                    console.log('[Map Identify] 工厂数量:', res.data);
                    bus.$emit('overview:update', { items: [{ key: 'factory', value: res.data }] });
                  })
                  .catch(err => {
                    console.warn('[Map Identify] 工厂请求失败:', err);
                  });
              } else {
                console.log('[Map Identify] 未提取到坐标');
              }
            } catch (err) {
              console.warn('[Map Identify] 坐标提取失败:', err);
            }
          } else {
            console.log('[Map Identify - Boundary] 未命中任何面要素');
            // 点击空白处，如果处于3D模式，可以考虑退回2D（可选）
            // this.exit3DMode(); 
            this.emitRegionFilter(null);
          }
        }
      };

      // 在定义回调后注册一次
      this.map.on('click', this._onMapClick);
    },

    // Bind hover tooltip for city and district layers
    bindHoverTooltip() {
      if (!this.map) return;
      
      // Remove existing listeners to avoid duplicates
      this.map.off('mousemove', this._onMapMouseMove);
      this.map.off('mouseleave', this._onMapMouseLeave);

      // Mouse move handler
      this._onMapMouseMove = (e) => {
        // Disable hover in location mode or 3D mode
        if (this.currentMode === 'location' || this.is3DMode) {
          this.hoverTooltip.visible = false;
          // Remove highlight layer if exists
          this.removeHighlightLayer();
          return;
        }

        const px = e.point;
        const tolerance = 5;
        const bbox = [
          [px.x - tolerance, px.y - tolerance],
          [px.x + tolerance, px.y + tolerance]
        ];

        // Query boundary layers
        const features = this.map.queryRenderedFeatures(bbox, { 
          layers: ['gba-fill', 'gba-line'] 
        });

        if (features && features.length > 0) {
          const feature = features[0];
          const props = feature.properties;
          
          // Determine which field to use based on current mode
          let displayName = '';
          if (this.currentMode === 'city') {
            // City level: use CityCN field
            displayName = props.CityCN || props.citycn || props.CITYCN || 
                         props.city_cn || props.City_CN || '';
          } else if (this.currentMode === 'district') {
            // District level: use DistrictCN field
            displayName = props.DistrictCN || props.districtcn || props.DISTRICTCN || 
                         props.district_cn || props.District_CN || '';
          }

          if (displayName) {
            // Show tooltip
            this.hoverTooltip.visible = true;
            this.hoverTooltip.x = e.originalEvent.clientX + 10;
            this.hoverTooltip.y = e.originalEvent.clientY + 10;
            this.hoverTooltip.text = displayName;
            
            // Change cursor to pointer
            this.map.getCanvas().style.cursor = 'pointer';

            // Add highlight layer for this feature
            this.addHighlightLayer(feature);
          } else {
            this.hoverTooltip.visible = false;
            this.map.getCanvas().style.cursor = '';
            this.removeHighlightLayer();
          }
        } else {
          // No feature under cursor
          this.hoverTooltip.visible = false;
          this.map.getCanvas().style.cursor = '';
          this.removeHighlightLayer();
        }
      };

      // Mouse leave handler
      this._onMapMouseLeave = () => {
        this.hoverTooltip.visible = false;
        this.map.getCanvas().style.cursor = '';
        this.removeHighlightLayer();
      };

      // Register event listeners
      this.map.on('mousemove', this._onMapMouseMove);
      this.map.on('mouseleave', this._onMapMouseLeave);
    },

    // Add highlight layer for hovered feature
    addHighlightLayer(feature) {
      if (!this.map || !feature) return;
      
      const highlightLayerId = 'gba-highlight';
      const highlightSourceId = 'gba-highlight-source';
      
      // Check if we need to update (different feature)
      const currentSource = this.map.getSource(highlightSourceId);
      if (currentSource) {
        // Update existing source with new feature
        currentSource.setData({
          type: 'FeatureCollection',
          features: [feature]
        });
      } else {
        // Create new source and layers
        this.map.addSource(highlightSourceId, {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: [feature]
          }
        });
        
        // Add highlight fill layer
        this.map.addLayer({
          id: highlightLayerId + '-fill',
          type: 'fill',
          source: highlightSourceId,
          paint: {
            'fill-color': '#00f2ff',
            'fill-opacity': 0.5
          }
        });
        
        // Add highlight line layer
        this.map.addLayer({
          id: highlightLayerId + '-line',
          type: 'line',
          source: highlightSourceId,
          paint: {
            'line-color': '#00f2ff',
            'line-width': 3
          }
        });
      }
    },

    // Remove highlight layer
    removeHighlightLayer() {
      if (!this.map) return;
      
      const highlightLayerId = 'gba-highlight';
      const highlightSourceId = 'gba-highlight-source';
      
      // Remove layers
      if (this.map.getLayer(highlightLayerId + '-fill')) {
        this.map.removeLayer(highlightLayerId + '-fill');
      }
      if (this.map.getLayer(highlightLayerId + '-line')) {
        this.map.removeLayer(highlightLayerId + '-line');
      }
      
      // Remove source
      if (this.map.getSource(highlightSourceId)) {
        this.map.removeSource(highlightSourceId);
      }
    },
    
    // 从要素提取边界坐标，统一返回为数组：Array<[number, number]>
    extractCoordinatesFromFeature(feature) {
      if (!feature) return [];
      const geometry = feature.geometry || feature;
      const type = geometry && geometry.type;
      const result = [];

      // 将任意坐标嵌套结构拍平为点数组
      const pushCoord = (c) => {
        if (Array.isArray(c) && typeof c[0] === 'number' && typeof c[1] === 'number') {
          result.push([c[0], c[1]]);
        }
      };

      const walk = (g) => {
        if (!g) return;
        const t = g.type;
        if (t === 'Point') pushCoord(g.coordinates);
        else if (t === 'MultiPoint' || t === 'LineString') g.coordinates.forEach(pushCoord);
        else if (t === 'MultiLineString' || t === 'Polygon') g.coordinates.flat(1).forEach(pushCoord);
        else if (t === 'MultiPolygon') g.coordinates.flat(2).forEach(pushCoord);
        else if (t === 'GeometryCollection') (g.geometries || []).forEach(walk);
      };

      if (type) {
        walk(geometry);
      } else if (geometry && geometry.type === undefined && Array.isArray(geometry)) {
        // 直接传入坐标数组时
        geometry.forEach(pushCoord);
      }
      return result;
    },
    getLabelFieldByScale(scale) {
      if (scale === 'City') return 'CityCN'
      if (scale === 'District') return 'DistrictCN'
      if (scale === 'Companies') return 'CompanyName'
      if (scale === 'Factory') return 'factory_n'
      return 'CityCN'
    },
    buildLabelPoints(geojson, scale) {
      console.log('[Label Points] Building label points for scale:', scale)
      if (!geojson) {
        console.warn('[Label Points] No geojson data provided')
        return { type: 'FeatureCollection', features: [] }
      }
      const features = geojson.type === 'FeatureCollection' ? geojson.features : [geojson]
      const labelField = this.getLabelFieldByScale(scale)
      console.log('[Label Points] Using label field:', labelField, 'for', features.length, 'features')
      const grouped = new Map()

      features.forEach((feature, index) => {
        if (!feature || !feature.properties) return
        const geom = feature.geometry
        if (!geom || (geom.type !== 'Polygon' && geom.type !== 'MultiPolygon')) return
        const labelValue = feature.properties[labelField]
        if (!labelValue) {
          console.warn(`[Label Points] Feature ${index} missing ${labelField} field. Properties:`, Object.keys(feature.properties))
          return
        }
        const area = this.computeFeatureArea(geom)
        const existing = grouped.get(labelValue)
        if (!existing || area > existing.area) {
          grouped.set(labelValue, { feature, area })
        }
      })

      console.log('[Label Points] Grouped', grouped.size, 'unique labels')
      const labelFeatures = []
      
      // Manual position adjustments for specific cities
      const positionAdjustments = {
        '佛山市': { offsetLng: 0.15, offsetLat: -0.08 },  // Move Foshan right and down
        '珠海市': { offsetLng: -0.45, offsetLat: 0.05 },  // Move Zhuhai significantly left
        '深圳市': { offsetLng: 0, offsetLat: -0.03 } 
      }
      
      grouped.forEach(({ feature }, labelName) => {
        const centroid = this.computeFeatureCentroid(feature.geometry)
        if (!centroid) {
          console.warn('[Label Points] Could not compute centroid for:', labelName)
          return
        }
        
        // Apply manual adjustments if defined
        let adjustedCentroid = centroid
        const cityName = feature.properties[this.getLabelFieldByScale(scale)]
        if (positionAdjustments[cityName]) {
          const adjustment = positionAdjustments[cityName]
          adjustedCentroid = [
            centroid[0] + (adjustment.offsetLng || 0),
            centroid[1] + (adjustment.offsetLat || 0)
          ]
          console.log(`[Label Points] Adjusted ${cityName} position from`, centroid, 'to', adjustedCentroid)
        }
        
        labelFeatures.push({
          type: 'Feature',
          properties: {
            labelName: feature.properties[this.getLabelFieldByScale(scale)]
          },
          geometry: {
            type: 'Point',
            coordinates: adjustedCentroid
          }
        })
        console.log('[Label Points] Created label:', labelName, 'at', adjustedCentroid)
      })
      console.log('[Label Points] Generated', labelFeatures.length, 'label features')
      return { type: 'FeatureCollection', features: labelFeatures }
    },
    computeFeatureArea(geometry) {
      if (!geometry) return 0
      const type = geometry.type
      if (type === 'Polygon') return this.computePolygonArea(geometry.coordinates)
      if (type === 'MultiPolygon') {
        return geometry.coordinates.reduce((sum, poly) => sum + this.computePolygonArea(poly), 0)
      }
      return 0
    },
    computePolygonArea(coordinates) {
      if (!coordinates || !coordinates.length) return 0
      const outer = coordinates[0] || []
      let area = 0
      for (let i = 0, len = outer.length; i < len - 1; i++) {
        const [x1, y1] = outer[i]
        const [x2, y2] = outer[i + 1]
        area += (x1 * y2 - x2 * y1)
      }
      return Math.abs(area / 2)
    },
    computeFeatureCentroid(geometry) {
      if (!geometry) return null
      const bounds = this.computeGeometryBounds(geometry)
      if (!bounds) return null
      const [[minX, minY], [maxX, maxY]] = bounds
      return [(minX + maxX) / 2, (minY + maxY) / 2]
    },
    computeGeometryBounds(geometry) {
      const coords = []
      const push = c => coords.push(c)
      const walk = g => {
        if (!g) return
        const t = g.type
        if (t === 'Point') push(g.coordinates)
        else if (t === 'MultiPoint' || t === 'LineString') g.coordinates.forEach(push)
        else if (t === 'MultiLineString' || t === 'Polygon') g.coordinates.flat(1).forEach(push)
        else if (t === 'MultiPolygon') g.coordinates.flat(2).forEach(push)
        else if (t === 'GeometryCollection') g.geometries.forEach(walk)
      }
      walk(geometry)
      if (!coords.length) return null
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
      coords.forEach(([x, y]) => {
        if (x < minX) minX = x
        if (y < minY) minY = y
        if (x > maxX) maxX = x
        if (y > maxY) maxY = y
      })
      return [[minX, minY], [maxX, maxY]]
    },
    emitRegionFilter(properties) {
      if (!properties) {
        bus.$emit('overview:investmentFilter', null)
        return
      }
      const cityName = this.pickFirstAvailable(properties, ['CityCN', 'City', 'city', 'NAME', 'name', '名称_nam', '名称', 'labelName'])
      const districtName = this.pickFirstAvailable(properties, ['DistrictCN', 'District', 'district'])
      const filters = {}
      if (this.currentMode === 'city' || this.currentScale === 'City') {
        if (cityName) filters.city = cityName
      } else if (this.currentMode === 'district' || this.currentScale === 'District') {
        if (districtName) {
          filters.district = districtName
        } else if (cityName) {
          // Fallback：部分区级数据可能没有 DistrictCN 字段
          filters.district = cityName
        }
      }
      bus.$emit('overview:investmentFilter', Object.keys(filters).length ? filters : null)
    },
    pickFirstAvailable(obj, keys) {
      if (!obj || typeof obj !== 'object') return null
      const normalizedEntries = Object.keys(obj).map(key => ({ key, lower: key.toLowerCase() }))
      for (const targetKey of keys) {
        const lowerTarget = targetKey.toLowerCase()
        const match = normalizedEntries.find(entry => entry.lower === lowerTarget)
        if (match && obj[match.key]) return obj[match.key]
        if (Object.prototype.hasOwnProperty.call(obj, targetKey) && obj[targetKey]) {
          return obj[targetKey]
        }
      }
      return null
    },
    getScreenPosition(px) {
      const container = this.$refs.mapContainer;
      if (container && container.getBoundingClientRect) {
        const rect = container.getBoundingClientRect();
        return {
          x: rect.left + px.x,
          y: rect.top + px.y
        };
      }
      return { x: px.x, y: px.y };
    },
    renderAllPoints() {
      if (!this.map || !this.allPointsData) {
        console.log('[All Points Render] 跳过: map=', !!this.map, 'data=', !!this.allPointsData)
        return;
      }
      
      const sourceId = 'all-points-source'
      const layerId = 'all-points'
      
      console.log('[All Points Render] 开始渲染:', {
        featureCount: this.allPointsData?.features?.length
      })
      
      // 删除旧的图层和源
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      
      // 添加所有点位数据源
      this.map.addSource(sourceId, {
        type: 'geojson',
        data: this.allPointsData
      })
      
      // 添加统一点图层 - 根据type字段动态设置颜色
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          // 根据type字段设置不同半径
          'circle-radius': 4,
          // 根据type字段设置不同颜色
          'circle-color': [
            'match',
            ['get', 'type'],
            'factory', '#FF4D4F',      // 工厂: 红色
            'company', '#FADB14',      // 公司: 黄色
            'samplingPoint', '#52C41A', // 采样点: 绿色
            '#999999'                   // 默认: 灰色
          ],
          'circle-opacity': 0.95,
          'circle-stroke-width': [
            'match',
            ['get', 'type'],
            'factory', 1,
            'company', 1.5,
            'samplingPoint', 2,
            1.5
          ],
          'circle-stroke-color': '#ffffff',
          'circle-stroke-opacity': 0.9
        },
        layout: {
          'visibility': this.currentMode === 'location' ? 'visible' : 'none'
        }
      })
      
      // 确保点图层在所有图层的最顶层
      this.map.moveLayer(layerId)
      
      // 确认图层成功添加
      const layerExists = this.map.getLayer(layerId)
      console.log('[All Points] 所有点位图层添加完成:', {
        layerExists: !!layerExists,
        visibility: this.map.getLayoutProperty(layerId, 'visibility'),
        movedToTop: true
      })
    },
    renderFactoryPoints() {
      if (!this.map || !this.factoryData) {
        console.log('[Factory Render] 跳过: map=', !!this.map, 'data=', !!this.factoryData)
        return;
      }
      
      const sourceId = 'factory-source'
      const layerId = 'factory-points'
      
      console.log('[Factory Render] 开始渲染:', {
        featureCount: this.factoryData?.features?.length,
        firstFeature: this.factoryData?.features?.[0]
      })
      
      // 删除旧的图层和源
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      
      // 添加工厂点数据源
      this.map.addSource(sourceId, {
        type: 'geojson',
        data: this.factoryData
      })
      
      // 添加工厂点图层 - 使用红色（底层，最小）
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-radius': 4,
          'circle-color': '#FF4D4F', // 红色
          'circle-opacity': 0.95,
          'circle-stroke-width': 1,
          'circle-stroke-color': '#ffffff',
          'circle-stroke-opacity': 0.8
        },
        layout: {
          'visibility': this.currentMode === 'location' ? 'visible' : 'none'
        }
      })
      
      // 确认图层成功添加
      const layerExists = this.map.getLayer(layerId)
      const layerStyle = layerExists ? this.map.getPaintProperty(layerId, 'circle-color') : null
      console.log('[Factory] 工厂点图层添加完成:', {
        layerExists: !!layerExists,
        layerColor: layerStyle,
        visibility: this.map.getLayoutProperty(layerId, 'visibility')
      })
    },
    renderCompanyPoints() {
      if (!this.map || !this.companyData) {
        console.log('[Company Render] 跳过: map=', !!this.map, 'data=', !!this.companyData)
        return;
      }
      
      const sourceId = 'company-source'
      const layerId = 'company-points'
      
      console.log('[Company Render] 开始渲染:', {
        featureCount: this.companyData?.features?.length,
        firstFeature: this.companyData?.features?.[0]
      })
      
      // 删除旧的图层和源
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      
      // 添加企业点数据源
      this.map.addSource(sourceId, {
        type: 'geojson',
        data: this.companyData
      })
      
      // 添加企业点图层 - 使用黄色（中层，中等大小）
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-radius': 5,
          'circle-color': '#FADB14', // 黄色
          'circle-opacity': 0.95,
          'circle-stroke-width': 1.5,
          'circle-stroke-color': '#ffffff',
          'circle-stroke-opacity': 0.9
        },
        layout: {
          'visibility': this.currentMode === 'location' ? 'visible' : 'none'
        }
      })
      
      // 确认图层成功添加
      const layerExists = this.map.getLayer(layerId)
      const layerStyle = layerExists ? this.map.getPaintProperty(layerId, 'circle-color') : null
      console.log('[Company] 企业点图层添加完成:', {
        layerExists: !!layerExists,
        layerColor: layerStyle,
        visibility: this.map.getLayoutProperty(layerId, 'visibility')
      })
    },
    renderCarbonPoints() {
      if (!this.map || !this.carbonData) {
        console.log('[Carbon Render] 跳过: map=', !!this.map, 'data=', !!this.carbonData)
        return;
      }
      
      const sourceId = 'carbon-source'
      const layerId = 'carbon-points'
      
      console.log('[Carbon Render] 开始渲染:', {
        featureCount: this.carbonData?.features?.length,
        firstFeature: this.carbonData?.features?.[0]
      })
      
      // 删除旧的图层和源
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      
      // 添加采样点数据源
      this.map.addSource(sourceId, {
        type: 'geojson',
        data: this.carbonData
      })
      
      // 添加采样点图层 - 使用绿色（顶层，最大）
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-radius': 6,
          'circle-color': '#52C41A', // 绿色
          'circle-opacity': 0.95,
          'circle-stroke-width': 2,
          'circle-stroke-color': '#ffffff',
          'circle-stroke-opacity': 0.95
        },
        layout: {
          'visibility': this.currentMode === 'location' ? 'visible' : 'none'
        }
      })
      
      // 确认图层成功添加
      const layerExists = this.map.getLayer(layerId)
      const layerStyle = layerExists ? this.map.getPaintProperty(layerId, 'circle-color') : null
      console.log('[Carbon] 采样点图层添加完成:', {
        layerExists: !!layerExists,
        layerColor: layerStyle,
        visibility: this.map.getLayoutProperty(layerId, 'visibility')
      })
    },
    
    // 添加 Mapbox 底图图层（作为 raster 图层）
    addMapboxBaseLayer(type) {
      if (!this.map) return
      
      // 如果没有指定类型，使用当前类型
      const mapType = type || this.baseMapType
      
      const sourceId = 'mapbox-base-source'
      const layerId = 'mapbox-base-layer'
      
      // 如果已存在，先移除
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      
      console.log(`[Base Map] 添加 Mapbox 底图图层: ${mapType}`)
      
      // 根据类型选择不同的 Mapbox 源
      let sourceConfig
      if (mapType === 'satellite') {
        // 卫星图层
        sourceConfig = {
          type: 'raster',
          url: 'mapbox://mapbox.satellite',
          tileSize: 256
        }
      } else {
        // 街道图层 - 使用 Mapbox Dark 黑暗风格栅格瓦片
        sourceConfig = {
          type: 'raster',
          tiles: [
            'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=' + PUBLIC_KEY
          ],
          tileSize: 512
        }
      }
      
      this.map.addSource(sourceId, sourceConfig)
      
      this.map.addLayer({
        id: layerId,
        type: 'raster',
        source: sourceId,
        paint: {
          'raster-opacity': mapType === 'satellite' ? 1.0 : 0.8  // 卫星100%不透明，街道80%
        }
      }, 'gba-fill')  // 插入到边界填充图层之前（最底层）
      
      console.log('[Base Map] Mapbox 底图图层添加完成')
      
      // 确保建筑物图层在最顶层
      if (this.map.getLayer('buildings-layer')) {
        this.map.moveLayer('buildings-layer')
        console.log('[Base Map] 已将建筑物图层移至最顶层')
      }
    },
    
    // 切换底图类型
    toggleBaseMapType() {
      const newType = this.baseMapType === 'satellite' ? 'streets' : 'satellite'
      this.setBaseMapType(newType)
    },
    
    // 设置底图类型
    setBaseMapType(type) {
      if (this.baseMapType === type) return
      
      this.baseMapType = type
      console.log(`[Base Map] 切换底图类型到: ${type}`)
      
      // 重新添加底图图层
      if (this.is3DMode) {
        this.addMapboxBaseLayer(type)
      }
    },
    
    // 移除 Mapbox 底图图层
    removeMapboxBaseLayer() {
      if (!this.map) return
      
      const sourceId = 'mapbox-base-source'
      const layerId = 'mapbox-base-layer'
      
      console.log('[Base Map] 移除 Mapbox 底图图层')
      
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      
      console.log('[Base Map] Mapbox 底图图层已移除')
    },
    
    // 进入3D模式逻辑
    enter3DMode(cityFeature) {
      if (!this.buildingData || !this.buildingData.features) {
        console.warn('[Enter 3D] 无建筑物数据');
        return;
      }
      
      this.is3DMode = true;
      
      // 0. 添加 Mapbox 底图图层
      this.addMapboxBaseLayer();
      
      // 0.1 隐藏边界填充图层，避免遮挡卫星底图
      if (this.map.getLayer('gba-fill')) {
        this.map.setLayoutProperty('gba-fill', 'visibility', 'none');
      }
      
      // 1. 渲染建筑物（如果还没渲染）
      this.renderBuildings();
      
      // 2. 筛选该城市内的建筑物
      // 简单起见，我们先尝试找到该城市范围内的建筑物
      // 由于没有 turf，我们用简单的包围盒判断 + 射线法（如果需要更精确）
      // 或者，如果建筑物数据里有 city_id 字段最好，但目前看可能没有
      
      // 获取城市多边形
      const cityGeometry = cityFeature.geometry;
      
      // 筛选
      const buildingsInCity = this.buildingData.features.filter(b => {
        // 取建筑物第一个点作为代表点
        const coords = b.geometry?.coordinates?.[0]?.[0];
        if (!coords) return false;
        return this.isPointInPolygon(coords, cityGeometry);
      });
      
      console.log(`[Enter 3D] 城市内找到 ${buildingsInCity.length} 个建筑物`);
      
      let targetCenter;
      let targetZoom = 14.5; // 稍微拉远一级，从 15.5 改为 14.5
      
      if (buildingsInCity.length > 0) {
        // 计算这些建筑物的几何中心
        const geometricCenter = this.findCenterOfFeatures(buildingsInCity);
        
        // 找到距离几何中心最近的一个建筑物作为锚点
        // 这样避免 zoom 到空地
        const nearestBuilding = this.findNearestFeature(geometricCenter, buildingsInCity);
        
        if (nearestBuilding) {
          targetCenter = nearestBuilding.geometry?.coordinates?.[0]?.[0];
          console.log('[Enter 3D] Found nearest building at:', targetCenter);
        } else {
          targetCenter = geometricCenter;
        }
      } else {
        // 如果该城市没有建筑物数据，就飞向城市中心
        targetCenter = this.computeFeatureCentroid(cityFeature.geometry);
        targetZoom = 13;
      }
      
      if (targetCenter) {
        this.map.flyTo({
          center: targetCenter,
          zoom: targetZoom,
          pitch: 80, // 修改为 80 度 (接近完全倾斜)
          bearing: 30,
          duration: 2000,
          essential: true
        });
      }
    },
    
    // 渲染所有建筑物的标签 (Updated for dynamic visibility)
    renderBuildingMarkers() {
      console.log('[Markers] renderBuildingMarkers called')
      // 首次调用时，初始化可见标记
      this.updateVisibleMarkers()
      
      // 监听地图移动事件，动态更新
      if (!this._markerUpdateListener) {
        this._markerUpdateListener = () => {
          if (this.is3DMode && (this.currentMode === 'city' || this.currentMode === 'district')) {
            this.updateVisibleMarkers()
          }
        }
        this.map.on('moveend', this._markerUpdateListener)
      }
    },

    updateVisibleMarkers() {
      if (!this.buildingData || !this.buildingData.features || !this.is3DMode) return
      
      const center = this.map.getCenter()
      const centerPoint = [center.lng, center.lat]
      
      // 1. 计算所有建筑物到当前中心点的距离
      const buildingsWithDist = this.buildingData.features.map((f, index) => {
        const fCenter = this.getFeatureCenter(f)
        if (!fCenter) return null
        
        // 简单的欧氏距离平方
        const dx = fCenter[0] - centerPoint[0]
        const dy = fCenter[1] - centerPoint[1]
        const distSq = dx * dx + dy * dy
        
        return {
          feature: f,
          index: index, // 使用索引作为唯一ID
          center: fCenter,
          distSq: distSq
        }
      }).filter(item => item !== null)
      
      // 2. 排序并取最近的 N 个
      buildingsWithDist.sort((a, b) => a.distSq - b.distSq)
      const nearest = buildingsWithDist.slice(0, this.maxVisibleMarkers)
      const nearestIndices = new Set(nearest.map(item => item.index))
      
      // 3. 移除不再范围内的标记
      for (const [index, marker] of this.visibleMarkers.entries()) {
        if (!nearestIndices.has(index)) {
          marker.remove()
          this.visibleMarkers.delete(index)
        }
      }
      
      // 4. 添加新进入范围的标记
      nearest.forEach(item => {
        if (!this.visibleMarkers.has(item.index)) {
          const marker = this.createSingleBuildingMarker(item.feature)
          if (marker) {
            this.visibleMarkers.set(item.index, marker)
          }
        }
      })
    },
    
    getFeatureCenter(feature) {
      if (feature._calculatedCenter) return feature._calculatedCenter
      
      const geometry = feature.geometry
      const bounds = new mapboxgl.LngLatBounds()

      if (geometry.type === 'Polygon') {
        geometry.coordinates[0].forEach(coord => bounds.extend(coord))
      } else if (geometry.type === 'MultiPolygon') {
        geometry.coordinates.forEach(polygon => {
          polygon[0].forEach(coord => bounds.extend(coord))
        })
      } else {
        return null
      }
      
      const center = bounds.getCenter()
      feature._calculatedCenter = [center.lng, center.lat]
      return feature._calculatedCenter
    },

    createSingleBuildingMarker(feature) {
      const name = feature.properties.pt_name || feature.properties.name
      if (!name) return null

      const center = this.getFeatureCenter(feature)
      
      // 计算高度：与 fill-extrusion-height 保持一致
      // ['*', ['coalesce', ['get', 'height'], 20], heightMultiplier]
      const rawHeight = feature.properties.height || 20
      const heightMultiplier = 8
      const altitude = rawHeight * heightMultiplier

      // 创建 DOM 元素
      const el = document.createElement('div')
      el.className = 'building-label-marker'
      el.innerHTML = `
        <div class="label-card">
          <div class="label-content">
            <span class="label-text">${name}</span>
          </div>
        </div>
        <div class="label-line"></div>
        <div class="label-dot"></div>
      `
      
      // 添加点击事件
      el.addEventListener('click', (e) => {
        e.stopPropagation(); // 阻止地图点击事件
        console.log('[Marker Click] 点击建筑物标签:', name);
        this.handleBuildingClick(feature.properties);
      });

      // 创建 Marker
      const marker = new mapboxgl.Marker({
        element: el,
        anchor: 'bottom'
      })
        .setLngLat(center)
      
      // 设置海拔高度 (Mapbox GL JS v2/v3 支持)
      if (marker.setAltitude) {
        marker.setAltitude(altitude)
      }

      marker.addTo(this.map)
      
      return marker
    },

    // 清除所有建筑物标签
    clearBuildingMarkers() {
      this.visibleMarkers.forEach(marker => marker.remove())
      this.visibleMarkers.clear()
      if (this._markerUpdateListener) {
        this.map.off('moveend', this._markerUpdateListener)
        this._markerUpdateListener = null
      }
    },

    findNearestFeature(centerPoint, features) {
      if (!centerPoint || !features || features.length === 0) return null;
      
      let minDistance = Infinity;
      let nearest = null;
      
      features.forEach(f => {
        const coords = f.geometry?.coordinates?.[0]?.[0];
        if (coords) {
          // 简单的欧几里得距离平方（比较大小时不需要开方）
          const dx = coords[0] - centerPoint[0];
          const dy = coords[1] - centerPoint[1];
          const distSq = dx * dx + dy * dy;
          
          if (distSq < minDistance) {
            minDistance = distSq;
            nearest = f;
          }
        }
      });
      
      return nearest;
    },
    
    // 简单的点在多边形内判断 (Ray casting algorithm)
    isPointInPolygon(point, geometry) {
      const x = point[0], y = point[1];
      let inside = false;
      
      const checkRing = (ring) => {
        for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
          const xi = ring[i][0], yi = ring[i][1];
          const xj = ring[j][0], yj = ring[j][1];
          
          const intersect = ((yi > y) !== (yj > y)) &&
              (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
          if (intersect) inside = !inside;
        }
      };
      
      if (geometry.type === 'Polygon') {
        checkRing(geometry.coordinates[0]); // 只检查外环
      } else if (geometry.type === 'MultiPolygon') {
        for (const poly of geometry.coordinates) {
          checkRing(poly[0]);
          if (inside) break; // 只要在一个多边形内就算在
        }
      }
      
      return inside;
    },
    
    findCenterOfFeatures(features) {
      if (!features || features.length === 0) return null;
      let sumLng = 0, sumLat = 0, count = 0;
      
      features.forEach(f => {
        const coords = f.geometry?.coordinates?.[0]?.[0]; // 取第一个点
        if (coords) {
          sumLng += coords[0];
          sumLat += coords[1];
          count++;
        }
      });
      
      if (count === 0) return null;
      return [sumLng / count, sumLat / count];
    },
    toggleLayer(layerValue) {
      const index = this.activeLayers.indexOf(layerValue);
      if (index === -1) {
        this.activeLayers.push(layerValue);
        console.log(`[Layer Control] Layer activated: ${layerValue}`);
        
        // 激活图层时放大地图到初始层级+5（9级）
        if (this.map) {
          this.map.flyTo({
            zoom: 9.5,
            duration: 1500
          });
        }
        
        // 显示卫星底图
        this.addMapboxBaseLayer('satellite');
        
        // 隐藏边界填充图层，避免遮挡卫星底图
        if (this.map.getLayer('gba-fill')) {
          this.map.setLayoutProperty('gba-fill', 'visibility', 'none');
        }
        
        // 如果数据未加载，先加载数据
        if (layerValue === 'carbon' && !this.carbonLayerData) {
          this.fetchLayerData('carbon');
        } else if (layerValue === 'temperature' && !this.tempLayerData) {
          this.fetchLayerData('temperature');
        } else {
          // 数据已存在，直接显示
          this.setLayerVisibility(layerValue, true);
        }
      } else {
        this.activeLayers.splice(index, 1);
        console.log(`[Layer Control] Layer deactivated: ${layerValue}`);
        this.setLayerVisibility(layerValue, false);
        
        // 如果碳排放和温度图层都未激活，移除卫星底图
        if (!this.activeLayers.includes('carbon') && !this.activeLayers.includes('temperature')) {
          this.removeMapboxBaseLayer();
          
          // 恢复边界填充图层的显示
          if (this.map.getLayer('gba-fill')) {
            this.map.setLayoutProperty('gba-fill', 'visibility', 'visible');
          }
        }
      }
    },
    fetchLayerData(type) {
      let url = '';
      let params = {};
      
      if (type === 'carbon') {
        url = 'map/natural-heatpoints';
        params = { type: 'carbonEmission' }; // 不指定year，使用最新年份
      } else if (type === 'temperature') {
        url = 'map/natural-heatpoints';
        params = { type: 'LST' }; // 不指定year，使用最新年份
      }
      
      if (!url) return;
      
      console.log(`[Layer Data] Fetching ${type} heatpoints from ${url} with params:`, params);
      http.get(url, { params })
        .then(res => {
          console.log(`[Layer Data] ${type} heatpoints loaded:`, res.data?.features?.length);
          if (type === 'carbon') {
            this.carbonLayerData = res.data;
          } else {
            this.tempLayerData = res.data;
          }
          this.renderLayer(type);
        })
        .catch(err => {
          console.error(`[Layer Data] Failed to load ${type} heatpoints:`, err);
        });
    },
    setLayerVisibility(type, visible) {
      if (!this.map) return;
      const layerId = `${type}-fill`;
      if (this.map.getLayer(layerId)) {
        this.map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
      }
    },
    renderLayer(type) {
      if (!this.map) return;
      
      const rawData = type === 'carbon' ? this.carbonLayerData : this.tempLayerData;
      if (!rawData || !rawData.features || rawData.features.length === 0) return;
      
      // 0. 数据清洗与验证
      // "varint doesn't fit into 10 bytes" 通常是由于坐标精度过高导致的
      // 需要将坐标四舍五入到合理精度（4位小数约为10米精度）
      const roundCoord = (coord) => {
        if (Array.isArray(coord)) {
          // 如果是坐标点 [lng, lat]
          if (coord.length === 2 && typeof coord[0] === 'number' && typeof coord[1] === 'number') {
            return [
              Math.round(coord[0] * 10000) / 10000,  // 保留4位小数
              Math.round(coord[1] * 10000) / 10000
            ];
          }
          // 如果是数组容器，继续递归
          return coord.map(roundCoord);
        }
        return coord;
      };

      const validFeatures = rawData.features.map((f, index) => {
        if (!f.geometry || !f.geometry.coordinates) return null;
        
        // 检查并四舍五入坐标
        try {
          const roundedCoords = roundCoord(f.geometry.coordinates);
          
          // 验证四舍五入后的坐标是否有效
          const isValid = (coord) => {
            if (Array.isArray(coord)) {
              if (coord.length === 2 && typeof coord[0] === 'number' && typeof coord[1] === 'number') {
                return !isNaN(coord[0]) && !isNaN(coord[1]) && 
                       Math.abs(coord[0]) <= 180 && Math.abs(coord[1]) <= 90;
              }
              return coord.every(isValid);
            }
            return false;
          };

          if (!isValid(roundedCoords)) {
            if (index < 3) console.warn(`[Layer Validation] Invalid coords at index ${index}`);
            return null;
          }

          return {
            ...f,
            geometry: {
              ...f.geometry,
              coordinates: roundedCoords
            }
          };
        } catch (e) {
          if (index < 3) console.warn(`[Layer Validation] Error processing feature ${index}:`, e);
          return null;
        }
      }).filter(f => f !== null);

      console.log(`[Layer Render] Valid features: ${validFeatures.length} / ${rawData.features.length}`);

      if (validFeatures.length === 0) {
        console.warn('[Layer Render] No valid features to render');
        return;
      }

      // 构造清洗后的 GeoJSON
      const data = {
        type: 'FeatureCollection',
        features: validFeatures
      };
      
      const sourceId = `${type}-source`;
      const layerId = `${type}-fill`;
      
      // 1. 找到数值字段
      const firstProps = data.features[0].properties;
      
      let valueField = 'value'; // 新接口返回的字段名
      
      console.log(`[Layer Render] Using field '${valueField}' for ${type}`);
      console.log(`[Layer Render] Sample properties:`, firstProps);
      
      // 计算 min/max 用于权重映射
      let min = Infinity, max = -Infinity;
      let validCount = 0;
      data.features.forEach(f => {
        const v = f.properties[valueField];
        if (typeof v === 'number' && !isNaN(v) && isFinite(v)) {
          if (v < min) min = v;
          if (v > max) max = v;
          validCount++;
        }
      });
      
      console.log(`[Layer Render] Valid values: ${validCount} / ${data.features.length}`);
      console.log(`[Layer Render] ${type} value range: [${min}, ${max}]`);
      
      if (validCount === 0) {
        console.warn('[Layer Render] No valid property values found');
        return;
      }
      
      // 避免 min === max
      if (min === max) {
        min = min - 1;
        max = max + 1;
      }
      
      // API 已经返回点数据，直接使用
      console.log(`[Layer Render] Using ${data.features.length} heatpoints directly from API`);
      
      // 为每个点添加 value 属性用于热力图权重
      data.features.forEach(f => {
        if (!f.properties.value && f.properties[valueField]) {
          f.properties.value = f.properties[valueField];
        }
      });
      
      // 2. 添加 Source
      if (this.map.getSource(sourceId)) {
         this.map.getSource(sourceId).setData(data);
      } else {
        this.map.addSource(sourceId, {
          type: 'geojson',
          data: data
        });
      }
      
      // 3. 添加 Heatmap Layer (强制重新创建)
      if (this.map.getLayer(layerId)) {
        console.log(`[Layer Render] Removing existing layer: ${layerId}`);
        this.map.removeLayer(layerId);
      }
      
      console.log(`[Layer Render] Adding heatmap layer: ${layerId}`);
      
      // 定义热力图颜色
      let heatmapColor;
      if (type === 'carbon') {
        // 碳排放: 绿 -> 黄 -> 橙 -> 红
        heatmapColor = [
          'interpolate',
          ['linear'],
          ['heatmap-density'],
          0, 'rgba(0, 255, 0, 0)',      // 透明
          0.2, 'rgb(0, 255, 0)',        // 绿色
          0.4, 'rgb(127, 255, 0)',      // 浅绿
          0.6, 'rgb(255, 255, 0)',      // 黄色
          0.8, 'rgb(255, 140, 0)',      // 橙色
          1, 'rgb(255, 0, 0)'           // 红色
        ];
      } else {
        // 温度: 蓝 -> 青 -> 黄 -> 橙 -> 红
        heatmapColor = [
          'interpolate',
          ['linear'],
          ['heatmap-density'],
          0, 'rgba(0, 0, 255, 0)',
          0.2, 'rgb(0, 0, 255)',
          0.4, 'rgb(0, 255, 255)',
          0.6, 'rgb(255, 255, 0)',
          0.8, 'rgb(255, 140, 0)',
          1, 'rgb(255, 0, 0)'
        ];
      }
      
      this.map.addLayer({
        id: layerId,
        type: 'heatmap',
        source: sourceId,
        paint: {
          // 热力图权重基于碳排放值（形成"山峰"效果）
          'heatmap-weight': [
            'interpolate',
            ['linear'],
            ['get', 'value'],
            min, 0,    // 最低值权重为0
            max, 1     // 最高值权重为1
          ],
          // 热力图强度（提高以显示明显的峰值）
          'heatmap-intensity': [
            'interpolate',
            ['linear'],
            ['zoom'],
            0, 1,
            9, 3
          ],
          // 热力图颜色
          'heatmap-color': heatmapColor,
          // 热力图半径（适中）
          'heatmap-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            0, 5,     // 缩小时半径5像素
            5, 12,    // 中等缩放12像素
            9, 20     // 放大时半径20像素
          ],
          // 热力图透明度
          'heatmap-opacity': 0.8
        }
      });
      
      console.log(`[Layer Render] Heatmap layer added successfully`);
      
      // 验证图层是否成功添加
      const layer = this.map.getLayer(layerId);
      const source = this.map.getSource(sourceId);
      console.log(`[Layer Render] Verification - Layer exists: ${!!layer}, Source exists: ${!!source}`);
      if (layer) {
        console.log(`[Layer Render] Layer visibility:`, this.map.getLayoutProperty(layerId, 'visibility'));
        console.log(`[Layer Render] Layer paint:`, this.map.getPaintProperty(layerId, 'fill-color'));
      }
    }
  }
}
</script>

<style>
@import 'mapbox-gl/dist/mapbox-gl.css';

.new-map-display {
  width: 100%;
  height: 100%;
  position: relative;
}

#mb-map {
  width: 100%;
  height: 100%;
  cursor: default;
}

#mb-map .mapboxgl-canvas-container.mapboxgl-interactive {
  cursor: default;
}

#mb-map .mapboxgl-canvas-container.mapboxgl-interactive:active {
  cursor: default;
}

/* Hover Tooltip Styling */
.map-hover-tooltip {
  position: fixed;
  padding: 8px 16px;
  background: rgba(4, 16, 30, 0.95);
  border: 1px solid rgba(0, 242, 255, 0.6);
  border-radius: 6px;
  color: #00f2ff;
  font-size: 14px;
  font-weight: 600;
  white-space: nowrap;
  pointer-events: none;
  z-index: 10000;
  box-shadow: 0 4px 12px rgba(0, 242, 255, 0.3),
              inset 0 0 10px rgba(0, 242, 255, 0.1);
  text-shadow: 0 0 5px rgba(0, 242, 255, 0.5);
  letter-spacing: 0.5px;
  animation: tooltip-fade-in 0.2s ease-out;
}

@keyframes tooltip-fade-in {
  from {
    opacity: 0;
    transform: translateY(-5px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 数据切换面板 */
.mode-switch-panel {
  position: absolute;
  bottom: 20px;
  right: 20px;
  /* transform: translateX(-50%); */
  z-index: 1000;
  /* 改为不透明背景，避免地图透出 */
  background: rgba(2, 6, 15, 0.98);
  padding: 0;
  transition: bottom 0.3s ease;
}

/* .mode-switch-panel.chat-open {
  bottom: 55%; 
} */

@keyframes glow-pulse {

  0%,
  100% {
    opacity: 0.4;
  }

  50% {
    opacity: 0.7;
  }
}

.mode-buttons {
  position: relative;
  display: flex;
  gap: 0;
  border-radius: 12px;
  overflow: hidden;
  /* 全不透明面板背景 */
  background: rgba(0, 30, 60, 1);
  border: 1px solid rgba(102, 221, 255, 0.2);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5), inset 0 0 24px rgba(0, 200, 255, 0.08);
}

.panel-glow {
  position: absolute;
  inset: -2px;
  border-radius: 12px;
  background: linear-gradient(135deg, rgba(0, 255, 214, 0.4), rgba(0, 117, 255, 0.4), rgba(177, 0, 255, 0.4));
  filter: blur(8px);
  opacity: 0.5;
  z-index: -1;
  animation: glow-pulse 3s ease-in-out infinite;
}

.panel-border {
  position: absolute;
  inset: 0;
  border-radius: 12px;
  padding: 1px;
  background: linear-gradient(135deg, rgba(0, 255, 214, 0.5), rgba(0, 117, 255, 0.5), rgba(177, 0, 255, 0.5));
  -webkit-mask:
    linear-gradient(#000 0 0) content-box,
    linear-gradient(#000 0 0);
  mask:
    linear-gradient(#000 0 0) content-box,
    linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
  z-index: 0;
}

.mode-btn {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 10px 24px;
  background: transparent;
  border: none;
  border-radius: 0;
  /*color: rgba(154, 215, 255, 0.8);*/
  color: #ffffff;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.3s ease;
  overflow: hidden;
  white-space: nowrap;
}

/* 第一个按钮：左侧圆角 */
.mode-btn:first-child {
  border-top-left-radius: 12px;
  border-bottom-left-radius: 12px;
}

/* 最后一个按钮：右侧圆角 */
.mode-btn:last-child {
  border-top-right-radius: 12px;
  border-bottom-right-radius: 12px;
}

/* 分隔线（除了最后一个按钮） */
.mode-btn:not(:last-child)::after {
  content: '';
  position: absolute;
  right: 0;
  top: 20%;
  bottom: 20%;
  width: 1px;
  background: rgba(102, 221, 255, 0.3);
}

/* 激活状态的分隔线隐藏 */
.mode-btn.active::after,
.mode-btn.active+.mode-btn::after {
  opacity: 0;
}

.mode-btn::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(0, 255, 214, 0.1), rgba(0, 117, 255, 0.1));
  opacity: 0;
  transition: opacity 0.3s ease;
}

.mode-btn:hover {
  background: rgba(0, 60, 100, 0.4);
  color: rgba(154, 215, 255, 1);
}

.mode-btn:hover::before {
  opacity: 1;
}

.mode-btn.active {
  background: linear-gradient(135deg, rgba(0, 255, 214, 0.2), rgba(0, 117, 255, 0.2));
  color: #66ddff;
  box-shadow: inset 0 0 20px rgba(0, 200, 255, 0.15);
}

.mode-btn.active::before {
  opacity: 1;
}

.mode-text {
  font-weight: 500;
  letter-spacing: 0.05em;
}

.mode-indicator {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(90deg, transparent, #66ddff, transparent);
  opacity: 0;
  transform: scaleX(0);
  transition: all 0.3s ease;
}

.mode-btn.active .mode-indicator {
  opacity: 1;
  transform: scaleX(1);
}

/* 简洁图例，匹配地图风格，放在左下角，仅在地点模式可见 */
.map-legend {
  position: absolute;
  left: 0px;
  bottom: 0px;
  z-index: 1000;
  background: rgba(2, 6, 15);
  border: 1px solid rgba(102, 221, 255, 0.06);
  padding: 8px 10px;
  border-radius: 8px;
  box-shadow: 0 6px 20px rgba(0,0,0,0.5), inset 0 0 18px rgba(0,150,255,0.03);
  color: #e6f7ff;
  font-size: 13px;
  user-select: none;
}
.map-legend ul {
  display: flex;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
  align-items: center;
}
.map-legend li {
  display: flex;
  align-items: center;
  gap: 8px;
}
.legend-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  display: inline-block;
  box-shadow: 0 2px 8px rgba(0,0,0,0.4);
  border: 1px solid rgba(255,255,255,0.9);
}
.dot-factory { background: #FF4D4F; box-shadow: 0 2px 10px rgba(255,77,79,0.25); }
.dot-company { background: #FADB14; box-shadow: 0 2px 10px rgba(250,219,20,0.18); }
.dot-sampling { background: #52C41A; box-shadow: 0 2px 10px rgba(82,196,26,0.18); }
.legend-label { color: #cfeeff; font-weight: 500; font-size: 13px;}
.map-legend.hidden { display: none; }

/* Building Label Marker Styles - Tech/Sci-fi Theme */
.building-label-marker {
  display: flex;
  flex-direction: column;
  align-items: center;
  pointer-events: none;
  /* 确保标记底部对齐到锚点位置 */
  transform-origin: bottom center;
  z-index: 10; /* Ensure it's above other map elements */
}

.label-card {
  /* 科技感背景：深色半透明 + 模糊 */
  background: rgba(4, 16, 30, 0.85);
  border: 1px solid rgba(0, 242, 255, 0.5);
  /* 切角效果 */
  clip-path: polygon(
    10px 0, 100% 0, 
    100% calc(100% - 10px), calc(100% - 10px) 100%, 
    0 100%, 0 10px
  );
  padding: 8px 16px;
  /* 霓虹发光效果 */
  box-shadow: 
    0 0 15px rgba(0, 242, 255, 0.2),
    inset 0 0 20px rgba(0, 242, 255, 0.1);
  backdrop-filter: blur(4px);
  margin-bottom: 0;
  position: relative;
  animation: floatCard 3s ease-in-out infinite;
}

/* 卡片角落装饰 */
.label-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 8px;
  height: 8px;
  border-top: 2px solid #00f2ff;
  border-left: 2px solid #00f2ff;
}

.label-card::after {
  content: '';
  position: absolute;
  bottom: 0;
  right: 0;
  width: 8px;
  height: 8px;
  border-bottom: 2px solid #00f2ff;
  border-right: 2px solid #00f2ff;
}

.label-content {
  display: flex;
  align-items: center;
  gap: 8px;
}



.label-text {
  color: #e6f7ff;
  font-family: 'Rajdhani', 'DIN Pro', sans-serif; /* 假设有科技感字体，回退到 sans-serif */
  font-size: 14px;
  font-weight: 600;
  white-space: nowrap;
  letter-spacing: 1px;
  text-transform: uppercase;
  text-shadow: 0 0 5px rgba(0, 242, 255, 0.6);
}

.label-line {
  width: 2px;
  height: 80px; /* 增加高度，让卡片悬浮更高 */
  /* 能量光束渐变 */
  background: linear-gradient(to bottom, 
    rgba(0, 242, 255, 1) 0%, 
    rgba(0, 242, 255, 0.5) 50%, 
    rgba(0, 242, 255, 0) 100%
  );
  box-shadow: 0 0 8px rgba(0, 242, 255, 0.6);
  margin-top: -1px;
  position: relative;
  overflow: hidden;
}

.panel-glow {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(circle at center, rgba(0, 200, 255, 0.15), transparent 70%);
  animation: glow-pulse 3s infinite ease-in-out;
  pointer-events: none;
}

/* 图层控制面板样式 */
.layer-control-panel {
  position: absolute;
  bottom: 5px;
  left: 5px;
  z-index: 1000;
}

.layer-buttons {
  display: flex;
  flex-direction: row;
  gap: 10px;
}

.layer-btn {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 24px;
  background: rgba(2, 6, 23, 0.85);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 8px;
  color: #94a3b8;
  font-family: 'Inter', sans-serif;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  backdrop-filter: blur(8px);
  overflow: hidden;
  text-align: left;
  min-width: auto;
}

.layer-btn:hover {
  background: rgba(30, 41, 59, 0.9);
  border-color: rgba(56, 189, 248, 0.4);
  color: #e2e8f0;
  transform: translateX(2px);
}

.layer-btn.active {
  background: rgba(15, 23, 42, 0.95);
  border-color: #38bdf8;
  color: #38bdf8;
  box-shadow: 0 0 15px rgba(56, 189, 248, 0.15);
}

.layer-indicator {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  background: #38bdf8;
  opacity: 0;
  transition: opacity 0.3s ease;
}

.layer-btn.active .layer-indicator {
  opacity: 1;
}

.layer-icon {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: #64748b;
  transition: background-color 0.3s ease;
}

.layer-btn.active .layer-icon {
  background-color: #38bdf8;
  box-shadow: 0 0 8px rgba(56, 189, 248, 0.6);
}

/* 针对特定图层的激活颜色 */
.layer-btn.active:nth-child(1) .layer-icon { /* 碳排放 */
  background-color: #52c41a;
  box-shadow: 0 0 8px rgba(82, 196, 26, 0.6);
}
.layer-btn.active:nth-child(1) {
  border-color: #52c41a;
  color: #52c41a;
}
.layer-btn.active:nth-child(1) .layer-indicator {
  background: #52c41a;
}

.layer-btn.active:nth-child(2) .layer-icon { /* 温度 */
  background-color: #ff4d4f;
  box-shadow: 0 0 8px rgba(255, 77, 79, 0.6);
}
.layer-btn.active:nth-child(2) {
  border-color: #ff4d4f;
  color: #ff4d4f;
}
.layer-btn.active:nth-child(2) .layer-indicator {
  background: #ff4d4f;
}


/* 光束流动动画效果 */
.label-line::after {
  content: '';
  position: absolute;
  top: -100%;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(to bottom, transparent, rgba(255, 255, 255, 0.8), transparent);
  animation: beamFlow 2s linear infinite;
}

.label-dot {
  width: 8px;
  height: 8px;
  background: #00f2ff;
  border-radius: 50%;
  box-shadow: 0 0 10px #00f2ff, 0 0 20px #00f2ff;
  margin-top: -4px;
  position: relative;
  z-index: 1;
}

/* 锚点波纹动画 */
.label-dot::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 100%;
  height: 100%;
  border: 1px solid #00f2ff;
  border-radius: 50%;
  animation: ripple 2s linear infinite;
}

@keyframes floatCard {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-5px); }
}

@keyframes beamFlow {
  0% { top: -100%; }
  100% { top: 100%; }
}

@keyframes ripple {
  0% { width: 100%; height: 100%; opacity: 1; }
  100% { width: 300%; height: 300%; opacity: 0; }
}

/* 底图切换分段控制器样式 */
.basemap-toggle-panel {
  position: absolute;
  top: 20px;
  right: 20px;
  z-index: 10;
}

.basemap-segmented-control {
  display: flex;
  position: relative;
  background: rgba(2, 6, 23, 0.6);
  backdrop-filter: blur(12px);
  padding: 4px;
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.segment-option {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  cursor: pointer;
  color: #94a3b8;
  font-size: 14px;
  font-weight: 500;
  transition: color 0.3s ease;
  user-select: none;
}

.segment-option:hover {
  color: #e2e8f0;
}

.segment-option.active {
  color: #fff;
  text-shadow: 0 0 8px rgba(255, 255, 255, 0.5);
}

.segment-icon {
  font-size: 16px;
}

/* 滑动指示器 */
.segment-glider {
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: 4px;
  width: calc(50% - 4px);
  background: rgba(56, 189, 248, 0.2);
  border: 1px solid rgba(56, 189, 248, 0.5);
  border-radius: 8px;
  z-index: 1;
  transition: transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
  box-shadow: 0 0 12px rgba(56, 189, 248, 0.3);
}

/* 根据状态移动滑块 */
.segment-glider.streets {
  transform: translateX(100%);
}

.segment-glider.satellite {
  transform: translateX(0);
}
</style>

