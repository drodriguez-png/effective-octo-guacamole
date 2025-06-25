# CAD/CAM UI

A SolidStart web application for the SigmaNest interface system, providing user interfaces for CAD/CAM operations and code delivery management.

## Project Overview

This application is built with SolidJS and SolidStart, featuring:

- **Home Page**: Main landing page with interactive counter component
- **Code Delivery System**: Interface for managing code delivery operations
- **Responsive Design**: CSS-based styling with component-level styles

## Tech Stack

- **Framework**: SolidJS with SolidStart
- **Router**: @solidjs/router for client-side routing
- **Meta Management**: @solidjs/meta for SEO and document head management
- **Build Tool**: Vinxi
- **Runtime**: Node.js 22+

## Project Structure

```
src/
├── app.tsx          # Root application component with routing
├── app.css          # Global application styles
├── components/      # Reusable UI components
│   ├── Counter.tsx  # Interactive counter component
│   └── Counter.css  # Counter component styles
├── routes/          # Page components
│   ├── index.tsx    # Home page
│   ├── cds.tsx      # Code Delivery System page
│   └── [...404].tsx # 404 error page
└── entry-*.tsx      # Application entry points
```

## Getting Started

### Prerequisites

- Node.js 22 or higher
- bun or other js toolchain

### Installation

```bash
# Install dependencies
bun install
```

### Development

```bash
# Start development server
bun run dev

# Start with auto-open browser
bun run dev -- --open
```

The application will be available at `http://localhost:3000`

### Building

```bash
# Build for production
bun run build

# Start production server
bun start
```

## Available Routes

- `/` - Home page with welcome message and counter
- `/cds` - Code Delivery System interface
- `/*` - 404 error page for unmatched routes

## Scripts

- `bun run dev` - Start development server
- `bun run build` - Build for production
- `bun run start` - Start production server
- `bun run version` - Show version information
