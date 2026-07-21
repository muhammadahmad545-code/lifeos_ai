# Architecture Guide

LIFEOS AI uses a feature-first Clean Architecture layout.

## Layers

- Presentation: screens, widgets, controllers, view models
- Domain: entities, repository contracts, use cases
- Data: repository implementations, local sources, remote sources, DTOs

## Shared Core

- App bootstrap and routing live under `lib/app`
- Cross-cutting concerns live under `lib/core`
- Reusable UI primitives live under `lib/shared`

## Data Strategy

- Drift stores structured offline-first data locally
- Hive stores lightweight preferences and cache state
- Firebase services provide authentication, sync, notifications, analytics, storage, and crash reporting
