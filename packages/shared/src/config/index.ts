/**
 * Global configuration for Streamia
 * Centralizes all environment variables and configuration settings
 */

// Use window global for sharing config across MFEs
declare global {
  interface Window {
    __STREAMIA_CONFIG__?: StreamiaConfig;
  }
}

interface StreamiaConfig {
  API_URL: string;
}

const getApiUrl = (): string => {
  // Check if we're in a Vite environment
  try {
    // @ts-ignore - Vite injects import.meta.env at build time
    if (import.meta?.env?.VITE_API_URL) {
      // @ts-ignore
      return import.meta.env.VITE_API_URL;
    }
  } catch {
    // Not in Vite environment
  }
  
  return 'http://localhost:3000/api';
};

const getConfig = (): StreamiaConfig => {
  if (typeof window !== 'undefined' && window.__STREAMIA_CONFIG__) {
    return window.__STREAMIA_CONFIG__;
  }

  const config: StreamiaConfig = {
    API_URL: getApiUrl(),
  };

  // Store in window for sharing across MFEs
  if (typeof window !== 'undefined') {
    window.__STREAMIA_CONFIG__ = config;
  }

  return config;
};

export const config = getConfig();

// Export individual values for convenience
export const API_URL = config.API_URL;
