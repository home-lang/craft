#!/usr/bin/env bun

import { spawn } from "bun";
import { join } from "path";

// Path to the craft executable
const craftBin = join(import.meta.dir, "zig-out/bin/craft");

// HTML content with Liquid Glass sidebar
const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Liquid Glass Sidebar</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
            padding: 2rem;
        }
        .container {
            max-width: 800px;
            text-align: center;
        }
        h1 {
            font-size: 3.5rem;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
        .subtitle {
            font-size: 1.3rem;
            opacity: 0.9;
            margin-bottom: 3rem;
        }
        .status {
            background: rgba(255, 255, 255, 0.15);
            padding: 2rem;
            border-radius: 16px;
            backdrop-filter: blur(10px);
            margin: 2rem 0;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .glass-icon {
            font-size: 5rem;
            margin-bottom: 1rem;
            animation: float 3s ease-in-out infinite;
        }
        @keyframes float {
            0%, 100% { transform: translateY(0px); }
            50% { transform: translateY(-20px); }
        }
        .features {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 1rem;
            margin-top: 2rem;
        }
        .feature {
            background: rgba(255, 255, 255, 0.1);
            padding: 1.5rem;
            border-radius: 12px;
            text-align: left;
            border: 1px solid rgba(255, 255, 255, 0.1);
            transition: all 0.3s ease;
        }
        .feature:hover {
            background: rgba(255, 255, 255, 0.15);
            transform: translateY(-2px);
        }
        .feature-icon {
            font-size: 2rem;
            margin-bottom: 0.5rem;
        }
        .feature-title {
            font-weight: 600;
            margin-bottom: 0.5rem;
        }
        .feature-desc {
            font-size: 0.9rem;
            opacity: 0.8;
        }
        .arrow {
            position: fixed;
            left: 280px;
            top: 50%;
            transform: translateY(-50%);
            font-size: 3rem;
            animation: bounce 2s ease-in-out infinite;
        }
        @keyframes bounce {
            0%, 100% { transform: translateY(-50%) translateX(0); }
            50% { transform: translateY(-50%) translateX(-10px); }
        }
    </style>
</head>
<body>
    <div class="arrow">←</div>

    <div class="container">
        <div class="glass-icon">✨</div>
        <h1>Liquid Glass</h1>
        <p class="subtitle">Native macOS Tahoe Design</p>

        <div class="status">
            <p id="status" style="font-size: 1.2rem; font-weight: 600;">
                ⏳ Initializing sidebar...
            </p>
        </div>

        <div class="features">
            <div class="feature">
                <div class="feature-icon">🎨</div>
                <div class="feature-title">Native Material</div>
                <div class="feature-desc">AppKit handles glass effects automatically</div>
            </div>
            <div class="feature">
                <div class="feature-icon">🔄</div>
                <div class="feature-title">Auto Layout</div>
                <div class="feature-desc">Proper constraint-based positioning</div>
            </div>
            <div class="feature">
                <div class="feature-icon">📐</div>
                <div class="feature-title">Safe Areas</div>
                <div class="feature-desc">Content extends with proper insets</div>
            </div>
            <div class="feature">
                <div class="feature-icon">🚀</div>
                <div class="feature-title">Future-Proof</div>
                <div class="feature-desc">Follows Apple's Tahoe guidelines</div>
            </div>
        </div>

        <p style="margin-top: 2rem; font-size: 1rem; opacity: 0.7;">
            Look to the left ← for the native Liquid Glass sidebar!
        </p>
    </div>

    <script>
        // Wait for Craft bridge to load
        window.addEventListener('DOMContentLoaded', () => {
            console.log('DOM loaded, waiting for craft bridge...');

            // Poll for the bridge with timeout
            let attempts = 0;
            const maxAttempts = 50;

            const checkBridge = setInterval(() => {
                attempts++;

                if (typeof window.craft !== 'undefined' && window.craft.nativeUI) {
                    clearInterval(checkBridge);
                    initializeSidebar();
                } else if (attempts >= maxAttempts) {
                    clearInterval(checkBridge);
                    document.getElementById('status').innerHTML =
                        '❌ Craft bridge not available<br><span style="font-size: 0.8rem;">Bridge may not be loaded yet</span>';
                    console.error('Bridge not available. window.craft =', window.craft);
                }
            }, 100);
        });

        function initializeSidebar() {
            console.log('✅ craft bridge available, creating sidebar...');

            try {
                // Create sidebar with native Liquid Glass (returns Sidebar instance)
                const sidebar = window.craft.nativeUI.createSidebar({
                    id: 'main-sidebar'
                });

                console.log('Created sidebar instance:', sidebar);

                // Add navigation section using instance method
                sidebar.addSection({
                    id: 'navigation',
                    header: 'NAVIGATION',
                    items: [
                        { id: 'home', label: 'Home', icon: '🏠' },
                        { id: 'documents', label: 'Documents', icon: '📄' },
                        { id: 'downloads', label: 'Downloads', icon: '⬇️' },
                        { id: 'favorites', label: 'Favorites', icon: '⭐' }
                    ]
                });

                // Add workspace section
                sidebar.addSection({
                    id: 'workspace',
                    header: 'WORKSPACE',
                    items: [
                        { id: 'projects', label: 'Projects', icon: '📁', badge: '5' },
                        { id: 'recent', label: 'Recent', icon: '🕒' },
                        { id: 'shared', label: 'Shared', icon: '👥', badge: '2' }
                    ]
                });

                // Add settings section
                sidebar.addSection({
                    id: 'settings',
                    header: 'SETTINGS',
                    items: [
                        { id: 'preferences', label: 'Preferences', icon: '⚙️' },
                        { id: 'about', label: 'About', icon: 'ℹ️' }
                    ]
                });

                // Update status - Liquid Glass effect should be visible now!
                document.getElementById('status').innerHTML =
                    '✅ Liquid Glass Sidebar Active!<br><span style="font-size: 0.9rem; opacity: 0.8;">NSVisualEffectView with sidebar material</span>';

                console.log('✅ Sidebar initialized successfully!');
            } catch (error) {
                console.error('Error creating sidebar:', error);
                document.getElementById('status').innerHTML =
                    '❌ Error creating sidebar<br><span style="font-size: 0.8rem;">' + error.message + '</span>';
            }
        }
    </script>
</body>
</html>
`.trim();

// Write HTML to temp file
const tmpDir = "/tmp";
const htmlPath = join(tmpDir, "craft-sidebar-demo.html");
await Bun.write(htmlPath, html);

console.log("🎨 Launching Liquid Glass Sidebar Demo...\n");
console.log("Features:");
console.log("  ✓ Native NSSplitViewController");
console.log("  ✓ Automatic Liquid Glass material");
console.log("  ✓ No manual NSVisualEffectView");
console.log("  ✓ Proper Auto Layout");
console.log("  ✓ Safe area insets");
console.log("  ✓ Unified toolbar style\n");

// Launch the app
const proc = spawn({
  cmd: [
    craftBin,
    "--url", `file://${htmlPath}`,
    "--title", "Liquid Glass Demo",
    "--width", "1200",
    "--height", "800",
    "--titlebar-hidden"
  ],
  stdout: "inherit",
  stderr: "inherit",
});

console.log("🚀 App launched!");
console.log("\n👀 Look for:");
console.log("  • Floating glass sidebar on the left");
console.log("  • Beautiful gradient background");
console.log("  • Native macOS appearance\n");

// Wait for the process
await proc.exited;
