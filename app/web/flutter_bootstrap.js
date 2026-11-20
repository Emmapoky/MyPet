{{flutter_js}}
{{flutter_build_config}}

// Draw the app inside #app (phone width on a laptop, full screen on a phone).
_flutter.loader.load({
  config: { hostElement: document.querySelector('#app') },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine({ hostElement: document.querySelector('#app') });
    document.querySelector('#loading')?.remove();
    await appRunner.runApp();
  },
});
