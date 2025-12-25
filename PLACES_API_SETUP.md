# Google Places API & Maps Integration Setup Guide

## Overview
This document provides step-by-step instructions to set up Google Places API and Google Maps for the enhanced complaint form feature.

---

## 1. API Keys Setup

### Your API Keys (Already in .env)
- **Google Maps API Key**: `AIzaSyD9VorqRxSNNduETSgv1bSz8ck-kDEKEPA`
- **Places API Key**: `AIzaSyAs_kErtfLBnHOPUPxKx2COUtLZJuN44RE`
- **Geocoding API Key**: `AIzaSyACWHp9dL4kdYKprQub-tyy0QFZhyErrh0`

These are loaded via `flutter_dotenv` package. The app reads from `.env` file automatically.

---

## 2. Android Configuration

### Step 1: Add Permissions to AndroidManifest.xml

Location: `android/app/src/main/AndroidManifest.xml`

Add these permissions inside the `<manifest>` tag (before `<application>`):

```xml
<!-- Location Permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Internet Permission -->
<uses-permission android:name="android.permission.INTERNET" />
```

### Step 2: Add Google Maps API Key to AndroidManifest.xml

Add this inside the `<application>` tag:

```xml
<application
    ...>
    <!-- Google Maps API Key -->
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="AIzaSyD9VorqRxSNNduETSgv1bSz8ck-kDEKEPA" />
    
    <!-- Activity declarations -->
    ...
</application>
```

### Step 3: Update build.gradle (app level)

Location: `android/app/build.gradle.kts`

Ensure these are in the dependencies:

```gradle
dependencies {
    // Google Maps
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    
    // Google Play Services
    implementation("com.google.android.gms:play-services-location:21.1.0")
}
```

### Step 4: Run on Android Device

```bash
flutter clean
flutter pub get
flutter run -d <device_id>
```

Enable location permissions when prompted.

---

## 3. iOS Configuration

### Step 1: Add Permissions to Info.plist

Location: `ios/Runner/Info.plist`

Add these keys:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to help locate damage areas on campus.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to your location to help locate damage areas on campus.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>This app uses local network to communicate with services.</string>

<key>NSBonjourServiceTypes</key>
<array>
    <string>_http._tcp</string>
</array>
```

### Step 2: Update Podfile

Location: `ios/Podfile`

Ensure the platform version is at least iOS 11.0:

```ruby
platform :ios, '11.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',
      ]
    end
  end
end
```

### Step 3: Run pod install

```bash
cd ios
pod install --repo-update
cd ..
```

### Step 4: Run on iOS Device

```bash
flutter clean
flutter pub get
flutter run -d <device_id>
```

---

## 4. Google Cloud Console Setup (For Your Reference)

### Enable Required APIs
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Enable these APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Places API**
   - **Geocoding API**

### API Key Restrictions (Optional but Recommended)
1. Go to **Credentials** → **API Keys**
2. Click your API key
3. Under **Key restrictions**, set:
   - **API restrictions**: Select the three APIs above
   - **Application restrictions**: 
     - For Android: Restrict to Android apps, add your app's package name and certificate fingerprint
     - For iOS: Restrict to iOS apps, add your bundle ID

### Get Android App Signing Certificate
```bash
# Get SHA-1 fingerprint
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

---

## 5. Feature Implementation Details

### How the Features Work

#### Public Area Mode
1. User selects "Public Area" from dropdown
2. Address search field becomes active with autocomplete
3. As user types, Google Places API suggests matching addresses
4. User taps a suggestion
5. App fetches place details (coordinates) from Google Places
6. Google Map displays with marker at selected location
7. User can add additional description in text field

#### Inside My Room Mode
1. User selects "Inside My Room" from dropdown
2. Address field auto-populates with: `{residentCollege} {block} {roomNumber}` from Firestore
3. App geocodes this address to coordinates
4. Google Map displays with marker at room location
5. User can edit the address if needed (tap "Update Location" button)
6. User can add additional description

### Packages Used
- **google_maps_flutter** (v2.8.0): Displays interactive maps
- **http**: Makes HTTP requests to Google APIs
- **flutter_dotenv**: Loads API keys from .env file
- **cloud_firestore**: Fetches student room data
- **firebase_auth**: Authenticates user

### Error Handling
- Invalid addresses: "Address not found" error message
- API failures: Displays user-friendly error with retry option
- No internet: "Error fetching..." messages
- Missing student data: Shows error loading student data message
- Null safety: All nullable values handled properly

---

## 6. Testing on Physical Device

### Android Phone
```bash
# Connect USB device with debugging enabled
adb devices  # List connected devices

flutter run -d <device_id>

# Grant location permissions when app asks
```

### iOS Phone
```bash
# Trust developer certificate on phone:
# Settings → General → VPN & Device Management → Trust [Your Developer Name]

flutter run -d <device_id>

# Grant location permissions when app asks
```

### Test Scenarios
1. **Public Area - Valid Address**: Search for "library" or "cafeteria"
2. **Public Area - Invalid Address**: Search for gibberish text
3. **Inside My Room - Auto-populate**: Should show room details automatically
4. **Room Edit**: Change address and tap "Update Location"
5. **Map Interaction**: Zoom/pan the map to ensure it's interactive
6. **Offline Mode**: Disable internet and test error handling

---

## 7. Firestore Schema (Student Collection)

Expected fields in `student` collection:

```
{
  "uid": "user_id",
  "residentCollege": "College Name",      // e.g., "St. Catherine's College"
  "block": "Block Letter/Number",        // e.g., "A", "Block 1"
  "roomNumber": "Room Number",           // e.g., "201", "A-205"
  "email": "student@email.com",
  ... other fields
}
```

---

## 8. Common Issues & Solutions

### Issue: Maps won't display
**Solution**: Verify API key is correctly set in both Android and iOS configurations

### Issue: "Access denied" error from Places API
**Solution**: Check API key restrictions in Google Cloud Console

### Issue: Autocomplete not working
**Solution**: Ensure internet is connected and API key is valid

### Issue: Location permissions denied
**Solution**: 
- Android: Check AndroidManifest.xml permissions
- iOS: Check Info.plist keys
- Grant permissions when app prompts

### Issue: "Student record not found"
**Solution**: Ensure current user has a document in Firestore `student` collection with required fields

---

## 9. Code Structure

### New Files Created
- **`lib/services/places_service.dart`**: Handles all Places API calls
  - `getAutocompletePredictions()`: Get address suggestions
  - `getPlaceDetails()`: Get coordinates from place ID
  - `geocodeAddress()`: Convert address string to coordinates

- **`lib/widgets/location_picker_widget.dart`**: Main UI widget for location selection
  - Handles both Public Area and Room modes
  - Displays Google Map with markers
  - Manages address search and selection
  - Integrates description field

### Modified Files
- **`lib/student/complaint_form_screen.dart`**: Enhanced complaint form
  - Added location data state variables
  - Added student data fetching
  - Integrated LocationPickerWidget
  - Updated form submission with location data

---

## 10. Next Steps

1. Run `flutter pub get` to fetch dependencies
2. Build and run on your physical device
3. Test both "Public Area" and "Inside My Room" scenarios
4. Verify map displays and markers appear correctly
5. Test address editing in room mode
6. Monitor API usage in Google Cloud Console

---

## Support & Documentation

- [Google Maps Flutter Documentation](https://pub.dev/packages/google_maps_flutter)
- [Google Places API Documentation](https://developers.google.com/maps/documentation/places/web-service/overview)
- [Google Geocoding API Documentation](https://developers.google.com/maps/documentation/geocoding)
- [Flutter Documentation](https://flutter.dev/docs)

---

Last Updated: December 25, 2025
