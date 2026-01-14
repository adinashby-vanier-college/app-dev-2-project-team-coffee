/**
 * OSM Renderer - Renders OpenStreetMap data to SVG
 */

/**
 * Convert lat/lon coordinates to pixel coordinates
 * @param {number} lat - Latitude
 * @param {number} lon - Longitude
 * @param {Object} bounds - Bounds object with minLat, maxLat, minLon, maxLon
 * @param {number} canvasWidth - Width of the canvas in pixels
 * @param {number} canvasHeight - Height of the canvas in pixels
 * @returns {Object} Pixel coordinates {x, y}
 */
window.OSMRenderer = window.OSMRenderer || {};
window.OSMRenderer.latLonToPixel = function(lat, lon, bounds, canvasWidth, canvasHeight) {
  const latRange = bounds.maxLat - bounds.minLat;
  const lonRange = bounds.maxLon - bounds.minLon;
  
  // Calculate aspect ratios
  const geoAspectRatio = latRange / lonRange; // Geographic aspect ratio (height/width)
  const canvasAspectRatio = canvasHeight / canvasWidth; // Canvas aspect ratio
  
  // Normalize to 0-1 range
  const normalizedLat = (bounds.maxLat - lat) / latRange; // Inverted Y axis
  const normalizedLon = (lon - bounds.minLon) / lonRange;
  
  // Preserve aspect ratio - scale both dimensions uniformly
  // We'll fit the geographic bounds to the canvas while maintaining correct aspect ratio
  const scale = Math.min(canvasWidth / lonRange, canvasHeight / latRange);
  const scaledWidth = lonRange * scale;
  const scaledHeight = latRange * scale;
  
  // Center the map in the canvas
  const offsetX = (canvasWidth - scaledWidth) / 2;
  const offsetY = (canvasHeight - scaledHeight) / 2;
  
  return {
    x: offsetX + normalizedLon * scaledWidth,
    y: offsetY + normalizedLat * scaledHeight
  };
}

/**
 * Get highway stroke width based on highway type
 * @param {string} highwayType - Highway type from OSM
 * @returns {number} Stroke width in pixels
 */
window.OSMRenderer.getHighwayWidth = function(highwayType) {
  const widthMap = {
    motorway: 28,
    trunk: 26,
    primary: 22,
    secondary: 18,
    tertiary: 14,
    'residential': 8,
    'service': 6,
    'footway': 4,
    'path': 3,
    'default': 12
  };
  
  return widthMap[highwayType] || widthMap.default;
}

/**
 * Get highway color based on highway type
 * @param {string} highwayType - Highway type from OSM
 * @returns {string} Color hex or name
 */
window.OSMRenderer.getHighwayColor = function(highwayType) {
  const colorMap = {
    motorway: '#FDE047',
    trunk: '#FDE047',
    primary: '#FDE047',
    secondary: '#FBBF24',
    tertiary: '#FBBF24',
    'residential': '#FFFFFF',
    'service': '#F5F5F0',
    'footway': '#E5E7EB',
    'path': '#E5E7EB',
    'default': '#94A3B8'
  };
  
  return colorMap[highwayType] || colorMap.default;
}

/**
 * Render way as SVG path
 * @param {Object} way - Way object with nodeRefs
 * @param {Map} nodes - Map of node IDs to node objects
 * @param {Object} bounds - Bounds for coordinate conversion
 * @param {number} canvasWidth - Canvas width
 * @param {number} canvasHeight - Canvas height
 * @param {boolean} closed - Whether the path should be closed (for polygons)
 * @returns {string} SVG path data string
 */
window.OSMRenderer.wayToPath = function(way, nodes, bounds, canvasWidth, canvasHeight, closed = false) {
  const points = way.nodeRefs
    .map(ref => nodes.get(ref))
    .filter(node => node != null)
    .map(node => latLonToPixel(node.lat, node.lon, bounds, canvasWidth, canvasHeight));
  
  if (points.length === 0) return '';
  
  let pathData = `M ${points[0].x} ${points[0].y}`;
  
  for (let i = 1; i < points.length; i++) {
    pathData += ` L ${points[i].x} ${points[i].y}`;
  }
  
  if (closed && points.length > 2) {
    pathData += ' Z';
  }
  
  return pathData;
}

/**
 * Generate SVG elements from categorized ways
 * @param {Object} categorizedWays - Categorized ways object
 * @param {Map} nodes - Map of node IDs to node objects
 * @param {Object} bounds - Bounds for coordinate conversion
 * @param {number} canvasWidth - Canvas width
 * @param {number} canvasHeight - Canvas height
 * @returns {Array} Array of React SVG elements
 */
window.OSMRenderer.renderOSMToSVG = function(categorizedWays, nodes, bounds, canvasWidth, canvasHeight) {
  const React = window.React;
  const elements = [];
  
  // Render water first (background layer)
  categorizedWays.water.forEach(way => {
    const pathData = window.OSMRenderer.wayToPath(way, nodes, bounds, canvasWidth, canvasHeight, true);
    if (pathData) {
      elements.push(
        React.createElement('path', {
          key: `water-${way.id}`,
          d: pathData,
          fill: "#A7D3F0",
          stroke: "#91B8D1",
          strokeWidth: "2",
          opacity: "0.8"
        })
      );
    }
  });
  
  // Render parks (green areas)
  categorizedWays.parks.forEach(way => {
    const pathData = window.OSMRenderer.wayToPath(way, nodes, bounds, canvasWidth, canvasHeight, true);
    if (pathData) {
      elements.push(
        React.createElement('path', {
          key: `park-${way.id}`,
          d: pathData,
          fill: "#C8E6C9",
          stroke: "#A5D6A7",
          strokeWidth: "2"
        })
      );
    }
  });
  
  // Render buildings
  categorizedWays.buildings.forEach(way => {
    const pathData = window.OSMRenderer.wayToPath(way, nodes, bounds, canvasWidth, canvasHeight, true);
    if (pathData) {
      elements.push(
        React.createElement('path', {
          key: `building-${way.id}`,
          d: pathData,
          fill: "#E5E3DF",
          stroke: "#D1CFCB",
          strokeWidth: "1"
        })
      );
    }
  });
  
  // Render highways (roads)
  categorizedWays.highways.forEach(way => {
    const highwayType = way.tags.highway || 'default';
    const strokeWidth = window.OSMRenderer.getHighwayWidth(highwayType);
    const strokeColor = window.OSMRenderer.getHighwayColor(highwayType);
    const pathData = window.OSMRenderer.wayToPath(way, nodes, bounds, canvasWidth, canvasHeight, false);
    
    if (pathData) {
      elements.push(
        React.createElement('path', {
          key: `highway-${way.id}`,
          d: pathData,
          fill: "none",
          stroke: strokeColor,
          strokeWidth: strokeWidth,
          strokeLinecap: "round",
          strokeLinejoin: "round",
          opacity: highwayType === 'motorway' || highwayType === 'trunk' ? 0.75 : 1
        })
      );
    }
  });
  
  return elements;
}
