import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import inject from '@rollup/plugin-inject';
import autoprefixer from 'autoprefixer';

// For __dirname equivalent in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export default defineConfig(({ command, mode }) => {
    const isProduction = mode === 'production';

    return {
        // Ensure we're using the proper mode for hot reloading
        mode: command === 'serve' ? 'development' : mode,

        // Build configuration
        build: {
            outDir: 'dist',
            emptyOutDir: true,
            sourcemap: !isProduction,
            minify: isProduction ? 'terser' : false,
            terserOptions: {
                compress: {
                    drop_console: isProduction,
                },
                output: {
                    ecma: 5,
                },
            },
            // Increase chunk size warning limit to prevent unnecessary warnings
            chunkSizeWarningLimit: 5000,
            rollupOptions: {
                plugins: [
                    inject({
                        $: 'jquery',
                        jQuery: 'jquery',
                        moment: 'moment-timezone'
                    })
                ],
                input: {
                    'ntopng': resolve(__dirname, 'http_src/ntopng.js'),
                    'ntopng_css': resolve(__dirname, 'http_src/ntopng_css.js'),
                    'third-party': resolve(__dirname, 'assets/third-party.js'),
                    'custom-theme': resolve(__dirname, 'http_src/views/private/clients/custom_theme.js'),
                    'dark-mode': resolve(__dirname, 'http_src/views/private/clients/dark-mode.js'),
                    'white-mode': resolve(__dirname, 'http_src/views/private/clients/white-mode.js'),
                    'images': resolve(__dirname, 'assets/images/images.js'),
                    'login': resolve(__dirname, 'assets/scripts/login.js')
                },
                output: {
                    entryFileNames: '[name].js',
                    chunkFileNames: '[name].js',
                    assetFileNames: (assetInfo) => {
                        if (assetInfo.name.endsWith('.css')) {
                            return '[name].css';
                        }
                        return 'assets/[name].[ext]';
                    },
                    // Split large third-party dependencies into separate chunks
                    manualChunks: {
                        'vendor-core': ['vue', 'jquery', 'bootstrap'],
                        'vendor-datatables': [
                            'datatables.net-dt',
                            'datatables.net-buttons-dt',
                            'datatables.net-colreorder-dt',
                            'datatables.net-responsive-dt'
                        ],
                        'vendor-charts': ['d3', 'apexcharts', 'nvd3'],
                        // Add problematic dependencies with evals here
                        'vendor-eval-safe': ['store-js']
                    }
                }
            }
        },

        // Plugins configuration
        plugins: [
            vue(),
            {
                name: 'provide-globals',
                config() {
                    return {
                        define: {
                            $: 'jquery',
                            jQuery: 'jquery',
                            'window.jQuery': 'jquery',
                        }
                    };
                }
            },
            // Special handling for files with eval
            {
                name: 'handle-eval-files',
                transform(code, id) {
                    // Skip transforming problematic files that use eval
                    if (id.includes('store-js/plugins/lib/json2.js') ||
                        id.includes('jquery.tablesorter.js')) {
                        return { code, map: null };
                    }
                }
            }
        ],

        // Add proper watch configuration
        server: {
            watch: {
                ignored: ['!**/node_modules/**', '**/httpdocs/dist/**'],
                usePolling: true, // This helps with file system watchers in some environments
                interval: 1000
            }
        },

        // Explicitly configure the watch mode for build
        watch: {
            include: ['http_src/**/*', 'assets/**/*'],
            exclude: ['node_modules/**', 'httpdocs/dist/**'],
            buildDelay: 100
        },

        // Resolve aliases
        resolve: {
            alias: {
                '@': resolve(__dirname, 'http_src'),
                'vue': isProduction
                    ? 'vue/dist/vue.esm-browser.prod.js'
                    : 'vue/dist/vue.esm-browser.js'
            }
        },

        // CSS processing
        css: {
            preprocessorOptions: {
                scss: {
                    // SCSS options if needed
                }
            },
            postcss: {
                plugins: [
                    autoprefixer()
                ]
            }
        },

        // Optimize dependencies
        optimizeDeps: {
            include: [
                'jquery',
                'bootstrap',
                'vue',
                'd3',
                'moment',
                'flatpickr',
                '@popperjs/core',
                'apexcharts',
                'datatables.net-dt',
                'select2',
                'leaflet'
            ],
            exclude: [
                // Exclude problematic packages that use eval
                'store-js',
                'jquery.tablesorter'
            ]
        }
    };
});