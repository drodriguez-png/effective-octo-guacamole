# CAD/CAM Interface System

A modern web interface for the SAP-Sigmanest integration system, built with SolidJS and SolidStart.

## Overview

This application provides a user-friendly interface for managing and monitoring various CAD/CAM operations and integrations between SAP and Sigmanest systems. It features a modular design with dedicated sections for different operational areas.

## Features

- **Code Delivery System**: Manage code delivery operations
- **Part Operations**: Handle part-related operations and workflows  
- **Renamed Demand**: Process demand renaming operations
- **Boomi Integration**: Interface for Boomi integration functionality
- **Theme Support**: Toggle between light, dark, and system themes
- **Responsive Design**: Modern, mobile-friendly interface
- **Component-based Architecture**: Reusable UI components and organized code structure

## Tech Stack

- **Framework**: SolidJS with SolidStart
- **Build Tool**: Vinxi
- **Styling**: CSS with custom themes
- **Router**: SolidJS Router
- **Meta Management**: SolidJS Meta

## Getting Started

### Prerequisites

- Node.js ≥ 22.0.0

### Installation

```bash
# Install dependencies
bun install
# or
npm install
```

### Development

```bash
# Start development server
bun run dev
```

The application will be available at `http://localhost:3000`

### Build

```bash
# Build for production
bun run build
```

### Production

```bash
# Start production server
bun run start
```

## Project Structure

```
src/
├── components/          # Reusable UI components
│   ├── Counter.tsx      # Example counter component
│   ├── Dropdown.tsx     # Generic dropdown component
│   ├── ThemeToggle.tsx  # Theme switching component
│   └── ToolsDropdown.tsx # Navigation tools dropdown
├── contexts/            # State management contexts
│   └── ThemeContext.tsx # Theme management context
├── routes/              # Application pages/routes
│   ├── index.tsx        # Home page with module selection
│   ├── boomi.tsx        # Boomi integration page
│   ├── cds.tsx          # Code delivery system page
│   ├── part_ops.tsx     # Part operations page
│   └── renamed_demand.tsx # Renamed demand page
├── styles/              # CSS stylesheets
│   ├── AppLayout.css    # Main application layout
│   ├── Dropdown.css     # Dropdown component styles
│   ├── PageLayout.css   # Page-specific layouts
│   └── themes.css       # Theme definitions
├── app.tsx              # Main application component
└── app.css              # Global styles
```

## Available Scripts

- `bun run dev` - Start development server with hot reload
- `bun run build` - Build the application for production
- `bun run start` - Start the production server
- `bun run version` - Display Vinxi version information

## Theme System

The application includes a comprehensive theme system supporting:
- **Light Theme**: Standard light color scheme
- **Dark Theme**: Dark color scheme for reduced eye strain
- **System Theme**: Automatically follows system preference

Themes can be switched using the theme toggle in the navigation bar.

## Contributing

This is an internal system for High Steel Structures LLC. Development follows the established patterns and conventions within the codebase.

## License

© 2025 High Steel Structures LLC. All rights reserved.
