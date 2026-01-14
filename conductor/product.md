# Initial Concept
The user wants to build TyreVibes, an iOS application for automated vehicle maintenance tracking and tire analysis using LiDAR, CoreML, and local AI assistance.

# Product Definition - TyreVibes

## Target Users
- Individual car owners looking for automated maintenance tracking.

## Goals
- Provide accurate tire tread depth analysis using LiDAR and computer vision.

## Key Features
- LiDAR-based tread depth measurement (for supported devices).
- Computer vision (CoreML) for license plate and tire sidewall recognition.
- Manual data entry for users without advanced hardware support.
- Historical tracking of tire wear with predictive replacement alerts.

## AI Assistant Capabilities
- Provide real-time answers to vehicle maintenance questions based on user data.
- Proactively notify the user about upcoming deadlines and recommended actions.
- Act as a voice-controlled interface for hands-free vehicle check-ins.
- Use local RAG (Retrieval-Augmented Generation) to analyze car manuals and service history.

## Data Privacy & Processing
- **Privacy-first:** All AI processing and tire analysis happen locally on the device.
- **Hybrid:** Local processing for privacy, cloud sync for cross-device access and backup (via Supabase).
