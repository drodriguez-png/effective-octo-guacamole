import { useTheme } from '../contexts/ThemeContext';
import { Dropdown } from './Dropdown';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  const getThemeIcon = () => {
    switch (theme()) {
      case 'light': return '☀️';
      case 'dark': return '🌙';
      case 'system': return '💻';
      default: return '💻';
    }
  };

  const getThemeLabel = () => {
    switch (theme()) {
      case 'light': return 'Light';
      case 'dark': return 'Dark';
      case 'system': return 'System';
      default: return 'System';
    }
  };

  const selectTheme = (newTheme: 'light' | 'dark' | 'system') => {
    setTheme(newTheme);
  };

  const triggerButton = (
    <button
      class="theme-toggle"
      title={`Current theme: ${theme()}`}
      aria-label={`Theme selector (current: ${theme()})`}
    >
      {getThemeIcon()} {getThemeLabel()} ▼
    </button>
  );

  return (
    <Dropdown 
      trigger={triggerButton}
      class="theme-dropdown"
      contentClass="theme-dropdown-content"
      alignRight={true}
    >
      <button 
        class={`theme-dropdown-item ${theme() === 'light' ? 'active' : ''}`}
        onClick={() => selectTheme('light')}
      >
        ☀️ Light
      </button>
      <button 
        class={`theme-dropdown-item ${theme() === 'dark' ? 'active' : ''}`}
        onClick={() => selectTheme('dark')}
      >
        🌙 Dark
      </button>
      <button 
        class={`theme-dropdown-item ${theme() === 'system' ? 'active' : ''}`}
        onClick={() => selectTheme('system')}
      >
        💻 System
      </button>
    </Dropdown>
  );
}