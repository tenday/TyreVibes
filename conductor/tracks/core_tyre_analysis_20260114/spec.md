# Specification - Initialize Core Tyre Analysis and Data Persistence Layer

## Context
TyreVibes needs a robust foundation for tire tread analysis and data persistence. This track focuses on setting up the core data models, the bridge to the MySQL/Supabase backend, and the initial LiDAR/CoreML integration infrastructure.

## Requirements
- Define core data models for `Vehicle`, `Tyre`, and `TyreAnalysis`.
- Implement `DataPersistenceService` to handle local and remote synchronization (MySQL/Supabase).
- Set up the `TreadDepthAnalyzer` base class with LiDAR and CoreML placeholders.
- Ensure type safety and comprehensive unit testing for all services.
- Integrate with existing `server.js` endpoints.

## Success Criteria
- Data models correctly represent the domain.
- `DataPersistenceService` can save and retrieve data from the backend.
- `TreadDepthAnalyzer` successfully interfaces with system APIs (LiDAR/CoreML).
- Unit test coverage > 80% for new components.
