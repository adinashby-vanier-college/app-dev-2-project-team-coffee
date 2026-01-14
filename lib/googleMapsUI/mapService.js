/**
 * ------------------------------------------------------------------
 * MAP SERVICE - Utility Functions
 * ------------------------------------------------------------------
 */

/**
 * Search locations by query string
 * @param {Array} locations - Array of location objects
 * @param {string} query - Search query
 * @returns {Array} Filtered locations
 */
window.MapService = window.MapService || {};
window.MapService.searchLocations = (locations, query) => {
  if (!query || query.trim() === '') {
    return [];
  }
  
  const searchTerm = query.toLowerCase().trim();
  
  return locations.filter(loc => 
    loc.name.toLowerCase().includes(searchTerm) || 
    loc.category.toLowerCase().includes(searchTerm) ||
    loc.type.toLowerCase().includes(searchTerm)
  );
};

/**
 * Calculate view state to center on a location
 * @param {Object} location - Location object with coordinates
 * @param {Object} options - Options for view calculation
 * @returns {Object} View state with x, y, and scale
 */
window.MapService.calculateViewForLocation = (location, options = {}) => {
  const { 
    offsetX = 200, 
    offsetY = 400, 
    scale = 1 
  } = options;
  
  return {
    x: -location.coordinates.x + offsetX,
    y: -location.coordinates.y + offsetY,
    scale: scale
  };
};

/**
 * Calculate zoom with min/max constraints
 * @param {number} currentScale - Current scale value
 * @param {string} direction - 'in' or 'out'
 * @param {Object} constraints - Min and max scale values
 * @returns {number} New scale value
 */
window.MapService.calculateZoom = (currentScale, direction, constraints = {}) => {
  const { min = 0.2, max = 3, factor = 1.5 } = constraints;
  
  if (direction === 'in') {
    return Math.min(currentScale * factor, max);
  } else {
    return Math.max(currentScale / factor, min);
  }
};

/**
 * Get marker color based on location type
 * @param {string} type - Location type
 * @returns {string} Tailwind color class
 */
window.MapService.getMarkerColor = (type) => {
  const colorMap = {
    restaurant: 'bg-orange-500',
    food: 'bg-orange-500',
    bar: 'bg-purple-500',
    shop: 'bg-pink-500',
    hotel: 'bg-indigo-500',
    attraction: 'bg-teal-500',
    landmark: 'bg-teal-500',
    park: 'bg-green-600',
    default: 'bg-red-500'
  };
  
  return colorMap[type] || colorMap.default;
};

/**
 * Get marker border color based on location type
 * @param {string} type - Location type
 * @returns {string} Tailwind color class for border
 */
window.MapService.getMarkerBorderColor = (type) => {
  const colorMap = {
    restaurant: 'border-t-orange-500',
    food: 'border-t-orange-500',
    bar: 'border-t-purple-500',
    shop: 'border-t-pink-500',
    hotel: 'border-t-indigo-500',
    attraction: 'border-t-teal-500',
    landmark: 'border-t-teal-500',
    park: 'border-t-green-600',
    default: 'border-t-red-500'
  };
  
  return colorMap[type] || colorMap.default;
};

/**
 * Get default view state (centered and zoomed out)
 * @param {Object} options - Optional viewport dimensions for centering
 * @param {number} options.viewportWidth - Viewport width in pixels
 * @param {number} options.viewportHeight - Viewport height in pixels
 * @returns {Object} Default view state
 */
window.MapService.getDefaultViewState = (options = {}) => {
  const mapCanvasSize = 3000; // Map canvas is 3000x3000
  const mapCenter = mapCanvasSize / 2; // Center of map is at (1500, 1500)
  const scale = 0.5; // Initial zoom scale (more zoomed in)
  
  // If viewport dimensions are provided, center the map
  if (options.viewportWidth && options.viewportHeight) {
    const viewportCenterX = options.viewportWidth / 2;
    const viewportCenterY = options.viewportHeight / 2;
    
    return {
      x: viewportCenterX - (mapCenter * scale),
      y: viewportCenterY - (mapCenter * scale),
      scale: scale
    };
  }
  
  // Fallback: approximate centering for typical mobile viewport
  // Assuming ~400px width and ~600px height for map area
  const approximateViewportWidth = 400;
  const approximateViewportHeight = 600;
  const approximateViewportCenterX = approximateViewportWidth / 2;
  const approximateViewportCenterY = approximateViewportHeight / 2;
  
  return {
    x: approximateViewportCenterX - (mapCenter * scale),
    y: approximateViewportCenterY - (mapCenter * scale),
    scale: scale
  };
};
