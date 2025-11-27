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
  </div>
</template>

<script>
import mapboxgl from 'mapbox-gl'
import { http } from '@/api/api'
import bus from '@/bus'
import FactoryInfoCard from './FactoryInfoCard.vue'
import CarbonEmissionCard from './CarbonEmissionCard.vue'
import CompanyInfoCard from './CompanyInfoCard.vue'

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

      blankStyle: null,
      currentMode: 'city', // 当前选中的模式
      currentScale: 'City',
      modes: [
        { value: 'city', label: '市级', scale: 'City' },
        { value: 'district', label: '区级', scale: 'District' },
        { value: 'location', label: '地点', scale: 'Location' }
      ]
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
  mounted() {
    // 空白样式
    const blankStyle = {
      version: 8,
      name: 'blank',
      glyphs: "mapbox://fonts/mapbox/{fontstack}/{range}.pbf", // 需要有效 token
      sources: {},

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

    // 始终加载城市边界作为底图
    this.fetchBoundaryByScale('City')
    // 加载所有点位数据
    this.fetchMapData()
  },
  beforeDestroy() {
    if (this.map) this.map.remove()
  },
  methods: {
    initMap() {
      const accessToken = "pk.eyJ1IjoiemhvdWdpcyIsImEiOiJjbWhpc2EyMHcwd3F4MmtwbjNhejV4MmIyIn0.Lu4eDBF_hFOON7q6FuEenQ"
      mapboxgl.accessToken = accessToken
      const map = new mapboxgl.Map({
        container: this.$refs.mapContainer,
        // style: 'mapbox://styles/mapbox/dark-v11',
        style: this.blankStyle,
        center: [113.45, 23.17],
        zoom: 10
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
      })
      this.$nextTick(() => setTimeout(() => map.resize(), 0))
      this.map = map
    },
    fetchBoundaryByScale(scale) {
      http.get('map/gba_boundary', { params: { scale } })
        .then(res => {
          this.boundary = res.data
          this.labelFeatures = this.buildLabelPoints(res.data, scale)
          this.updateOverviewCounts(res.data)
          if (this.mapLoaded) {
            // 确保点位在边界之前渲染
            if (this.allPointsData && !this.map.getLayer('all-points')) {
              this.renderAllPoints()
            }
            this.renderBoundary()
          }
        })
        .catch(err => {
          console.error('加载边界数据失败:', err)
          this.labelFeatures = null
        })
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
      const sourceId = 'gba-boundary'
      const labelSourceId = 'gba-label-source'
      const removeIfExists = id => {
        if (this.map.getLayer(id)) this.map.removeLayer(id)
      }

      // 先删除所有使用该 source 的图层
      removeIfExists('gba-label')
      removeIfExists('gba-fill')
      removeIfExists('gba-line')
      
      // 再删除 source
        if (this.map.getSource(sourceId)) {
          this.map.removeSource(sourceId)
        }
      if (this.map.getSource(labelSourceId)) {
        this.map.removeSource(labelSourceId)
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
      this.map.addSource(labelSourceId, {
        type: 'geojson',
        data: this.labelFeatures || { type: 'FeatureCollection', features: [] }
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
      // 城市名称标注（基于属性：名称_nam）
        this.map.addLayer({
        id: 'gba-label',
        type: 'symbol',
        source: labelSourceId,
        filter: ['any',
          ['==', ['geometry-type'], 'Polygon'],
          ['==', ['geometry-type'], 'MultiPolygon']
        ],
        layout: {
          // 取我们预先生成的统一标签字段：labelName
          'text-field': ['coalesce', ['get', 'labelName'], ''],
          'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular'], // 该样式内可用字体
          'text-size': 14,
          'symbol-placement': 'point',   // 多边形内放置一个点标注
          'text-allow-overlap': false,
          'text-variable-anchor': ['center', 'top', 'bottom', 'left', 'right'],
          'text-offset': [0, 0]
        },
          paint: {
          'text-color': '#E2E8F0',
          'text-halo-color': 'rgba(2, 6, 23, 0.9)',
          'text-halo-width': 1.2
          }
      });
      const bbox = this.computeGeoJSONBounds(this.boundary)
      console.log('fitBounds bbox:', bbox)
      if (bbox) this.map.fitBounds(bbox, { padding: 40, duration: 0 })
      
      // 确保点图层始终在最顶层
      if (this.map.getLayer('all-points')) {
        this.map.moveLayer('all-points')
        console.log('[Layer Order] 点图层已移至顶层')
      }
      
      // 绑定点击事件
      this.bindIdentify()
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
      
      // 地点模式：同时显示企业、工厂和碳排放点
      if (mode === 'location') {
        // 确保城市边界显示
        if (!this.boundary) {
          this.fetchBoundaryByScale('City')
        }
        
        // 显示所有点位
        if (this.map.getLayer('all-points')) {
          this.map.setLayoutProperty('all-points', 'visibility', 'visible')
        } else if (this.allPointsData) {
          this.renderAllPoints()
        }
      } else {
        // 其他模式：隐藏所有点位，更新边界
        if (this.map.getLayer('all-points')) {
          this.map.setLayoutProperty('all-points', 'visibility', 'none')
        }
        this.fetchBoundaryByScale(scale)
        
        // 关闭所有卡片
        this.$refs.companyCard && this.$refs.companyCard.close && this.$refs.companyCard.close()
        this.$refs.factoryCard && this.$refs.factoryCard.close && this.$refs.factoryCard.close()
        this.$refs.carbonCard && this.$refs.carbonCard.close && this.$refs.carbonCard.close()
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
              const screenPos = this.getScreenPosition(px)
              this.$refs.carbonCard && this.$refs.carbonCard.show && this.$refs.carbonCard.show(f.properties, screenPos.x, screenPos.y)
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
            this.emitRegionFilter(null);
          }
        }
      };

      // 在定义回调后注册一次
      this.map.on('click', this._onMapClick);
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
      if (!geojson) {
        return { type: 'FeatureCollection', features: [] }
      }
      const features = geojson.type === 'FeatureCollection' ? geojson.features : [geojson]
      const labelField = this.getLabelFieldByScale(scale)
      const grouped = new Map()

      features.forEach(feature => {
        if (!feature || !feature.properties) return
        const geom = feature.geometry
        if (!geom || (geom.type !== 'Polygon' && geom.type !== 'MultiPolygon')) return
        const labelValue = feature.properties[labelField]
        if (!labelValue) return
        const area = this.computeFeatureArea(geom)
        const existing = grouped.get(labelValue)
        if (!existing || area > existing.area) {
          grouped.set(labelValue, { feature, area })
        }
      })

      const labelFeatures = []
      grouped.forEach(({ feature }) => {
        const centroid = this.computeFeatureCentroid(feature.geometry)
        if (!centroid) return
        labelFeatures.push({
          type: 'Feature',
          properties: {
            labelName: feature.properties[this.getLabelFieldByScale(scale)]
          },
          geometry: {
            type: 'Point',
            coordinates: centroid
          }
        })
      })
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
</style>
