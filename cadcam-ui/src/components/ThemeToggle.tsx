import { useTheme } from '../contexts/ThemeContext';

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

  const cycleTheme = () => {
    const modes = ['light', 'dark', 'system'] as const;
    const currentIndex = modes.indexOf(theme());
    const nextIndex = (currentIndex + 1) % modes.length;
    setTheme(modes[nextIndex]);
  };

  return (
    <button
      onClick={cycleTheme}
      class="theme-toggle"
      title={`Current theme: ${theme()}`}
      aria-label={`Switch theme (current: ${theme()})`}
    >
      {getThemeIcon()}
    </button>
  );
}