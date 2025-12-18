# CSS Placeholder Map Integration Plan

## Overview
This document outlines the integration of a CSS-based placeholder map widget into the HomePage. This placeholder will later be replaced with Google Maps SDK integration.

## Implementation Summary

### Files Created/Modified

1. **Created**: `lib/widgets/css_map_widget.dart`
   - Reusable widget containing the CSS-based placeholder map
   - Includes `MapLocation` model class for location data
   - Contains dummy locations (Central Park, The Local Spot, Home)
   - Features animated bouncing markers
   - Simulates map tiles with grid pattern, roads, and park areas

2. **Modified**: `lib/pages/home_page.dart`
   - Replaced body content with `CssMapWidget`
   - AppBar remains at top displaying "FriendMap Home"
   - NavBar remains at bottom
   - Map widget fills the space between AppBar and NavBar

### Architecture
```
HomePage (Scaffold)
├── AppBar: "FriendMap Home" (Top)
├── Body: CssMapWidget (Full screen map placeholder)
└── BottomNavigationBar: NavBar (Bottom)
```

### Widget Structure
`CssMapWidget` uses:
- **Stack** for layering (background map + markers + home indicator)
- **CustomPaint** for grid pattern simulation
- **Positioned** widgets for roads and park areas
- **AnimatedBuilder** with AnimationController for marker bouncing
- **MapLocation** model class for location data structure

### Location Data Model
```dart
class MapLocation {
  final int id;
  final double xPercent;  // 0.0 to 1.0
  final double yPercent;  // 0.0 to 1.0
  final String name;
  final String type;
}
```
This model can be reused when integrating Google Maps (convert percentages to Lat/Lng coordinates).

## Future Integration with Google Maps

### Migration Strategy
1. **Replace Widget**: Swap `CssMapWidget` with a `GoogleMapWidget` or similar
2. **Convert Coordinates**: Transform `MapLocation` percentages to actual Lat/Lng
3. **Use Google Maps Markers**: Replace custom marker widgets with `google_maps_flutter` markers
4. **Preserve Location Data**: The `MapLocation` model structure can remain, just add Lat/Lng fields

### Dependencies Already Available
The project already includes `google_maps_flutter: ^2.7.0` in `pubspec.yaml`, so no additional dependencies are needed for future integration.

## Testing
- Verify map displays correctly on HomePage
- Ensure AppBar and NavBar remain visible and functional
- Test marker animations work smoothly
- Verify responsive behavior on different screen sizes

## Notes
- The widget is designed to be self-contained and easily replaceable
- Location data structure is intentionally simple for easy migration
- Animation timing (2.5s) matches the original React component
- All styling colors match the original design specification
