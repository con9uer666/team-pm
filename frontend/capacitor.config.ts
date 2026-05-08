import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.teampm.app',
  appName: '战队管理',
  webDir: 'dist',
  android: {
    allowMixedContent: true,
  },
};

export default config;
