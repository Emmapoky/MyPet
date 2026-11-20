// MyPet web test build on Cloudflare Workers (free plan, static assets).
// Everything is served as plain files, except the two behaviour models: Workers
// limits one file to 25 MiB, so tool/build_web.sh stores each model in parts and
// this joins them back into one download at /models/<name>.onnx.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const m = url.pathname.match(/^\/models\/([\w.-]+\.onnx)$/);
    if (!m) return env.ASSETS.fetch(request);

    const list = await env.ASSETS.fetch(new URL('/models/parts.json', url));
    if (!list.ok) return new Response('Not found', { status: 404 });
    const model = (await list.json())[m[1]];
    if (!model) return new Response('Not found', { status: 404 });

    const { readable, writable } = new TransformStream();
    (async () => {
      try {
        for (const part of model.parts) {
          const r = await env.ASSETS.fetch(new URL(`/models/${part}`, url));
          if (!r.ok || !r.body) throw new Error(`missing ${part}`);
          await r.body.pipeTo(writable, { preventClose: true });
        }
        await writable.close();
      } catch (e) {
        await writable.abort(e);
      }
    })();
    return new Response(readable, {
      headers: {
        'content-type': 'application/octet-stream',
        'content-length': String(model.size),
        'cache-control': 'public, max-age=604800',
      },
    });
  },
};
