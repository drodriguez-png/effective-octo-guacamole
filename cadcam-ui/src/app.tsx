import { MetaProvider, Title } from "@solidjs/meta";
import { Router, useLocation } from "@solidjs/router";
import { FileRoutes } from "@solidjs/start/router";
import { Suspense } from "solid-js";
import "./app.css";
import "./styles/AppLayout.css";
import "./styles/themes.css";
import "./components/Dropdown.css";
import { ThemeProvider } from "./contexts/ThemeContext";
import { ThemeToggle } from "./components/ThemeToggle";
import { ToolsDropdown } from "./components/ToolsDropdown";

function RootLayout(props) {
  const location = useLocation();

  return (
    <MetaProvider>
      <Title>SolidStart - Basic</Title>
      <div class="app-container">
        <nav class="app-nav">
          <div class="nav-left">
            {location.pathname !== '/' && <a href="/" class="nav-link">🏠</a>}
            <ToolsDropdown />
          </div>
          <div class="nav-right">
            <ThemeToggle />
          </div>
        </nav>
        <main class="app-main">
          <Suspense>{props.children}</Suspense>
        </main>
        <footer class="app-footer">
          <p class="footer-text">
            © {new Date().getFullYear()} High Steel Structures LLC. All rights reserved.
          </p>
        </footer>
      </div>
    </MetaProvider>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <Router root={RootLayout}>
        <FileRoutes />
      </Router>
    </ThemeProvider>
  );
}
