# rbmDashboard

A comprehensive Vue 2-based GIS dashboard application designed for visualizing complex map data, environmental metrics, and green finance analytics.

## Overview

**rbmDashboard** is a modern frontend application built with Vue.js. It integrates advanced mapping capabilities using SuperMap iClient (supporting MapboxGL) and rich data visualizations via ECharts. The dashboard is designed to provide real-time insights into carbon emissions, ESG reports, and various environmental indicators in a "Digital Twin" style interface.

## Key Features

- **Interactive Maps**: High-performance map rendering using `@supermap/vue-iclient-mapboxgl`. Supports visualization of GeoJSON data (e.g., Greater Bay Area).
- **Data Visualization**: 
    - Real-time charts and graphs powered by ECharts.
    - Specialized components for Green Finance, Carbon Emissions, and Temperature trends.
    - "Digital Twin" aesthetic with dynamic background effects.
- **Smart API Integration**: 
    - Automatic backend probing to select the best available API host (Localhost vs. LAN vs. Remote/Production).
    - Robust Axios configuration with timeout handling.
- **User System**:
    - Dedicated Login page.
    - Profile Setup wizard.
    - User authentication state management.
- **AI Agent Integration**:
    - Built-in chat interface for interacting with an AI Agent directly from the dashboard.
    - Markdown rendering support for AI responses.

## Tech Stack

- **Framework**: [Vue.js 2](https://v2.vuejs.org/)
- **Routing**: Vue Router
- **HTTP Client**: Axios
- **Mapping**: [SuperMap iClient for MapboxGL](https://iclient.supermap.io/web/introduction/mapboxgl.html) & Mapbox GL JS
- **Charts**: ECharts
- **Math Rendering**: KaTeX (for mathematical formulas in chat)

## Project Setup

### Prerequisites

- Node.js (Recommended: LTS version compatible with Vue 2 ecosystem)
- npm or yarn

### Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/zzhou638/rbmDashboard.git
cd rbmDashboard
npm install
```

### Development

Run the development server with hot-reload:

```bash
npm run serve
```

### Production Build

Compile and minify for production:

```bash
npm run build
```

### Linting

Lint and fix files:

```bash
npm run lint
```

## Project Structure

- `src/api`: API configuration and auto-probing logic.
- `src/components`: Reusable UI components (Chart widgets, Map display, etc.).
- `src/views`: Main page views (Home, Login, ProfileSetup).
- `src/router`: Route definitions.
- `public`: Static assets.

## Configuration

The application automatically attempts to connect to the following backend hosts in priority order:
1. `http://localhost:8085` (Local Dev)
2. `http://10.7.0.1:8085` (LAN)
3. `https://api.zhougis.app` (Production)

You can override the API host by setting the `VUE_APP_API_HOST` environment variable.
