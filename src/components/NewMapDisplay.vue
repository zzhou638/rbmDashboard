<template>
  <div class="new-map-display">
    <div id="mb-map" ref="mapContainer"></div>
    
    <!-- 工厂信息卡片 -->
    <FactoryInfoCard ref="factoryCard" />
    <CompanyInfoCard ref="companyCard" />
    <CarbonEmissionCard ref="carbonCard" />
    
    <!-- 数据切换面板 -->
    <div class="mode-switch-panel">
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
  data() {
    return {
      map: null,
      mapLoaded: false, // 标记地图样式是否加载完成
      boundary: null,
      labelFeatures: null,
      factoryData: null, // 工厂点数据
      companyData: null, // 企业点数据
      carbonPointLayerId: 'carbon-point',
      blankStyle: null,
      currentMode: 'city', // 当前选中的模式
      currentScale: 'City',
      modes: [
        { value: 'city', label: '市级', scale: 'City' },
        { value: 'district', label: '区级', scale: 'District' },
        { value: 'enterprise', label: '企业', scale: 'Companies' },
        { value: 'factory', label: '工厂', scale: 'Factory' },
        { value: 'carbon', label: '碳排放', scale: 'Carbon' }
      ]
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
    // 同时加载工厂点数据
    this.fetchFactoryData()
    // 加载企业点数据
    this.fetchCompanyData()
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
        // 先渲染企业点和工厂点（在底层）
        if (this.companyData) {
          this.renderCompanyPoints()
        }
        if (this.factoryData) {
          this.renderFactoryPoints()
        }
        // 再渲染边界面（在上层）
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
            // 确保企业点和工厂点在边界之前渲染
            if (this.companyData && !this.map.getLayer('company-points')) {
              this.renderCompanyPoints()
            }
            if (this.factoryData && !this.map.getLayer('factory-points')) {
              this.renderFactoryPoints()
            }
            this.renderBoundary()
          }
        })
        .catch(err => {
          console.error('加载边界数据失败:', err)
          this.labelFeatures = null
        })
    },
    fetchFactoryData() {
      http.get('map/gba_boundary', { params: { scale: 'Factory' } })
        .then(res => {
          this.factoryData = res.data
          if (this.mapLoaded) {
            this.renderFactoryPoints()
          }
        })
        .catch(err => {
          console.error('加载工厂数据失败:', err)
        })
    },
    fetchCompanyData() {
      http.get('companies/geojson')
        .then(res => {
          this.companyData = res.data
          console.log('[Company] 企业数据加载成功:', this.companyData)
          if (this.mapLoaded) {
            this.renderCompanyPoints()
          }
        })
        .catch(err => {
          console.error('加载企业数据失败:', err)
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
      
      // 企业模式特殊处理：只控制企业点的显示/隐藏
      if (mode === 'enterprise') {
        // 确保城市边界显示
        if (!this.boundary) {
          this.fetchBoundaryByScale('City')
        }
        // 隐藏工厂点
        if (this.map.getLayer('factory-points')) {
          this.map.setLayoutProperty('factory-points', 'visibility', 'none')
        }
        // 显示企业点
        if (this.map.getLayer('company-points')) {
          this.map.setLayoutProperty('company-points', 'visibility', 'visible')
          // 确保企业点位图层位于最顶层，避免被区/面图层覆盖
          try { if (this.map.getLayer('company-points')) this.map.moveLayer('company-points') } catch (e) { console.warn('moveLayer company-points failed', e) }
        } else if (this.companyData) {
          this.renderCompanyPoints()
        } else {
          this.fetchCompanyData()
        }
        // 切换到企业模式时，移除碳点并关闭碳卡，避免残留
        this.removeCarbonPoint()
        this.$refs.carbonCard && this.$refs.carbonCard.close && this.$refs.carbonCard.close()
      }
      // 工厂模式特殊处理：只控制工厂点的显示/隐藏
      else if (mode === 'factory') {
        // 确保城市边界显示
        if (!this.boundary) {
          this.fetchBoundaryByScale('City')
        }
        // 隐藏企业点
        if (this.map.getLayer('company-points')) {
          this.map.setLayoutProperty('company-points', 'visibility', 'none')
        }
        // 显示工厂点
        if (this.map.getLayer('factory-points')) {
          this.map.setLayoutProperty('factory-points', 'visibility', 'visible')
          // 确保工厂点位图层位于最顶层，避免被区/面图层覆盖
          try { if (this.map.getLayer('factory-points')) this.map.moveLayer('factory-points') } catch (e) { console.warn('moveLayer factory-points failed', e) }
        } else if (this.factoryData) {
          this.renderFactoryPoints()
        } else {
          this.fetchFactoryData()
        }
        // 切换到工厂模式时，移除碳点并关闭碳卡，避免残留
        this.removeCarbonPoint()
        this.$refs.carbonCard && this.$refs.carbonCard.close && this.$refs.carbonCard.close()
      } else if (mode === 'carbon') {
        // 切换到碳排放：先隐藏企业/工厂点并关闭它们的卡片，避免与碳点叠加
        if (this.map.getLayer('company-points')) {
          this.map.setLayoutProperty('company-points', 'visibility', 'none')
        }
        if (this.map.getLayer('factory-points')) {
          this.map.setLayoutProperty('factory-points', 'visibility', 'none')
        }
        this.$refs.companyCard && this.$refs.companyCard.close && this.$refs.companyCard.close()
        this.$refs.factoryCard && this.$refs.factoryCard.close && this.$refs.factoryCard.close()
        this.showCarbonPoint()
        return
      } else {
        // 其他模式：隐藏工厂点和企业点，更新边界
        if (this.map.getLayer('factory-points')) {
          this.map.setLayoutProperty('factory-points', 'visibility', 'none')
        }
        if (this.map.getLayer('company-points')) {
          this.map.setLayoutProperty('company-points', 'visibility', 'none')
        }
        this.fetchBoundaryByScale(scale)
        this.removeCarbonPoint()
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
        if (this.currentMode === 'carbon') {
          features = this.map.queryRenderedFeatures(bbox, { layers: [this.carbonPointLayerId] })
          if (features && features.length) {
            console.log('[Map Identify - Carbon] 命中碳排放点')
            const screenPos = this.getScreenPosition(px)
            this.$refs.carbonCard && this.$refs.carbonCard.show(screenPos)
          } else {
            console.log('[Map Identify - Carbon] 未命中碳排放点')
            this.$refs.carbonCard && this.$refs.carbonCard.close()
          }
          return
        }

        if (this.currentMode === 'enterprise') {
          // 企业模式：仅查询企业点图层
          features = this.map.queryRenderedFeatures(bbox, { layers: ['company-points'] });
          
          if (features && features.length) {
            const f = features[0];
            console.log('[Map Identify - Company] 命中企业点:', f);
            if (f && f.properties) {
              console.log('[Map Identify - Company] 企业属性:', f.properties);
              
              // 获取 stock_name 并显示企业信息卡片
              const stockName = f.properties.stock_name || f.properties.stockName || f.properties.stock_code;
              if (stockName) {
                console.log('[Map Identify - Company] stockName:', stockName);
                this.$refs.companyCard.show(stockName);
              } else {
                console.warn('[Map Identify - Company] 未找到 stock_name 字段，可用字段:', Object.keys(f.properties));
              }
            }
          } else {
            console.log('[Map Identify - Company] 未命中企业点');
          }
        } else if (this.currentMode === 'factory') {
          // 工厂模式：仅查询工厂点图层
          features = this.map.queryRenderedFeatures(bbox, { layers: ['factory-points'] });
          
          if (features && features.length) {
            const f = features[0];
            console.log('[Map Identify - Factory] 命中工厂点:', f);
            if (f && f.properties) {
              console.log('[Map Identify - Factory] 工厂属性:', f.properties);
              
              // 获取 factoryUuid 并显示工厂信息卡片
              // GeoJSON 中字段名为 factory_uu
              const factoryUuid = f.properties.factory_uu || f.properties.factoryUuid || f.properties.factory_uuid;
              if (factoryUuid) {
                console.log('[Map Identify - Factory] factoryUuid:', factoryUuid);
                this.$refs.factoryCard.show(factoryUuid);
              } else {
                console.warn('[Map Identify - Factory] 未找到 factory_uu 字段，可用字段:', Object.keys(f.properties));
              }
            }
          } else {
            console.log('[Map Identify - Factory] 未命中工厂点');
          }
        } else {
          // 市级和区级模式：查询面图层
          this.$refs.carbonCard && this.$refs.carbonCard.close()
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
    renderFactoryPoints() {
      if (!this.map || !this.factoryData) return;
      
      const sourceId = 'factory-source'
      const layerId = 'factory-points'
      
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
      
      // 添加工厂点图层
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-radius': 3,
          'circle-color': '#ff6b35',
          'circle-opacity': 0.8,
          'circle-stroke-width': 1,
          'circle-stroke-color': '#ffffff',
          'circle-stroke-opacity': 0.8
        },
        layout: {
          'visibility': this.currentMode === 'factory' ? 'visible' : 'none'
        }
      })
      // 确保工厂点在最上层
      try { if (this.map.getLayer(layerId)) this.map.moveLayer(layerId) } catch (e) { console.warn('moveLayer factory-points failed', e) }
      console.log('[Factory] 工厂点数据已渲染')
    },
    renderCompanyPoints() {
      if (!this.map || !this.companyData) return;
      
      const sourceId = 'company-source'
      const layerId = 'company-points'
      
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
      
      // 添加企业点图层
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-radius': 4,
          'circle-color': '#00f2ff',
          'circle-opacity': 0.85,
          'circle-stroke-width': 1.5,
          'circle-stroke-color': '#ffffff',
          'circle-stroke-opacity': 0.9
        },
        layout: {
          'visibility': this.currentMode === 'enterprise' ? 'visible' : 'none'
        }
      })
      // 确保企业点在最上层
      try { if (this.map.getLayer(layerId)) this.map.moveLayer(layerId) } catch (e) { console.warn('moveLayer company-points failed', e) }
      console.log('[Company] 企业点数据已渲染')
    },
    showCarbonPoint() {
      if (!this.map) return
      const sourceId = 'carbon-source'
      const layerId = this.carbonPointLayerId
      // 切换到碳排放点时，确保关闭企业/工厂卡片并隐藏它们的图层
      this.$refs.companyCard && this.$refs.companyCard.close && this.$refs.companyCard.close()
      this.$refs.factoryCard && this.$refs.factoryCard.close && this.$refs.factoryCard.close()
      if (this.map.getLayer('company-points')) {
        this.map.setLayoutProperty('company-points', 'visibility', 'none')
      }
      if (this.map.getLayer('factory-points')) {
        this.map.setLayoutProperty('factory-points', 'visibility', 'none')
      }
      this.$refs.carbonCard && this.$refs.carbonCard.close()
      const carbonFeature = {
        type: 'FeatureCollection',
        features: [{
          type: 'Feature',
          properties: { name: '碳排放监测点' },
          geometry: {
            type: 'Point',
            coordinates: [113.5721821, 22.7860305]
          }
        }]
      }
      if (this.map.getLayer(layerId)) {
        this.map.getSource(sourceId)?.setData(carbonFeature)
        this.map.setLayoutProperty(layerId, 'visibility', 'visible')
        return
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
      }
      this.map.addSource(sourceId, {
        type: 'geojson',
        data: carbonFeature
      })
      this.map.addLayer({
        id: layerId,
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-radius': 8,
          'circle-color': '#34D399',
          'circle-opacity': 0.9,
          'circle-stroke-width': 2,
          'circle-stroke-color': '#FFFFFF',
          'circle-stroke-opacity': 0.9
        }
      })
      this.map.flyTo({
        center: [113.5721821, 22.7860305],
        zoom: 11,
        speed: 0.8
      })
    },
    removeCarbonPoint() {
      if (!this.map) return
      const sourceId = 'carbon-source'
      const layerId = this.carbonPointLayerId
      this.$refs.carbonCard && this.$refs.carbonCard.close()
      if (this.map.getLayer(layerId)) {
        this.map.removeLayer(layerId)
      }
      if (this.map.getSource(sourceId)) {
        this.map.removeSource(sourceId)
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

/* 数据切换面板 */
.mode-switch-panel {
  position: absolute;
  bottom: 20px;
  right: 20px;
  /* transform: translateX(-50%); */
  z-index: 1000;
  background: transparent;
  padding: 0;
}

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
  background: rgba(0, 30, 60, 0.3);
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
</style>
