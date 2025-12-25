# Quick Start Testing Guide

## Pre-Testing Checklist

1. ✅ Flutter version 3.x installed
2. ✅ Physical Android/iOS device connected
3. ✅ Location permissions enabled in device settings
4. ✅ Internet connection active
5. ✅ All files created/modified properly

---

## Build & Run Commands

### Clean Build
```bash
cd d:\SmartServe-KolejCare
flutter clean
flutter pub get
```

### Run on Device
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run in release mode (recommended for performance testing)
flutter run -d <device_id> --release
```

---

## Test Scenario 1: Public Area Search

### Setup
- Launch app and navigate to complaint form
- Select **"Public Area"** from location dropdown

### Test Steps
1. **Type Address**
   - Click address search field
   - Type: "library"
   - Wait ~500ms for suggestions
   - **Expected**: 5 suggestions appear (e.g., "Main Library", "Science Building", etc.)

2. **Invalid Address**
   - Clear field
   - Type: "xyzabc123invalid"
   - Wait 500ms
   - **Expected**: No suggestions appear or "Address not found"

3. **Select Suggestion**
   - Clear field
   - Type: "hospital"
   - Tap first suggestion
   - **Expected**: 
     - Full address populates in field
     - Map appears with marker
     - Marker is centered on selected location
     - Map is interactive (can zoom/pan)

4. **Edit & Reselect**
   - Clear field
   - Type different location
   - Select new suggestion
   - **Expected**: Map updates with new marker location

---

## Test Scenario 2: Room Location (Auto-Populate)

### Setup
- Launch app and navigate to complaint form
- Select **"Inside My Room"** from location dropdown

### Test Steps
1. **Auto-Population**
   - Wait for loading to complete
   - **Expected**: 
     - Address field shows: "{College Name}, {Block}, {Room#}"
     - Map appears automatically
     - Marker shows room location

2. **Edit Room Address**
   - Ensure student data loaded (no error message)
   - Address field shows your room location
   - Clear field and type new location
   - Tap **"Update Location"** button
   - **Expected**: 
     - Loading spinner appears
     - Map updates to new location
     - Marker moves to new position

3. **Switch Back to Public**
   - Select "Public Area" from dropdown
   - **Expected**: 
     - Address field clears
     - Previous map clears
     - "Public Area" mode begins fresh

4. **Switch Back to Room**
   - Select "Inside My Room" again
   - **Expected**: 
     - Room address re-populates automatically
     - Map re-appears with marker

---

## Test Scenario 3: Error Handling

### Test Steps
1. **Disable Internet**
   - Enable airplane mode on device
   - Try to search address
   - **Expected**: Error message appears (e.g., "Error fetching autocomplete")

2. **Invalid API Key** (Manual Test)
   - Edit `.env` file with fake API key
   - Rebuild app
   - Try to search address
   - **Expected**: "Places API access denied" message

3. **Firestore Error** (Missing Student Data)
   - This only shows if student document missing from Firestore
   - **Expected**: "Error loading student data" message in room mode

4. **Enable Internet & Retry**
   - Disable airplane mode
   - App should work normally again

---

## Test Scenario 4: Form Submission

### Public Area Submission
1. Fill all fields:
   - Maintenance type: Select any
   - Title: Enter some text
   - Description: Enter some text
   - Location: **Public Area**
   - Address: Search and select location
   - Location description: Optional
   - Urgency: Select any
   - Consent: Yes
   - Images: Optional

2. Tap **"Submit Complaint"**

3. **Expected**:
   - Success dialog appears
   - Data saved to Firestore with coordinates
   - Check Firestore:
     ```
     complaint/{docId} {
       damageLocation: "Selected address",
       damageLocationLatitude: 50.7345,
       damageLocationLongitude: -3.5321,
       damageLocationDescription: "Your notes",
       damageLocationType: "public"
     }
     ```

### Room Submission
1. Fill all fields same as above but:
   - Location: **Inside My Room**
   - Address: Auto-populated (no manual entry needed)
   - Can optionally edit address

2. Tap **"Submit Complaint"**

3. **Expected**:
   - Success dialog appears
   - Data saved with room location coordinates
   - Check Firestore for `damageLocationType: "room"`

---

## Test Scenario 5: UI/UX Checks

### Address Input Field
- [ ] Placeholder text shows for each mode
- [ ] Typing doesn't cause freezes
- [ ] Autocomplete dropdown appears and disappears properly
- [ ] Predictions scrollable if too many
- [ ] Selected prediction displays in field

### Map Display
- [ ] Map loads without crashes
- [ ] Marker visible and correctly positioned
- [ ] Map info window shows address
- [ ] Can zoom (pinch or buttons)
- [ ] Can pan (drag)
- [ ] Map stops loading indicator when ready

### Description Field
- [ ] Text input works
- [ ] Can be empty (optional)
- [ ] Multiline support (multiple lines of text)
- [ ] Placeholder text visible
- [ ] Saved correctly in Firestore

### Loading States
- [ ] Student data: Shows spinner while loading
- [ ] Address search: Shows spinner while fetching predictions
- [ ] Location: Shows spinner while getting coordinates
- [ ] All spinners are subtle and don't obstruct content

### Error Messages
- [ ] Error messages are clear and readable
- [ ] Error messages don't crash app
- [ ] Can retry after error
- [ ] Error colors use red (#FF6B6B or similar)

---

## Performance Metrics

### Monitor These During Testing
1. **API Response Time**: Autocomplete should appear within ~700ms
2. **Map Load Time**: Map should display within ~2 seconds
3. **Location Update**: Switching locations should update map within ~1 second
4. **Memory**: App shouldn't use >200MB RAM
5. **Battery**: Extensive map usage shouldn't drain >10% battery per hour

### Check in Logcat/Device Logs
```bash
# Watch logs
flutter logs

# Filter for errors
flutter logs | findstr "error\|Error\|Places API"
```

---

## Mobile Device Tips

### Android
- Grant location permissions when prompted
- Allow app to access location "While using app"
- Enable GPS for more accurate location
- Test on Android 10+ for best compatibility

### iOS
- Trust your developer certificate (Settings → General → VPN & Device Management)
- Grant location permissions
- Enable GPS
- Ensure device has cellular/WiFi for location services
- Test on iOS 11+ for best compatibility

---

## Expected Behavior Checklist

### Autocomplete
- [x] First 500ms of typing: No API calls (debounced)
- [x] After 500ms silence: API called
- [x] Results appear within 1-2 seconds
- [x] Results update as user types more
- [x] Clear field clears predictions

### Map
- [x] Only shows after address selected
- [x] Marker at correct coordinates
- [x] Map centered on marker (zoom 17)
- [x] Info window shows address
- [x] Zoom/pan works smoothly
- [x] Updates when new address selected

### Room Mode
- [x] Auto-fills on first load
- [x] Shows loading spinner while fetching student data
- [x] Error if student data not found
- [x] Can edit address with "Update Location" button
- [x] Edit button only visible in room mode

### Form Validation
- [x] Cannot submit without location selected
- [x] All location data saved to Firestore
- [x] Coordinates properly stored as numbers
- [x] Location type ('room' or 'public') tracked
- [x] Description is optional but stored

---

## Debugging Tips

### View Firestore Data
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Firestore Database
4. Navigate to `complaint` collection
5. Open latest document
6. Check `damageLocation`, `damageLocationLatitude`, `damageLocationLongitude`

### Enable Verbose Logging
```bash
flutter run -v

# Check for Places API messages
```

### Check API Quota Usage
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to "APIs & Services" → "Quotas"
4. Check usage for:
   - Places API
   - Maps JavaScript API
   - Geocoding API

---

## Common Test Issues & Solutions

### Issue: Autocomplete not appearing
**Check**:
- Is PLACES_API_KEY set in .env?
- Is internet connected?
- Did you wait 500ms after typing?
- Check logs for "Error fetching autocomplete"

### Issue: Map won't load
**Check**:
- Is Google Maps API key in AndroidManifest/Info.plist?
- Is internet connected?
- Check logs for "Maps" errors
- Try rebuilding with `flutter clean`

### Issue: Student data not loading
**Check**:
- Is user logged in?
- Does user have document in Firestore `student` collection?
- Does document have `residentCollege`, `block`, `roomNumber` fields?

### Issue: App crashes when selecting address
**Check**:
- Check logs for exception details
- Try `flutter clean && flutter pub get`
- Rebuild and run again

---

## Success Criteria

✅ **Testing is successful if:**
1. Autocomplete suggestions appear when typing address
2. Can select suggestion and map displays with marker
3. Room mode auto-populates address correctly
4. Can edit room address and map updates
5. Error messages display for invalid inputs
6. Form can be submitted with location data
7. Firestore contains correct coordinates
8. All UI elements responsive and no crashes

---

## Quick Run Commands

```bash
# Full clean & rebuild
flutter clean && flutter pub get && flutter run -d <device_id>

# Just run (after first build)
flutter run -d <device_id>

# Check for errors
flutter analyze

# Format code
dart format lib/

# View logs
flutter logs

# Run with verbose output
flutter run -v
```

---

**Happy Testing!** 🚀

For issues or questions, check `PLACES_API_SETUP.md` or `PLACES_API_IMPLEMENTATION.md`

Last Updated: December 25, 2025
