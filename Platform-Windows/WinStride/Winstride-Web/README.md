# WinStride Web

React-based dashboard frontend for WinStride. Connects to the WinStride API to visualize security events, network connections, process trees, and more.

## Development

```bash
npm install
npm run dev
```

The dev server starts at `http://localhost:5173` and proxies API requests to `http://localhost:5090`.

## Build

```bash
npm run build
```

Output goes to `dist/`. Serve with any static file server.

## Module Structure

Each dashboard module lives in `src/modules/` and follows the same pattern:

```
modules/<name>/
├── <Name>Dashboard.tsx    # Main entry component
├── dashboard/             # Metric cards, charts
├── graph/                 # Visualization (if applicable)
├── list/                  # Event list views
├── timeline/              # Timeline views (if applicable)
└── shared/                # Types, utilities, hooks
```

## Key Dependencies

- **React 19** + **React Router** — UI framework and routing
- **TanStack React Query** — Server state management and caching
- **Cytoscape.js** — Interactive graph visualization (logon networks, process trees)
- **Recharts** — Charts and timeline visualizations
- **Tailwind CSS 4** — Utility-first styling
