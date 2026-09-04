{{flutter_js}}
{{flutter_build_config}}

// High-performance Flutter Web loader:
// 1. Automatically selects the optimal renderer (skwasm / canvaskit / wasm).
// 2. Preloads engine resources without blocking DOM rendering.
// 3. Smoothly cross-fades from the instant CSS App Shell skeleton to Flutter once the first frame paints.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    // Ensure Flutter has drawn the first frame before fading out the HTML/CSS App Shell
    if (window.requestAnimationFrame) {
      window.requestAnimationFrame(function () {
        window.requestAnimationFrame(function () {
          if (typeof window._removeAppShell === 'function') {
            window._removeAppShell();
          }
        });
      });
    } else {
      if (typeof window._removeAppShell === 'function') {
        window._removeAppShell();
      }
    }
  },
});
