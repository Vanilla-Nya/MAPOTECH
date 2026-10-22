/*
 * VitaScale by MAPOTECH — Browser Computer Vision module (marker-based).
 *
 * Zero-install: runs entirely in the browser on top of the repository-vendored
 * OpenCV.js (web/vitascale/opencv.js). Camera frames are processed locally and
 * are NEVER uploaded. Only the numeric result is returned to Dart.
 *
 * Measurement principle (no silhouette / no YOLO):
 *   - The measuring board carries 4 SOLID dark square reference markers whose
 *     centres form a rectangle of known physical size (boardWidthCm x boardHeightCm).
 *   - The movable head/foot piece carries 1 RING marker (dark square with a light
 *     hole) — the "slider".
 *   - A homography maps image pixels -> board coordinates in centimetres, which
 *     corrects perspective. The slider centre position along the measuring axis,
 *     plus mechanical calibration offsets, gives the length/height.
 *   - The frame is rejected unless exactly 4 reference markers + 1 slider are
 *     found and the reprojected marker size matches the known physical size.
 *
 * Accuracy is NOT clinically validated. Results must be verified by staff.
 */
(function (root) {
  'use strict';

  var DEFAULT_CONFIG = {
    refMarkerSizeCm: 5.0, // physical side length of each reference marker
    boardWidthCm: 40.0, // distance between reference marker centres along X
    boardHeightCm: 120.0, // distance between reference marker centres along Y
    axis: 'y', // measuring axis in board coordinates: 'y' or 'x'
    zeroOffsetCm: 0.0, // board coordinate of the fixed head plate / floor (calibration)
    sliderOffsetCm: 0.0, // slider marker centre -> measuring face (calibration)
    invertAxis: false, // true if the measurement grows towards decreasing coordinate
    tolerancePct: 12.0, // max allowed reference marker size error
    minAreaRatio: 0.0004, // min marker area relative to the frame area
    maxDim: 1280 // frames are downscaled to this maximum dimension
  };

  function mergeConfig(cfg) {
    var out = {};
    var k;
    for (k in DEFAULT_CONFIG) out[k] = DEFAULT_CONFIG[k];
    if (cfg) for (k in cfg) if (cfg[k] !== undefined && cfg[k] !== null) out[k] = cfg[k];
    return out;
  }

  function dist(a, b) {
    var dx = a.x - b.x;
    var dy = a.y - b.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function contourPoints(approx) {
    var pts = [];
    for (var i = 0; i < approx.rows; i++) {
      pts.push({ x: approx.data32S[i * 2], y: approx.data32S[i * 2 + 1] });
    }
    return pts;
  }

  function centroid(pts) {
    var sx = 0;
    var sy = 0;
    for (var i = 0; i < pts.length; i++) {
      sx += pts[i].x;
      sy += pts[i].y;
    }
    return { x: sx / pts.length, y: sy / pts.length };
  }

  // Orders 4 points as TL, TR, BR, BL using coordinate sums/differences.
  function orderQuad(pts) {
    var bySum = pts.slice().sort(function (a, b) { return (a.x + a.y) - (b.x + b.y); });
    var byDiff = pts.slice().sort(function (a, b) { return (a.x - a.y) - (b.x - b.y); });
    return [bySum[0], byDiff[3], bySum[3], byDiff[0]];
  }

  function applyH(H, p) {
    var d = H.data64F;
    var w = d[6] * p.x + d[7] * p.y + d[8];
    return { x: (d[0] * p.x + d[1] * p.y + d[2]) / w, y: (d[3] * p.x + d[4] * p.y + d[5]) / w };
  }

  /**
   * Core measurement — pure function over RGBA image data. Exported for tests.
   * @param cv     initialised OpenCV.js namespace
   * @param image  { data: Uint8ClampedArray (RGBA), width, height }
   * @param config see DEFAULT_CONFIG
   * @returns {{ok:boolean, valueCm:(number|null), reasons:string[], diagnostics:Object, markers:Object}}
   */
  function measureFromImageData(cv, image, config) {
    var cfg = mergeConfig(config);
    var reasons = [];
    var diagnostics = { refCount: 0, sliderCount: 0, markerSizeErrorPct: null, slider: null };
    var markers = { refs: [], slider: null };
    var mats = [];
    function track(m) { mats.push(m); return m; }

    try {
      var src = track(cv.matFromImageData(image));
      var gray = track(new cv.Mat());
      cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY);
      var blur = track(new cv.Mat());
      cv.GaussianBlur(gray, blur, new cv.Size(5, 5), 0);
      var bin = track(new cv.Mat());
      // Dark markers on light board -> white blobs after inverse Otsu threshold.
      cv.threshold(blur, bin, 0, 255, cv.THRESH_BINARY_INV + cv.THRESH_OTSU);

      var contours = track(new cv.MatVector());
      var hierarchy = track(new cv.Mat());
      cv.findContours(bin, contours, hierarchy, cv.RETR_CCOMP, cv.CHAIN_APPROX_SIMPLE);

      var frameArea = image.width * image.height;
      var minArea = frameArea * cfg.minAreaRatio;
      var refs = [];
      var sliders = [];

      for (var i = 0; i < contours.size(); i++) {
        var parent = hierarchy.intPtr(0, i)[3];
        if (parent !== -1) continue; // only outer contours
        var cnt = contours.get(i);
        var area = cv.contourArea(cnt);
        if (area < minArea) { cnt.delete(); continue; }
        var peri = cv.arcLength(cnt, true);
        var approx = new cv.Mat();
        cv.approxPolyDP(cnt, approx, 0.04 * peri, true);
        var isQuad = approx.rows === 4 && cv.isContourConvex(approx);
        if (isQuad) {
          var pts = contourPoints(approx);
          var s1 = dist(pts[0], pts[1]);
          var s2 = dist(pts[1], pts[2]);
          var aspect = Math.max(s1, s2) / Math.max(1e-6, Math.min(s1, s2));
          if (aspect < 2.2) {
            // Child contour (hole) => ring/slider marker.
            var child = hierarchy.intPtr(0, i)[2];
            var holeArea = 0;
            while (child !== -1) {
              var ch = contours.get(child);
              holeArea = Math.max(holeArea, cv.contourArea(ch));
              ch.delete();
              child = hierarchy.intPtr(0, child)[0];
            }
            var entry = { corners: pts, center: centroid(pts), area: area };
            if (holeArea > area * 0.12) sliders.push(entry);
            else refs.push(entry);
          }
        }
        approx.delete();
        cnt.delete();
      }

      diagnostics.refCount = refs.length;
      diagnostics.sliderCount = sliders.length;
      markers.refs = refs.map(function (r) { return r.corners; });
      markers.slider = sliders.length === 1 ? sliders[0].corners : null;

      if (refs.length !== 4) reasons.push('Marker referensi terdeteksi ' + refs.length + '/4.');
      if (sliders.length !== 1) reasons.push('Marker penggeser (ring) terdeteksi ' + sliders.length + '/1.');
      if (reasons.length) return { ok: false, valueCm: null, reasons: reasons, diagnostics: diagnostics, markers: markers };

      var ordered = orderQuad(refs.map(function (r) { return r.center; }));
      var W = cfg.boardWidthCm;
      var Hh = cfg.boardHeightCm;
      var srcPts = track(cv.matFromArray(4, 1, cv.CV_32FC2, [
        ordered[0].x, ordered[0].y, ordered[1].x, ordered[1].y,
        ordered[2].x, ordered[2].y, ordered[3].x, ordered[3].y
      ]));
      var dstPts = track(cv.matFromArray(4, 1, cv.CV_32FC2, [0, 0, W, 0, W, Hh, 0, Hh]));
      var H = track(cv.getPerspectiveTransform(srcPts, dstPts));

      // Validate homography: reference markers must reproject to their known size.
      var sizes = [];
      for (var r = 0; r < refs.length; r++) {
        var c = refs[r].corners.map(function (p) { return applyH(H, p); });
        for (var e = 0; e < 4; e++) sizes.push(dist(c[e], c[(e + 1) % 4]));
      }
      var meanSize = sizes.reduce(function (a, b) { return a + b; }, 0) / sizes.length;
      var sizeErrPct = Math.abs(meanSize - cfg.refMarkerSizeCm) / cfg.refMarkerSizeCm * 100;
      diagnostics.markerSizeErrorPct = Math.round(sizeErrPct * 10) / 10;
      if (!(sizeErrPct <= cfg.tolerancePct)) {
        reasons.push('Ukuran marker hasil koreksi perspektif menyimpang ' + diagnostics.markerSizeErrorPct +
          '% (batas ' + cfg.tolerancePct + '%). Periksa kalibrasi papan atau posisi kamera.');
      }

      var sp = applyH(H, sliders[0].center);
      diagnostics.slider = { xCm: Math.round(sp.x * 100) / 100, yCm: Math.round(sp.y * 100) / 100 };
      var margin = 2 * cfg.refMarkerSizeCm;
      if (sp.x < -margin || sp.x > W + margin || sp.y < -margin || sp.y > Hh + margin) {
        reasons.push('Marker penggeser berada di luar area papan ukur.');
      }

      var coord = cfg.axis === 'x' ? sp.x : sp.y;
      var span = cfg.axis === 'x' ? W : Hh;
      var raw = cfg.invertAxis ? (span - coord) : coord;
      var value = raw - cfg.zeroOffsetCm + cfg.sliderOffsetCm;
      if (!(value > 0)) reasons.push('Nilai hasil pengukuran tidak valid (<= 0 cm). Periksa kalibrasi titik nol.');

      if (reasons.length) return { ok: false, valueCm: null, reasons: reasons, diagnostics: diagnostics, markers: markers };
      return { ok: true, valueCm: Math.round(value * 10) / 10, reasons: [], diagnostics: diagnostics, markers: markers };
    } catch (err) {
      reasons.push('Kesalahan pemrosesan citra: ' + (err && err.message ? err.message : String(err)));
      return { ok: false, valueCm: null, reasons: reasons, diagnostics: diagnostics, markers: markers };
    } finally {
      for (var m = 0; m < mats.length; m++) {
        try { mats[m].delete(); } catch (_) { /* already freed */ }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Browser-only helpers
  // ---------------------------------------------------------------------------
  var loadPromise = null;

  function resolveCv() {
    return new Promise(function (resolve, reject) {
      var cvRef = root.cv;
      if (!cvRef) { reject(new Error('OpenCV.js tidak ditemukan.')); return; }
      if (typeof cvRef.then === 'function') {
        cvRef.then(function (ready) { root.cv = ready; resolve(ready); }, reject);
        return;
      }
      if (cvRef.Mat) { resolve(cvRef); return; }
      cvRef.onRuntimeInitialized = function () { resolve(root.cv); };
    });
  }

  function load(src) {
    if (loadPromise) return loadPromise;
    loadPromise = new Promise(function (resolve, reject) {
      if (root.cv) { resolveCv().then(resolve, reject); return; }
      var s = root.document.createElement('script');
      s.src = src || 'vitascale/opencv.js';
      s.async = true;
      s.onload = function () { resolveCv().then(resolve, reject); };
      s.onerror = function () { reject(new Error('Gagal memuat OpenCV.js dari ' + s.src)); };
      root.document.head.appendChild(s);
    }).then(function () { return true; }, function (e) { loadPromise = null; throw e; });
    return loadPromise;
  }

  function isReady() { return !!(root.cv && root.cv.Mat); }

  function grabFrame(videoEl, maxDim) {
    var w = videoEl.videoWidth;
    var h = videoEl.videoHeight;
    if (!w || !h) return null;
    var scale = Math.min(1, maxDim / Math.max(w, h));
    var cw = Math.round(w * scale);
    var ch = Math.round(h * scale);
    var canvas = root.document.createElement('canvas');
    canvas.width = cw;
    canvas.height = ch;
    var ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(videoEl, 0, 0, cw, ch);
    return { canvas: canvas, ctx: ctx, image: ctx.getImageData(0, 0, cw, ch) };
  }

  function annotate(frame, result) {
    var ctx = frame.ctx;
    ctx.lineWidth = Math.max(2, frame.canvas.width / 320);
    ctx.strokeStyle = '#3B82F6';
    result.markers.refs.forEach(function (q) {
      ctx.beginPath();
      q.forEach(function (p, i) { if (i === 0) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y); });
      ctx.closePath();
      ctx.stroke();
    });
    if (result.markers.slider) {
      ctx.strokeStyle = '#EC4899';
      ctx.beginPath();
      result.markers.slider.forEach(function (p, i) { if (i === 0) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y); });
      ctx.closePath();
      ctx.stroke();
    }
    // Local preview only — kept in browser memory, never uploaded.
    return frame.canvas.toDataURL('image/jpeg', 0.7);
  }

  /**
   * Captures the current video frame and measures it.
   * @returns JSON string { ok, valueCm, reasons, diagnostics, previewDataUrl? }
   */
  function measureVideo(videoEl, configJson, withPreview) {
    if (!isReady()) {
      return JSON.stringify({ ok: false, valueCm: null, reasons: ['OpenCV.js belum siap.'], diagnostics: {} });
    }
    var cfg = mergeConfig(configJson ? JSON.parse(configJson) : null);
    var frame = grabFrame(videoEl, cfg.maxDim);
    if (!frame) {
      return JSON.stringify({ ok: false, valueCm: null, reasons: ['Frame kamera belum tersedia.'], diagnostics: {} });
    }
    var result = measureFromImageData(root.cv, frame.image, cfg);
    var out = { ok: result.ok, valueCm: result.valueCm, reasons: result.reasons, diagnostics: result.diagnostics };
    if (withPreview) out.previewDataUrl = annotate(frame, result);
    return JSON.stringify(out);
  }

  var api = {
    DEFAULT_CONFIG: DEFAULT_CONFIG,
    load: load,
    isReady: isReady,
    measureVideo: measureVideo,
    measureFromImageData: measureFromImageData
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (root && typeof root === 'object') root.VitaScaleCV = api;
})(typeof window !== 'undefined' ? window : globalThis);
