import { createContext, createSignal, useContext, onMount, ParentComponent } from 'solid-js';

export type ThemeMode = 'light' | 'dark' | 'system';
export type ResolvedTheme = 'light' | 'dark';

interface ThemeContextType {
  theme: () => ThemeMode;
  resolvedTheme: () => ResolvedTheme;
  setTheme: (theme: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeContextType>();

export const ThemeProvider: ParentComponent = (props) => {
  const [theme, setThemeSignal] = createSignal<ThemeMode>('system');
  const [resolvedTheme, setResolvedTheme] = createSignal<ResolvedTheme>('light');

  const getSystemTheme = (): ResolvedTheme => {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  };

  const updateResolvedTheme = (currentTheme: ThemeMode) => {
    const resolved = currentTheme === 'system' ? getSystemTheme() : currentTheme;
    setResolvedTheme(resolved);
    document.documentElement.setAttribute('data-theme', resolved);
  };

  const setTheme = (newTheme: ThemeMode) => {
    setThemeSignal(newTheme);
    localStorage.setItem('theme', newTheme);
    updateResolvedTheme(newTheme);
  };

  onMount(() => {
    const savedTheme = localStorage.getItem('theme') as ThemeMode || 'system';
    setThemeSignal(savedTheme);
    updateResolvedTheme(savedTheme);

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = () => {
      if (theme() === 'system') {
        updateResolvedTheme('system');
      }
    };

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  });

  const contextValue: ThemeContextType = {
    theme,
    resolvedTheme,
    setTheme,
  };

  return (
    <ThemeContext.Provider value={contextValue}>
      {props.children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};