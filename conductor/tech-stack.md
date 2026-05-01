# Technology Stack - TyreVibes

## Frontend (iOS)
- **Framework:** SwiftUI
- **Language:** Swift
- **Capabilities:** CoreML (Computer Vision), LiDAR API, ARKit, BackgroundTasks

## Backend (Hybrid)
- **Primary API:** Node.js with Express.js (Hosted on Namecheap)
- **Edge Computing:** Supabase Edge Functions (TypeScript)
- **Authentication:** Supabase Auth (JWT)

## Database
- **Core Storage:** MySQL (Hosted on Namecheap) - Handles high-volume data, vehicle details, and image metadata.
- **Serverless/Auth:** Supabase (PostgreSQL) - Handles user authentication and edge function triggers.

## AI & Machine Learning
- **On-Device Vision:** CoreML for license plate and tire recognition.

## Infrastructure & Tools
- **Image Processing:** Sharp (Node.js) for adaptive image compression.
- **Database Management:** Supabase CLI, MySQL2.
