# SmartServe-KolejCare

A comprehensive Flutter mobile application for managing residential college facilities, maintenance requests, and student services. SmartServe streamlines the complaint reporting process, technician assignment, and repair tracking for college dormitories.

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Architecture](#architecture)
- [Support & Help](#support--help)
- [License](#license)

## Overview

SmartServe-KolejCare is a multi-role platform designed to facilitate seamless communication between students, staff, and technicians in residential college environments. The application enables students to report maintenance issues, staff to manage and assign tasks, and technicians to efficiently schedule and complete repairs.

**Key Users:**
- **Students** - Report damage, track repairs, provide feedback
- **Staff/Administrators** - Review complaints, assign technicians, manage operations
- **Technicians** - Accept tasks, schedule work, document completion

## Key Features

### For Students
- 📝 **Submit Complaints** - Report room/facility damage with photos, location data, and detailed descriptions
- 🎯 **AI-Powered Urgency Detection** - Machine learning model analyzes damage severity and categorizes urgency levels
- 📍 **Location Services** - Integrated maps with GPS coordinates for precise damage location
- 📱 **Real-Time Tracking** - Monitor complaint status from submission to completion
- 🔔 **Instant Notifications** - Get alerts on task assignment, technician arrival, and completion
- 💬 **AI Chatbot Support** - Ask questions and get instant help powered by Google Generative AI
- 📊 **Dashboard** - View complaint progress and residential college announcements

### For Staff
- 📋 **Complaint Management** - View, filter, and manage all complaints with advanced search
- 👥 **Technician Assignment** - Intelligent assignment system considering technician availability and schedules
- 📈 **Analytics Dashboard** - Monitor complaint trends, resolution times, and team performance
- ⚙️ **Settings** - Configure system preferences and user permissions

### For Technicians
- 📅 **Task Scheduling** - Accept/reject assigned tasks and manage work schedule
- 📸 **Work Documentation** - Upload completion proof and document repair details
- ❌ **Rejection Management** - Report when repair cannot be completed with proof images
- 🗺️ **Route Optimization** - View assigned locations and optimize repair routes

### General
- 🔐 **Firebase Authentication** - Secure Google Sign-In and email-based authentication
- 💳 **Payment Integration** - Stripe payment processing for service fees
- 🌐 **Multi-Platform** - Runs on Android, iOS, Web, Windows, macOS, and Linux
- 🎨 **Material Design 3** - Modern, accessible user interface

## Technology Stack

| Category | Technologies |
|----------|--------------|
| **Frontend** | Flutter, Material Design 3 |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **Real-time Communication** | Socket.io, WebRTC |
| **Maps & Location** | Google Maps, Geolocator, OSRM |
| **AI/ML** | TFLite (damage urgency detection), Google Generative AI (chatbot) |
| **Payments** | Stripe |
| **File Management** | Image compression, PDF generation, Printing |
| **State Management** | Provider/StreamBuilder |
| **Environment** | Dart 3.9.2+, Flutter |

## Prerequisites

Before setting up the project, ensure you have:

- **Flutter SDK** (3.9.2 or higher)
- **Dart SDK** (included with Flutter)
- **Android Studio** (for Android development) or **Xcode** (for iOS)
- **Firebase Project** with enabled services:
  - Authentication (Google, Email/Password)
  - Cloud Firestore
  - Storage
- **API Keys**:
  - [Google Maps API](https://console.cloud.google.com/)
  - [Google Generative AI API](https://ai.google.dev/)
  - [Stripe API](https://dashboard.stripe.com/) (Publishable & Secret keys)
- **Git** for version control

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/SmartServe-KolejCare.git
cd SmartServe-KolejCare
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Create a `.env` file in the project root with required API keys:

```env
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key
GOOGLE_GENERATIVE_AI_KEY=your_google_ai_api_key
```

Add `.env` to assets in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - .env
```

### 4. Set Up Firebase

1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` directory
3. Update `lib/firebase_options.dart` with your Firebase configuration

```bash
flutterfire configure
```

### 5. Run the Application

```bash
# Development
flutter run

# Production build
flutter build apk
flutter build ios
flutter build web
```

### Example Usage

#### Reporting a Complaint (Student)

```dart
// Navigate to complaint form
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ComplaintFormScreen(),
  ),
);
```

The form includes:
- Maintenance type selection (Furniture, Electrical, Plumbing, etc.)
- Photo upload with AI damage analysis
- Location selection with GPS coordinates
- Urgency level prediction
- Room entry consent checkbox

#### Assigning a Technician (Staff)

```dart
// Staff dashboard shows pending complaints
// Click to assign technician using intelligent scheduling
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AssignTechnicianPage(
      complaintId: complaintId,
      complaint: complaintData,
    ),
  ),
);
```

System considers:
- Technician availability
- Distance from complaint location
- Current workload
- Skill set requirements

## Project Structure

```
lib/
├── main.dart                 # App entry point & Stripe initialization
├── app.dart                  # Material app configuration
├── auth_gate.dart           # Authentication routing
├── firebase_options.dart    # Firebase configuration
│
├── student/                 # Student module
│   ├── home_page.dart       # Dashboard & complaint status
│   ├── complaint_form_screen.dart     # New complaint form with AI analysis
│   ├── complaint_detail_screen.dart   # View complaint details
│   ├── notification_page.dart         # Real-time notifications
│   ├── chatbot_screen.dart           # AI chatbot support
│   ├── profile.dart                  # User profile management
│   └── screens/
│       ├── activity.dart              # Complaint activity tracking
│       └── activity/                  # Status-specific screens
│
├── staff/                   # Staff management module
│   ├── staff_portal.dart             # Main dashboard
│   ├── staff_complaints.dart         # Complaint management
│   ├── analytics_page.dart           # Performance analytics
│   └── assign_technician.dart        # Scheduling engine
│
├── technician/              # Technician module
│   └── [technician-specific screens]
│
├── models/                  # Data models
│   ├── user_model.dart          # User (Student, Staff, Technician)
│   ├── complaint_model.dart     # Complaint structure
│   ├── location_model.dart      # Location/GPS data
│   └── repair_destination.dart  # Repair location
│
├── services/                # Business logic
│   ├── osrm_service.dart       # Route optimization
│   ├── weatherService.dart     # Weather data
│   └── [other services]
│
├── widgets/                 # Reusable UI components
│   └── location_selection_card.dart
│
└── utils/                   # Utilities & helpers

assets/
└── urgency_model.tflite    # ML model for damage urgency
```

## Architecture

### Data Flow

**Complaint Submission:**
```
User Form Input 
  → AI Damage Analysis (TFLite) 
  → Firestore Storage 
  → Real-time Notification
  → Staff Dashboard Display
```

**Task Assignment:**
```
Staff Selection 
  → Schedule Calculation 
  → Technician Matching 
  → Firestore Update 
  → Notification to Technician
```

**Completion Tracking:**
```
Status Update 
  → Real-time Listener 
  → Student Notification 
  → UI Progress Update
```

### Key Integration Points

- **Firebase**: Centralized data store for all users, complaints, and tasks
- **Google Maps**: Location visualization and route optimization
- **Stripe**: Secure payment processing
- **WebRTC**: Real-time communication capabilities
- **Socket.io**: Event-driven updates for notifications

## Support & Help

### Documentation
- See [FAQs.txt](FAQs.txt) for common questions
- Check [INTEGRATION_EXAMPLES.dart](INTEGRATION_EXAMPLES.dart) for code samples
- Review [COMPLAINT_FORM_INTEGRATION_EXAMPLE.dart](COMPLAINT_FORM_INTEGRATION_EXAMPLE.dart) for form implementation details

### Getting Help

1. **In-App Support**: Use the AI chatbot in the app
2. **Technical Issues**: Check the [Help Page](lib/help_page.dart)
3. **Bug Reports**: Open an issue on GitHub
4. **Feature Requests**: Discuss in GitHub Discussions

### Common Issues

**Build Errors:**
- Run `flutter clean` and `flutter pub get`
- Ensure all required files (.env, google-services.json) are present
- Check Flutter/Dart versions match requirements

**Firebase Connection Issues:**
- Verify `firebase_options.dart` configuration
- Check internet connectivity
- Ensure Firebase project is active and accessible

**API Key Issues:**
- Validate keys in `.env` file
- Check API quotas in respective consoles
- Ensure APIs are enabled in GCP/Firebase

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Last Updated:** January 2026

For more information about specific features or development, refer to the inline documentation in the codebase.
