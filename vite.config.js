import { defineConfig } from 'vite'
import elmPlugin from 'vite-plugin-elm'
import WindiCss from 'vite-plugin-windicss'
export default defineConfig({
  plugins: [
    elmPlugin(),
    WindiCss(),
  ],
});
