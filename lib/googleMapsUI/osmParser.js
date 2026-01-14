/**
 * OSM Parser - Parses OpenStreetMap XML files
 */

/**
 * Parse OSM XML file
 * @param {string} xmlText - OSM XML content
 * @returns {Object} Parsed OSM data with nodes, ways, and bounds
 */
window.OSMParser = window.OSMParser || {};
window.OSMParser.parseOSM = function(xmlText) {
  const parser = new DOMParser();
  const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
  
  // Extract bounds
  const boundsElement = xmlDoc.querySelector('bounds');
  const bounds = boundsElement ? {
    minLat: parseFloat(boundsElement.getAttribute('minlat')),
    minLon: parseFloat(boundsElement.getAttribute('minlon')),
    maxLat: parseFloat(boundsElement.getAttribute('maxlat')),
    maxLon: parseFloat(boundsElement.getAttribute('maxlon'))
  } : null;
  
  // Extract all nodes
  const nodeElements = xmlDoc.querySelectorAll('node');
  const nodes = new Map();
  
  nodeElements.forEach(nodeEl => {
    const id = nodeEl.getAttribute('id');
    const lat = parseFloat(nodeEl.getAttribute('lat'));
    const lon = parseFloat(nodeEl.getAttribute('lon'));
    
    const tags = {};
    nodeEl.querySelectorAll('tag').forEach(tagEl => {
      tags[tagEl.getAttribute('k')] = tagEl.getAttribute('v');
    });
    
    nodes.set(id, { id, lat, lon, tags });
  });
  
  // Extract all ways
  const wayElements = xmlDoc.querySelectorAll('way');
  const ways = [];
  
  wayElements.forEach(wayEl => {
    const id = wayEl.getAttribute('id');
    
    // Get node references
    const nodeRefs = [];
    wayEl.querySelectorAll('nd').forEach(ndEl => {
      nodeRefs.push(ndEl.getAttribute('ref'));
    });
    
    // Get tags
    const tags = {};
    wayEl.querySelectorAll('tag').forEach(tagEl => {
      tags[tagEl.getAttribute('k')] = tagEl.getAttribute('v');
    });
    
    ways.push({ id, nodeRefs, tags });
  });
  
  return { bounds, nodes, ways };
}

/**
 * Categorize ways by type for rendering
 * @param {Array} ways - Array of way objects
 * @returns {Object} Categorized ways
 */
window.OSMParser.categorizeWays = function(ways) {
  const categories = {
    highways: [],
    buildings: [],
    parks: [],
    water: [],
    other: []
  };
  
  ways.forEach(way => {
    const tags = way.tags;
    
    if (tags.highway) {
      categories.highways.push(way);
    } else if (tags.building) {
      categories.buildings.push(way);
    } else if (tags.leisure === 'park' || tags.landuse === 'recreation_ground' || 
               tags.landuse === 'park' || tags.landuse === 'grass' ||
               tags.natural === 'wood' || tags.natural === 'tree_row') {
      categories.parks.push(way);
    } else if (tags.natural === 'water' || tags.waterway || tags.landuse === 'water' ||
               tags.amenity === 'fountain') {
      categories.water.push(way);
    } else {
      categories.other.push(way);
    }
  });
  
  return categories;
}
