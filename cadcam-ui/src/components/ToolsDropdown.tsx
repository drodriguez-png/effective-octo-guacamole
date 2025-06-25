import { Dropdown } from './Dropdown';

export function ToolsDropdown() {
  const triggerButton = (
    <button class="dropdown-toggle">
      ⚒️ Tools ▼
    </button>
  );

  return (
    <Dropdown 
      trigger={triggerButton}
      class="nav-dropdown"
    >
      <a href="/cds" class="dropdown-item">📦 Code Delivery</a>
      <a href="/part_ops" class="dropdown-item">⚙️ Part Operations</a>
      <a href="/renamed_demand" class="dropdown-item">🔄 Renamed Demand</a>
      <a href="/boomi" class="dropdown-item">🔗 Boomi</a>
    </Dropdown>
  );
}