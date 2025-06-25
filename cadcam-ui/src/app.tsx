import { MetaProvider, Title } from "@solidjs/meta";
import { Router, useLocation } from "@solidjs/router";
import { FileRoutes } from "@solidjs/start/router";
import { Suspense, createSignal } from "solid-js";
import "./app.css";
import "./styles/AppLayout.css";

function RootLayout(props) {
  const [isDropdownOpen, setIsDropdownOpen] = createSignal(false);
  const location = useLocation();

  const toggleDropdown = () => {
    setIsDropdownOpen(!isDropdownOpen());
  };

  const closeDropdown = () => {
    setIsDropdownOpen(false);
  };

  return (
    <MetaProvider>
      <Title>SolidStart - Basic</Title>
      <div class="app-container" onClick={closeDropdown}>
        <nav class="app-nav">
          {location.pathname !== '/' && <a href="/" class="nav-link">🏠</a>}
          <div class="nav-dropdown">
            <button 
              class="dropdown-toggle" 
              onClick={(e) => {
                e.stopPropagation();
                toggleDropdown();
              }}
            >
              ⚒️ Tools ▼
            </button>
            <div class={`dropdown-content ${isDropdownOpen() ? 'show' : ''}`}>
              <a href="/cds" class="dropdown-item" onClick={closeDropdown}>📦 Code Delivery</a>
              <a href="/part_ops" class="dropdown-item" onClick={closeDropdown}>⚙️ Part Operations</a>
              <a href="/renamed_demand" class="dropdown-item" onClick={closeDropdown}>🔄 Renamed Demand</a>
              <a href="/boomi" class="dropdown-item" onClick={closeDropdown}>🔗 Boomi</a>
            </div>
          </div>
          <a href="/fail" class="nav-link">Test</a>
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
    <Router root={RootLayout}>
      <FileRoutes />
    </Router>
  );
}
