import '../models/location_details.dart';

class LocationDataService {
  LocationDataService._();

  static final LocationDataService instance = LocationDataService._();

  // NOTE: This is a Dart mirror of a subset of LOCATION_DATABASE from locations.js.
  // Add more entries as needed to keep it in sync with the web data.
  final Map<String, LocationDetails> _locationsById = {
    'mtl-mount-royal': LocationDetails(
      id: 'mtl-mount-royal',
      name: 'Mount Royal Park',
      rating: 4.9,
      reviews: '45,000',
      price: 'Free',
      category: 'Park',
      address: 'Mount Royal',
      openStatus: 'Open',
      closeTime: '11 PM',
      phone: null,
      website: null,
      description:
          'Iconic mountain park offering panoramic views of the city, walking trails, and the famous cross.',
      hours: [
        DayHours(day: 'Monday', time: '6:00 AM – 11:00 PM'),
        DayHours(day: 'Tuesday', time: '6:00 AM – 11:00 PM'),
        DayHours(day: 'Wednesday', time: '6:00 AM – 11:00 PM'),
        DayHours(day: 'Thursday', time: '6:00 AM – 11:00 PM'),
        DayHours(day: 'Friday', time: '6:00 AM – 11:00 PM'),
        DayHours(day: 'Saturday', time: '6:00 AM – 11:00 PM'),
        DayHours(day: 'Sunday', time: '6:00 AM – 11:00 PM'),
      ],
    ),
    'mtl-schwartz': LocationDetails(
      id: 'mtl-schwartz',
      name: "Schwartz's Deli",
      rating: 4.6,
      reviews: '18,421',
      price: r'$$',
      category: 'Deli',
      address: '3895 St Laurent Blvd',
      openStatus: 'Open',
      closeTime: '11 PM',
      phone: '(514) 842-4813',
      website: 'https://schwartzsrestaurant.com',
      description: 'The institution. Smoked meat, cherry coke, pickles.',
      hours: [
        DayHours(day: 'Monday', time: '11:00 AM – 11:00 PM'),
        DayHours(day: 'Tuesday', time: '11:00 AM – 11:00 PM'),
        DayHours(day: 'Wednesday', time: '11:00 AM – 11:00 PM'),
        DayHours(day: 'Thursday', time: '11:00 AM – 11:00 PM'),
        DayHours(day: 'Friday', time: '11:00 AM – 11:00 PM'),
        DayHours(day: 'Saturday', time: '11:00 AM – 11:00 PM'),
        DayHours(day: 'Sunday', time: '11:00 AM – 11:00 PM'),
      ],
    ),
    // Add more entries here mirroring locations.js if needed.
  };

  LocationDetails? getLocationById(String id) => _locationsById[id];
}

