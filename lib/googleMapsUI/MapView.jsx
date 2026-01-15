const { useState, useRef, useEffect } = React;

// Simple icon component to replace lucide-react
const Icon = ({ name, className, style }) => {
  const svgPaths = {
    MapPin: 'M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z M12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
    Star: 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z',
    Clock: 'M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8z M12 6v6l4 2',
    Phone: 'M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z',
    Globe: 'M21 12a9 9 0 0 1-9 9m9-9a9 9 0 0 0-9-9m9 9H3m9 9a9 9 0 0 1-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 0 1 9-9',
    Share2: 'M18 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M6 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M13.5 10.5L18 8M13.5 13.5L18 16M6 13v-2',
    Bookmark: 'M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z',
    X: 'M18 6L6 18M6 6l12 12',
    Plus: 'M12 5v14m7-7H5',
    Minus: 'M5 12h14',
    Search: 'M21 21l-6-6m2-5a7 7 0 1 1-14 0 7 7 0 0 1 14 0z',
    ChevronDown: 'M6 9l6 6 6-6',
    ChevronUp: 'M18 15l-6-6-6 6',
    Beer: 'M17 11v1a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-1M17 11V9a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v2M17 11h2a2 2 0 0 1 2 2v1a2 2 0 0 1-2 2h-2',
    Coffee: 'M18 8h1a4 4 0 0 1 0 8h-1M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8zM6 1v3M10 1v3M14 1v3',
    Utensils: 'M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3z',
    ShoppingBag: 'M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4zM3 6h18M16 10a4 4 0 0 1-8 0',
    Landmark: 'M3 21l9-9 9 9M12 3v18',
    Hotel: 'M18 2H6a2 2 0 0 0-2 2v18l4-4h8l4 4V4a2 2 0 0 0-2-2z',
    Train: 'M16 1H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2zM5 5h6M5 9h6M5 13h6',
    Compass: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM12 2v20M17 7l-5 5-5-5'
  };
  const path = svgPaths[name] || '';
  return React.createElement('svg', {
    className,
    style: style || {},
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2,
    strokeLinecap: 'round',
    strokeLinejoin: 'round'
  }, React.createElement('path', { d: path }));
};

// Create global icon components for backward compatibility
const createIconComponent = (name) => (props) => React.createElement(Icon, { ...props, name });
const MapPin = createIconComponent('MapPin');
const Star = createIconComponent('Star');
const Clock = createIconComponent('Clock');
const Phone = createIconComponent('Phone');
const Globe = createIconComponent('Globe');
const Share2 = createIconComponent('Share2');
const Bookmark = createIconComponent('Bookmark');
const X = createIconComponent('X');
const Plus = createIconComponent('Plus');
const Minus = createIconComponent('Minus');
const Search = createIconComponent('Search');
const ChevronDown = createIconComponent('ChevronDown');
const ChevronUp = createIconComponent('ChevronUp');
const Beer = createIconComponent('Beer');
const Coffee = createIconComponent('Coffee');
const Utensils = createIconComponent('Utensils');
const ShoppingBag = createIconComponent('ShoppingBag');
const Landmark = createIconComponent('Landmark');
const Hotel = createIconComponent('Hotel');
const Train = createIconComponent('Train');
const Compass = createIconComponent('Compass');

const App = () => {
  const [selectedLocation, setSelectedLocation] = useState(null);
  const [viewState, setViewState] = useState(window.MapService.getDefaultViewState()); // Initial state, will be updated by useEffect 
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [isHoursExpanded, setIsHoursExpanded] = useState(false);
  const [hoveredLocationId, setHoveredLocationId] = useState(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);

  // Saved locations state (persisted during runtime)
  const [savedLocations, setSavedLocations] = useState(new Set());

  // OSM Data State
  const [osmData, setOsmData] = useState(null);
  const [osmSvgElements, setOsmSvgElements] = useState([]);
  const [isLoadingOSM, setIsLoadingOSM] = useState(true);

  // Locations State (loaded from Firebase via Flutter)
  const [locations, setLocations] = useState([]);

  const mapRef = useRef(null);
  const currentDay = new Date().toLocaleDateString('en-US', { weekday: 'long' });

  // --- INITIALIZE MAP VIEW (Center and zoom out) ---
  useEffect(() => {
    if (mapRef.current) {
      const viewportWidth = mapRef.current.clientWidth;
      const viewportHeight = mapRef.current.clientHeight;
      if (viewportWidth > 0 && viewportHeight > 0) {
        const centeredViewState = window.MapService.getDefaultViewState({
          viewportWidth,
          viewportHeight
        });
        setViewState(centeredViewState);
      }
    }
  }, []); // Run once on mount

  // --- LOAD OSM DATA ---
  useEffect(() => {
    const loadOSMData = async () => {
      try {
        setIsLoadingOSM(true);
        const response = await fetch('/map.osm');
        if (!response.ok) {
          throw new Error(`Failed to load OSM file: ${response.status}`);
        }
        const xmlText = await response.text();
        const parsed = window.OSMParser.parseOSM(xmlText);

        if (!parsed.bounds) {
          throw new Error('OSM file missing bounds');
        }

        setOsmData(parsed);

        // Categorize ways and render to SVG
        const categorized = window.OSMParser.categorizeWays(parsed.ways);
        const canvasWidth = 3000;
        const canvasHeight = 3000;
        const svgElements = window.OSMRenderer.renderOSMToSVG(categorized, parsed.nodes, parsed.bounds, canvasWidth, canvasHeight);
        setOsmSvgElements(svgElements);
      } catch (error) {
        console.error('Error loading OSM data:', error);
        // Set empty elements on error so map still renders
        setOsmSvgElements([]);
      } finally {
        setIsLoadingOSM(false);
      }
    };

    loadOSMData();
  }, []);

  // --- LOAD LOCATIONS FROM FLUTTER ---
  useEffect(() => {
    // Function to receive locations from Flutter
    window.loadLocationsFromFlutter = (locationsData) => {
      setLocations(locationsData || []);
    };

    // Check if there's queued locations data from before React was ready
    if (window._locationsQueue && window._locationsQueue.length > 0) {
      const queuedLocations = window._locationsQueue.shift();
      setLocations(queuedLocations || []);
    }

  }, []);

  // --- FRIENDS STATE ---
  const [friends, setFriends] = useState([]);

  useEffect(() => {
    window.loadFriendsFromFlutter = (friendsData) => {
      setFriends(friendsData || []);
    };
    if (window._friendsQueue && window._friendsQueue.length > 0) {
      setFriends(window._friendsQueue.shift() || []);
    }
  }, []);

  // --- SEARCH LOGIC ---
  useEffect(() => {
    const results = window.MapService.searchLocations(locations, searchQuery);
    setSearchResults(results);
  }, [searchQuery, locations]);

  const handleSearchSelect = (location) => {
    setSelectedLocation(location);
    setIsHoursExpanded(false);
    setSearchQuery('');
    setSearchResults([]);
    const newViewState = window.MapService.calculateViewForLocation(location);
    setViewState(newViewState);
  };

  // --- PANNING LOGIC ---
  const handleMouseDown = (e) => {
    setIsDragging(true);
    setDragStart({ x: e.clientX - viewState.x, y: e.clientY - viewState.y });
  };

  const handleMouseMove = (e) => {
    if (!isDragging) return;
    e.preventDefault();
    setViewState(prev => ({
      ...prev,
      x: e.clientX - dragStart.x,
      y: e.clientY - dragStart.y
    }));
  };

  const handleMouseUp = () => setIsDragging(false);

  // --- ZOOM LOGIC ---
  const handleZoom = (direction) => {
    if (!mapRef.current) return;

    setViewState(prev => {
      // Get viewport dimensions
      const viewportWidth = mapRef.current.clientWidth;
      const viewportHeight = mapRef.current.clientHeight;

      // Calculate viewport center
      const viewportCenterX = viewportWidth / 2;
      const viewportCenterY = viewportHeight / 2;

      // Calculate the map coordinate at the viewport center before zoom
      const mapPointX = (viewportCenterX - prev.x) / prev.scale;
      const mapPointY = (viewportCenterY - prev.y) / prev.scale;

      // Calculate new scale
      const newScale = window.MapService.calculateZoom(prev.scale, direction);

      // Adjust x and y so the same map point stays at the viewport center after zoom
      const newX = viewportCenterX - (mapPointX * newScale);
      const newY = viewportCenterY - (mapPointY * newScale);

      return { ...prev, scale: newScale, x: newX, y: newY };
    });
  };

  const handlePinClick = (e, location) => {
    e.stopPropagation();
    setSelectedLocation(location);
    setIsHoursExpanded(false);
  };

  const closeSheet = () => {
    setSelectedLocation(null);
    setIsHoursExpanded(false);
  };

  const toggleHours = () => {
    setIsHoursExpanded(!isHoursExpanded);
  };

  const handleSaveToggle = () => {
    if (!selectedLocation) return;
    setSavedLocations(prev => {
      const newSet = new Set(prev);
      if (newSet.has(selectedLocation.id)) {
        newSet.delete(selectedLocation.id);
      } else {
        newSet.add(selectedLocation.id);
      }
      return newSet;
    });
  };

  const handleSendSceneClick = () => {
    if (selectedLocation) {
      if (window.FlutterShowSendSceneModal) {
        window.FlutterShowSendSceneModal.postMessage(selectedLocation.id);
      } else {
        console.warn('FlutterShowSendSceneModal channel not available');
      }
    }
  };

  const handleAddressClick = (address) => {
    if (!address) return;
    const googleMapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`;
    window.open(googleMapsUrl, '_blank', 'noopener,noreferrer');
  };

  return (
    <div className="min-h-screen bg-slate-200 flex items-center justify-center p-0 sm:p-4 font-sans">

      {/* DEVICE FRAME */}
      <div className="relative w-full max-w-[412px] h-[100dvh] sm:h-[844px] bg-slate-100 overflow-hidden sm:rounded-[3rem] sm:border-[8px] border-slate-900 shadow-2xl text-slate-900 select-none flex flex-col">

        {/* --- MAP VIEWPORT --- */}
        <div
          className="flex-1 relative overflow-hidden cursor-move active:cursor-grabbing bg-[#E5E3DF]"
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={handleMouseUp}
          onMouseLeave={handleMouseUp}
          ref={mapRef}
        >
          {/* MAP CONTENT CONTAINER (3000px Canvas) */}
          <div
            className="absolute origin-top-left transition-transform duration-75 ease-linear"
            style={{
              transform: `translate(${viewState.x}px, ${viewState.y}px) scale(${viewState.scale})`,
              width: '3000px',
              height: '3000px'
            }}
          >
            {/* =====================================================================================
               THE MAP LAYER - RENDERED FROM OSM DATA
               ===================================================================================== */}
            {isLoadingOSM ? (
              <div className="absolute inset-0 flex items-center justify-center bg-[#E5E3DF]">
                <div className="text-slate-500 text-sm">Loading map data...</div>
              </div>
            ) : (
              <svg width="3000" height="3000" viewBox="0 0 3000 3000" xmlns="http://www.w3.org/2000/svg" className="absolute inset-0 pointer-events-none">
                <defs>
                  {/* City Texture Pattern */}
                  <pattern id="cityGrid" width="20" height="20" patternUnits="userSpaceOnUse" patternTransform="rotate(-15)">
                    <path d="M 20 0 L 0 0 0 20" fill="none" stroke="#d9d7d3" strokeWidth="0.8" />
                  </pattern>
                </defs>

                {/* Base City Layer */}
                <rect width="3000" height="3000" fill="url(#cityGrid)" />

                {/* OSM Rendered Elements */}
                {osmSvgElements}
              </svg>
            )}

            {/* =====================================================================================
               NEIGHBORHOOD & DISTRICT LABELS
               ===================================================================================== */}

            <div className="absolute top-[1850px] left-[1200px] text-[32px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Downtown</div>
            <div className="absolute top-[2150px] left-[1600px] text-[26px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Old Port</div>
            <div className="absolute top-[1350px] left-[1700px] text-[30px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Plateau</div>
            <div className="absolute top-[900px] left-[1400px] text-[24px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Mile End</div>
            <div className="absolute top-[2200px] left-[800px] text-[24px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Griffintown</div>
            <div className="absolute top-[700px] left-[2600px] text-[24px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Hochelaga</div>
            <div className="absolute top-[1050px] left-[1100px] text-[28px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-5deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Outremont</div>
            <div className="absolute top-[1500px] left-[700px] text-[26px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Westmount</div>
            <div className="absolute top-[2080px] left-[1000px] text-[22px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Little Burgundy</div>
            <div className="absolute top-[1920px] left-[1350px] text-[20px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Quartier des Spectacles</div>
            <div className="absolute top-[2380px] left-[1500px] text-[20px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Cité Multimedia</div>
            <div className="absolute top-[2500px] left-[2200px] text-[22px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Cité du Havre</div>
            <div className="absolute top-[1680px] left-[720px] text-[18px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Victoria Village</div>
            <div className="absolute top-[2580px] left-[800px] text-[18px] font-black text-slate-600/25 uppercase tracking-[0.15em] rotate-[-8deg] pointer-events-none" style={{ fontFamily: 'Arial, sans-serif', letterSpacing: '0.15em' }}>Les Cours Pointe St. Charles</div>

            {/* -- MARKERS -- */}
            {locations.map((loc) => {
              const markerColor = window.MapService.getMarkerColor(loc.type);
              const borderColor = window.MapService.getMarkerBorderColor(loc.type);
              const isSelected = selectedLocation?.id === loc.id;

              // Calculate dynamic sizes to keep markers at constant screen size
              // Since markers are inside a scaled container, we scale inversely
              // Base sizes are the desired screen size (small, like real maps)
              const basePinSize = 20; // Small pin size on screen
              const baseIconSize = 10;
              const baseBorderWidth = 1.5;
              const baseNeedleLeftRight = 3;
              const baseNeedleTop = 4;
              const baseLabelFontSize = 8;
              const baseLabelPaddingX = 6;
              const baseLabelPaddingY = 3;
              const baseLabelBorderRadius = 8; // More rounded
              const baseLabelMarginTop = 3;
              const baseDefaultDotSize = 5;

              // Scale inversely to counteract container scaling
              const inverseScale = 1 / viewState.scale;
              const pinSize = basePinSize * inverseScale;
              const iconSize = baseIconSize * inverseScale;
              const borderWidth = baseBorderWidth * inverseScale;
              const needleLeftRight = baseNeedleLeftRight * inverseScale;
              const needleTop = baseNeedleTop * inverseScale;
              const labelFontSize = baseLabelFontSize * inverseScale;
              const labelPaddingX = baseLabelPaddingX * inverseScale;
              const labelPaddingY = baseLabelPaddingY * inverseScale;
              const labelBorderRadius = baseLabelBorderRadius * inverseScale;
              const labelMarginTop = baseLabelMarginTop * inverseScale;
              const defaultDotSize = baseDefaultDotSize * inverseScale;

              const isHovered = hoveredLocationId === loc.id;
              const isZoomedOut = viewState.scale <= 0.7;
              const showHoverCard = isHovered && isZoomedOut && !isSelected;

              return (
                <div
                  key={loc.id}
                  className="absolute transform -translate-x-1/2 -translate-y-full hover:scale-110 transition-transform duration-200 z-10 cursor-pointer"
                  style={{ left: loc.coordinates.x, top: loc.coordinates.y }}
                  onClick={(e) => handlePinClick(e, loc)}
                  onMouseDown={(e) => e.stopPropagation()}
                  onMouseEnter={() => setHoveredLocationId(loc.id)}
                  onMouseLeave={() => setHoveredLocationId(null)}
                >
                  <div className="relative flex flex-col items-center group">
                    {/* Pin */}
                    <div
                      className={`rounded-full border-white shadow-lg flex items-center justify-center transition-all duration-200 
                        ${isSelected ? 'bg-blue-600 scale-125 z-50 ring-4 ring-blue-200' : markerColor}
                      `}
                      style={{
                        width: `${pinSize}px`,
                        height: `${pinSize}px`,
                        borderWidth: `${borderWidth}px`,
                        borderStyle: 'solid'
                      }}
                    >
                      {loc.type === 'restaurant' || loc.type === 'food' ? <Utensils className="text-white" style={{ width: `${iconSize}px`, height: `${iconSize}px` }} /> :
                        loc.type === 'bar' ? <Beer className="text-white" style={{ width: `${iconSize}px`, height: `${iconSize}px` }} /> :
                          loc.type === 'shop' ? <ShoppingBag className="text-white" style={{ width: `${iconSize}px`, height: `${iconSize}px` }} /> :
                            loc.type === 'hotel' ? <Hotel className="text-white" style={{ width: `${iconSize}px`, height: `${iconSize}px` }} /> :
                              loc.type === 'landmark' || loc.type === 'attraction' ? <Landmark className="text-white" style={{ width: `${iconSize}px`, height: `${iconSize}px` }} /> :
                                loc.type === 'park' ? <MapPin className="text-white" style={{ width: `${iconSize}px`, height: `${iconSize}px` }} /> :
                                  <div className="bg-white rounded-full" style={{ width: `${defaultDotSize}px`, height: `${defaultDotSize}px` }} />
                      }
                    </div>

                    {/* Needle */}
                    <div
                      className={`w-0 h-0 border-l-transparent border-r-transparent -mt-0.5 
                         ${isSelected ? 'border-t-blue-600' : borderColor}
                      `}
                      style={{
                        borderLeftWidth: `${needleLeftRight}px`,
                        borderRightWidth: `${needleLeftRight}px`,
                        borderTopWidth: `${needleTop}px`,
                        borderStyle: 'solid'
                      }}
                    />

                    {/* Label (always visible title card) */}
                    <div
                      className="absolute top-full backdrop-blur-sm font-bold whitespace-nowrap pointer-events-none z-30"
                      style={{
                        fontFamily: 'Arial, sans-serif',
                        fontSize: `${labelFontSize}px`,
                        lineHeight: '1',
                        paddingLeft: `${labelPaddingX}px`,
                        paddingRight: `${labelPaddingX}px`,
                        paddingTop: `${labelPaddingY}px`,
                        paddingBottom: `${labelPaddingY}px`,
                        borderRadius: `${labelBorderRadius}px`,
                        marginTop: `${labelMarginTop}px`,
                        backgroundColor: showHoverCard || isSelected ? 'rgba(255, 255, 255, 0.95)' : 'rgba(255, 255, 255, 0.65)',
                        boxShadow: showHoverCard || isSelected ? '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)' : '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)',
                        border: showHoverCard || isSelected ? '1px solid rgba(0, 0, 0, 0.1)' : 'none',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        textAlign: 'center',
                        left: '50%',
                        transform: 'translateX(-50%)',
                        opacity: 1,
                        pointerEvents: 'none'
                      }}
                    >
                      {loc.name}
                    </div>
                  </div>
                </div>
              );
            })}

            {/* -- FRIEND MARKERS -- */}
            {friends.map((friend) => {
              if (!friend.location || (!friend.location.x && !friend.location.latitude)) return null;

              // Fallback: If x/y exist use them, else simple mock projection or ignore
              // For this task, we assume x/y are present or we mock them
              const x = friend.location.x || (friend.location.latitude ? (3000 - (friend.location.latitude * 30)) % 3000 : 1500);
              const y = friend.location.y || (friend.location.longitude ? (3000 - (friend.location.longitude * 30)) % 3000 : 1500);

              // Calculate dynamic sizes
              const inverseScale = 1 / viewState.scale;
              const avatarSize = 40 * inverseScale;
              const borderSize = 3 * inverseScale;

              return (
                <div
                  key={`friend-${friend.id}`}
                  className="absolute transform -translate-x-1/2 -translate-y-1/2 z-20 cursor-pointer hover:z-50"
                  style={{ left: x, top: y }}
                  title={friend.name}
                >
                  <div
                    className="rounded-full overflow-hidden border-white shadow-lg relative bg-white"
                    style={{
                      width: `${avatarSize}px`,
                      height: `${avatarSize}px`,
                      borderWidth: `${borderSize}px`,
                      borderStyle: 'solid',
                      borderColor: '#2563eb' // Blue-600
                    }}
                  >
                    {friend.photoURL ? (
                      <img src={friend.photoURL} alt={friend.name} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-slate-200 text-slate-500 font-bold" style={{ fontSize: `${avatarSize * 0.4}px` }}>
                        {friend.avatar}
                      </div>
                    )}
                  </div>
                  {/* Name Label */}
                  <div
                    className="absolute top-full left-1/2 transform -translate-x-1/2 mt-1 bg-white/90 backdrop-blur-sm px-2 py-0.5 rounded text-xs font-bold shadow-sm whitespace-nowrap text-slate-800 pointer-events-none"
                    style={{
                      fontSize: `${12 * inverseScale}px`,
                      marginTop: `${4 * inverseScale}px`,
                      borderRadius: `${4 * inverseScale}px`,
                      padding: `${2 * inverseScale}px ${6 * inverseScale}px`
                    }}
                  >
                    {friend.name}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* --- FLOATING CONTROLS --- */}
        {!selectedLocation && (
          <div className="absolute top-4 left-4 right-4 z-30 flex flex-col gap-2">
            <div className="bg-white rounded-full shadow-xl p-3 flex items-center gap-3 border border-slate-100">
              <Search className="w-5 h-5 text-slate-500 ml-1" />
              <input
                type="text"
                placeholder="Search Montreal..."
                className="flex-1 bg-transparent outline-none text-slate-800 placeholder-slate-400 text-sm"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
              {searchQuery && (
                <button onClick={() => setSearchQuery('')} className="p-1 hover:bg-slate-100 rounded-full">
                  <X className="w-4 h-4 text-slate-400" />
                </button>
              )}
            </div>

            {searchQuery && searchResults.length > 0 && (
              <div className="bg-white rounded-2xl shadow-xl border border-slate-100 overflow-hidden max-h-[60vh] overflow-y-auto animate-slide-up-sm">
                {searchResults.map((loc, index) => (
                  <div
                    key={loc.id}
                    onClick={() => handleSearchSelect(loc)}
                    className={`p-4 flex items-center gap-3 active:bg-slate-50 border-b border-slate-50 last:border-0 cursor-pointer hover:bg-slate-50 transition-colors`}
                  >
                    <div className="w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center flex-shrink-0">
                      <MapPin className="w-5 h-5 text-slate-500" />
                    </div>
                    <div className="flex flex-col flex-1">
                      <span className="font-medium text-slate-900 text-sm">{loc.name}</span>
                      <span className="text-xs text-slate-500">{loc.category} • {loc.distance}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* --- ZOOM CONTROLS (Bottom Right) --- */}
        <div className="absolute right-4 bottom-24 flex flex-col gap-2 z-20">
          <button
            onClick={() => handleZoom('in')}
            className="w-11 h-11 bg-white rounded-full shadow-lg flex items-center justify-center text-slate-600 active:bg-slate-50 border border-slate-100 hover:shadow-xl transition-shadow"
          >
            <Plus className="w-5 h-5" />
          </button>
          <button
            onClick={() => handleZoom('out')}
            className="w-11 h-11 bg-white rounded-full shadow-lg flex items-center justify-center text-slate-600 active:bg-slate-50 border border-slate-100 hover:shadow-xl transition-shadow"
          >
            <Minus className="w-5 h-5" />
          </button>
        </div>

        {/* --- GOOGLE MAPS WATERMARK (Bottom Center) --- */}
        <div className="absolute bottom-2 left-1/2 transform -translate-x-1/2 z-10 pointer-events-none">
          <div className="text-[10px] font-medium" style={{ fontFamily: 'Roboto, Arial, sans-serif', color: '#428fdf' }}>Alki Corp. Maps™</div>
        </div>

        {/* --- LOCATION DETAIL MODAL --- */}
        {selectedLocation && (
          <div className="absolute inset-0 z-30 flex flex-col justify-end">
            {/* Backdrop - Visual only, no click handler */}
            <div className="absolute inset-0 bg-black/10" />

            {/* The Sheet */}
            <div className="relative bg-white w-full rounded-t-3xl shadow-[0_-5px_20px_rgba(0,0,0,0.1)] animate-slide-up max-h-[75%] overflow-y-auto no-scrollbar">

              <div className="w-full flex justify-center pt-3 pb-1">
                <div className="w-12 h-1.5 bg-slate-300 rounded-full" />
              </div>

              <div className="p-5 pt-2">

                <div className="flex justify-between items-start mb-1">
                  <h2 className="text-2xl font-bold text-slate-800 pr-2">{selectedLocation.name}</h2>
                  <button
                    type="button"
                    onClick={closeSheet}
                    className="p-1.5 bg-slate-100 rounded-full hover:bg-slate-200 active:bg-slate-300 transition-colors flex-shrink-0 cursor-pointer"
                  >
                    <X className="w-5 h-5 text-slate-500" />
                  </button>
                </div>

                <div className="flex items-center gap-2 mb-4 flex-wrap">
                  <span className="font-bold text-sm text-slate-800">{selectedLocation.rating}</span>
                  <div className="flex text-yellow-400">
                    {[...Array(5)].map((_, i) => (
                      <Star key={i} className={`w-3.5 h-3.5 ${i < Math.floor(selectedLocation.rating) ? 'fill-current' : 'text-slate-200'}`} />
                    ))}
                  </div>
                  <span className="text-slate-500 text-sm">({selectedLocation.reviews} reviews)</span>
                  <span className="text-slate-300 text-xs">•</span>
                  <span className="text-slate-500 text-sm">{selectedLocation.category}</span>
                  {selectedLocation.price && (
                    <>
                      <span className="text-slate-300 text-xs">•</span>
                      <span className="text-slate-500 text-sm">{selectedLocation.price}</span>
                    </>
                  )}
                </div>

                <p className="text-sm text-slate-600 leading-relaxed mb-6">
                  {selectedLocation.description}
                </p>

                <div className="flex gap-4 overflow-x-auto no-scrollbar mb-6 pb-2">
                  <button
                    type="button"
                    onClick={handleSaveToggle}
                    className={`flex-1 min-w-[90px] py-2.5 px-4 rounded-full font-medium text-sm flex flex-col items-center gap-1 transition-colors cursor-pointer relative z-10 ${savedLocations.has(selectedLocation.id)
                      ? 'bg-green-50 border-2 border-green-500 text-green-700 hover:bg-green-100 active:bg-green-200'
                      : 'bg-slate-50 border-2 border-slate-200 text-slate-700 hover:bg-green-50 hover:border-green-500 hover:text-green-700 active:bg-green-100'
                      }`}
                  >
                    <Bookmark
                      className={`w-5 h-5 ${savedLocations.has(selectedLocation.id) ? 'fill-green-600 text-green-600' : ''}`}
                    />
                    <span>Save</span>
                  </button>
                  <button
                    type="button"
                    onClick={handleSendSceneClick}
                    className="flex-1 min-w-[90px] bg-slate-50 border-2 border-slate-200 text-slate-700 py-2.5 px-4 rounded-full font-medium text-sm flex flex-col items-center gap-1 hover:bg-red-50 hover:border-red-500 hover:text-red-700 active:bg-red-100 transition-colors cursor-pointer relative z-10"
                  >
                    <Share2 className="w-5 h-5" />
                    <span>Send Scene™</span>
                  </button>
                </div>

                <div className="h-px bg-slate-100 w-full mb-4" />

                <div className="space-y-4">
                  <div className="flex items-start gap-3">
                    <MapPin className="w-5 h-5 text-blue-600 mt-0.5 shrink-0" />
                    <button
                      type="button"
                      onClick={() => handleAddressClick(selectedLocation.address)}
                      className="text-sm text-slate-700 leading-relaxed text-left cursor-pointer hover:opacity-80 active:opacity-70 transition-opacity"
                    >
                      {selectedLocation.address}
                    </button>
                  </div>

                  {/* Hours Dropdown */}
                  <div className="relative">
                    <button
                      type="button"
                      onClick={toggleHours}
                      className="w-full flex items-start gap-3 text-left py-0.5 -mx-1 px-1 rounded-lg hover:bg-slate-50 active:bg-slate-100 transition-colors cursor-pointer"
                    >
                      <Clock className="w-5 h-5 text-blue-600 mt-0.5 shrink-0" />
                      <div className="flex-1 flex items-center justify-between gap-2 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap text-sm">
                          <span className={`font-medium ${selectedLocation.openStatus?.includes('Open') ? 'text-green-600' : selectedLocation.openStatus?.includes('Closed') ? 'text-red-500' : 'text-orange-500'}`}>
                            {selectedLocation.openStatus || 'Hours not available'}
                          </span>
                          {selectedLocation.closeTime && (
                            <span className="text-slate-500">⋅ Closes {selectedLocation.closeTime}</span>
                          )}
                        </div>
                        <ChevronDown className={`w-4 h-4 text-slate-400 shrink-0 transition-transform duration-200 ${isHoursExpanded ? 'rotate-180' : ''}`} />
                      </div>
                    </button>

                    {/* Expandable Weekly Hours */}
                    {isHoursExpanded && selectedLocation.hours && Array.isArray(selectedLocation.hours) && (
                      <div className="ml-8 space-y-1.5 pt-1 pb-1 relative z-10">
                        {selectedLocation.hours.map((dayData) => {
                          const isToday = currentDay === dayData.day;
                          return (
                            <div key={dayData.day} className={`flex justify-between text-sm ${isToday ? 'font-semibold text-slate-900' : 'text-slate-600'}`}>
                              <span className="w-28">{dayData.day}</span>
                              <span>{dayData.time}</span>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>

                  <div className="flex items-start gap-3">
                    <Globe className="w-5 h-5 text-blue-600 mt-0.5 shrink-0" />
                    <a
                      href={`https://www.${selectedLocation.name.toLowerCase().replace(/['\s]/g, '')}.com`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm text-slate-700 leading-relaxed text-left cursor-pointer hover:opacity-80 active:opacity-70 transition-opacity truncate"
                    >
                      www.{selectedLocation.name.toLowerCase().replace(/['\s]/g, '')}.com
                    </a>
                  </div>

                  <div className="flex items-start gap-3">
                    <Phone className="w-5 h-5 text-blue-600 mt-0.5 shrink-0" />
                    <a
                      href="tel:+15145550199"
                      className="text-sm text-slate-700 leading-relaxed text-left cursor-pointer hover:opacity-80 active:opacity-70 transition-opacity"
                    >
                      (514) 555-0199
                    </a>
                  </div>
                </div>

                <div className="mt-6">
                  <h3 className="font-bold text-slate-800 mb-3">Photos</h3>
                  <div className="flex gap-2 overflow-x-auto no-scrollbar h-32 pb-2">
                    <div className="w-32 h-full bg-slate-200 rounded-xl flex-shrink-0 animate-pulse" />
                    <div className="w-32 h-full bg-slate-200 rounded-xl flex-shrink-0 animate-pulse delay-75" />
                    <div className="w-32 h-full bg-slate-200 rounded-xl flex-shrink-0 animate-pulse delay-150" />
                  </div>
                </div>

                <div className="h-8" />
              </div>
            </div>
          </div>
        )}


      </div>

      <style>{`
        @keyframes slide-up {
          from { transform: translateY(100%); }
          to { transform: translateY(0); }
        }
        .animate-slide-up {
          animation: slide-up 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        @keyframes slide-down {
          from { opacity: 0; transform: translateY(-10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-slide-down {
          animation: slide-down 0.2s ease-out;
        }
        @keyframes slide-up-sm {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-slide-up-sm {
           animation: slide-up-sm 0.2s ease-out;
        }
        .no-scrollbar::-webkit-scrollbar { display: none; }
        .no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
      `}</style>
    </div>
  );
};

window.App = App;
