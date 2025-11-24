import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String apiKey = '2fbf84e90dda3dc3f9fbf9a1520de49a';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // Get weather by city name
  Future<WeatherData?> getWeatherByCity(String cityName) async {
    try {
      final url = Uri.parse(
        '$baseUrl?q=$cityName&appid=$apiKey&units=metric'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherData.fromJson(data);
      } else {
        print('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  // Get weather by coordinates (latitude, longitude)
  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$baseUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherData.fromJson(data);
      } else {
        print('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }
}

// Weather Data Model
class WeatherData {
  final String cityName;
  final double temperature;
  final String description;
  final String mainCondition;
  final int humidity;
  final double windSpeed;
  final String icon;

  WeatherData({
    required this.cityName,
    required this.temperature,
    required this.description,
    required this.mainCondition,
    required this.humidity,
    required this.windSpeed,
    required this.icon,
  });

  // Create from JSON
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['name'],
      temperature: json['main']['temp'].toDouble(),
      description: json['weather'][0]['description'],
      mainCondition: json['weather'][0]['main'],
      humidity: json['main']['humidity'],
      windSpeed: json['wind']['speed'].toDouble(),
      icon: json['weather'][0]['icon'],
    );
  }

  // Get weather icon URL
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}