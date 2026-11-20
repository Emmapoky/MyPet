// Browser helpers for the behaviour check in the web build (lib/web/web_engine.dart).
// They do what ffmpeg does on the phone: pull out the sound as 48 kHz mono, read the
// clip's length, and grab one frame per second as square RGB pictures.
// Everything stays in this browser.
(function () {
  function loadVideo(url) {
    return new Promise(function (resolve, reject) {
      var v = document.createElement('video');
      v.muted = true;
      v.playsInline = true;
      v.preload = 'auto';
      v.crossOrigin = 'anonymous';
      v.onloadeddata = function () { resolve(v); };
      v.onerror = function () { reject(new Error('Could not open the clip')); };
      v.src = url;
      v.load();
    });
  }

  function seek(v, t) {
    return new Promise(function (resolve) {
      var done = false;
      function finish() { if (!done) { done = true; v.removeEventListener('seeked', finish); resolve(); } }
      v.addEventListener('seeked', finish);
      setTimeout(finish, 3000);
      v.currentTime = t;
    });
  }

  // Clips recorded in Chrome report an unknown (Infinity) length until the end is read.
  async function duration(v) {
    if (isFinite(v.duration) && v.duration > 0) return v.duration;
    await seek(v, 1e7);
    var d = isFinite(v.duration) && v.duration > 0 ? v.duration : v.currentTime;
    await seek(v, 0);
    return d || 0;
  }

  // "iPhone · Safari 18 · 6 cores" style line for the check timing readout. No IDs.
  function deviceLine() {
    var ua = navigator.userAgent || '';
    var dev = /iPhone/.test(ua) ? 'iPhone' : /iPad/.test(ua) ? 'iPad'
      : /Android/.test(ua) ? (ua.match(/Android[^;]*;\s*([^;)]+?)(?:\sBuild|\))/) || [, 'Android'])[1]
      : /Macintosh/.test(ua) ? (navigator.maxTouchPoints > 1 ? 'iPad' : 'Mac')
      : /Windows/.test(ua) ? 'Windows PC' : /Linux/.test(ua) ? 'Linux' : 'Unknown device';
    var m;
    var br = (m = ua.match(/(?:Edg|EdgiOS)\/(\d+)/)) ? 'Edge ' + m[1]
      : (m = ua.match(/(?:CriOS|Chrome)\/(\d+)/)) ? 'Chrome ' + m[1]
      : (m = ua.match(/(?:FxiOS|Firefox)\/(\d+)/)) ? 'Firefox ' + m[1]
      : (m = ua.match(/Version\/(\d+).*Safari/)) ? 'Safari ' + m[1] : 'Browser';
    var bits = [dev, br];
    if (navigator.hardwareConcurrency) bits.push(navigator.hardwareConcurrency + ' cores');
    if (navigator.deviceMemory) bits.push(navigator.deviceMemory + ' GB');
    return bits.join(' \u00b7 ');
  }

  window.mypetMedia = {
    deviceLine: deviceLine,

    bytes: async function (url) {
      var r = await fetch(url);
      return new Uint8Array(await r.arrayBuffer());
    },

    // The soundtrack, mixed to one channel and resampled to `rate` (like ffmpeg -ac 1 -ar).
    decodeAudio: async function (url, rate) {
      var data = await (await fetch(url)).arrayBuffer();
      var Ctx = window.AudioContext || window.webkitAudioContext;
      var ctx = new Ctx();
      var buf;
      try {
        buf = await new Promise(function (res, rej) { ctx.decodeAudioData(data, res, rej); });
      } finally {
        if (ctx.close) ctx.close();
      }
      var len = Math.max(1, Math.ceil(buf.duration * rate));
      var off = new OfflineAudioContext(1, len, rate);
      var src = off.createBufferSource();
      src.buffer = buf;
      src.connect(off.destination);
      src.start();
      var out = await off.startRendering();
      return out.getChannelData(0);
    },

    // [seconds, 1 if the clip has pictures else 0]. Audio-only files give [0, 0].
    probe: async function (url) {
      try {
        var v = await loadVideo(url);
        var d = await duration(v);
        var hasVideo = v.videoWidth > 0 ? 1 : 0;
        v.removeAttribute('src');
        v.load();
        return [d, hasVideo];
      } catch (e) {
        return [0, 0];
      }
    },

    // One frame per second (second k at k + 0.5 s, at most `max`), scaled to cover a
    // size x size square and centre-cropped, as RGB bytes one after another.
    frames: async function (url, size, max, dur) {
      var v = await loadVideo(url);
      var n = Math.min(max, Math.max(1, Math.ceil(dur)));
      var c = document.createElement('canvas');
      c.width = size;
      c.height = size;
      var g = c.getContext('2d', { willReadFrequently: true });
      g.imageSmoothingEnabled = true;
      g.imageSmoothingQuality = 'high';
      var out = new Uint8Array(n * size * size * 3);
      var got = 0;
      for (var k = 0; k < n; k++) {
        await seek(v, Math.min(k + 0.5, Math.max(0, dur - 0.05)));
        var w = v.videoWidth, h = v.videoHeight;
        if (!w || !h) break;
        var s = Math.max(size / w, size / h);
        var dw = w * s, dh = h * s;
        g.drawImage(v, (size - dw) / 2, (size - dh) / 2, dw, dh);
        var px = g.getImageData(0, 0, size, size).data;
        var o = got * size * size * 3;
        for (var i = 0, j = 0; i < px.length; i += 4, j += 3) {
          out[o + j] = px[i];
          out[o + j + 1] = px[i + 1];
          out[o + j + 2] = px[i + 2];
        }
        got++;
      }
      v.removeAttribute('src');
      v.load();
      return out.subarray(0, got * size * size * 3);
    },
  };
})();
