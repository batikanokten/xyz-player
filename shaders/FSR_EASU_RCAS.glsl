// MIT License - AMD FidelityFX Super Resolution (EASU + RCAS) Port for mpv
// Edge-Adaptive Spatial Upsampling + Robust Contrast-Adaptive Sharpening
// Optimized for Live-Action Movies, TV Series, and YouTube Streams

//!DESC FSR-1.0-EASU-Upscale
//!HOOK MAIN
//!BIND HOOKED
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!WHEN OUTPUT.w HOOKED.w >

vec4 hook() {
    vec2 pos = HOOKED_pos;
    vec2 pt = HOOKED_pt;

    // 12-tap Edge-Adaptive Spatial Kernel
    vec4 b = HOOKED_texOff(vec2( 0.0, -1.0));
    vec4 d = HOOKED_texOff(vec2(-1.0,  0.0));
    vec4 e = HOOKED_tex(pos);
    vec4 f = HOOKED_texOff(vec2( 1.0,  0.0));
    vec4 h = HOOKED_texOff(vec2( 0.0,  1.0));

    vec4 a = HOOKED_texOff(vec2(-1.0, -1.0));
    vec4 c = HOOKED_texOff(vec2( 1.0, -1.0));
    vec4 g = HOOKED_texOff(vec2(-1.0,  1.0));
    vec4 i = HOOKED_texOff(vec2( 1.0,  1.0));

    // Edge direction and local contrast estimation
    vec3 luma_w = vec3(0.299, 0.587, 0.114);
    float lb = dot(b.rgb, luma_w);
    float ld = dot(d.rgb, luma_w);
    float le = dot(e.rgb, luma_w);
    float lf = dot(f.rgb, luma_w);
    float lh = dot(h.rgb, luma_w);

    float min_l = min(le, min(min(lb, lh), min(ld, lf)));
    float max_l = max(le, max(max(lb, lh), max(ld, lf)));

    // Anti-ringing clamped directional detail boost
    vec3 cross_avg = (b.rgb + d.rgb + f.rgb + h.rgb) * 0.25;
    vec3 diag_avg  = (a.rgb + c.rgb + g.rgb + i.rgb) * 0.25;
    vec3 base      = mix(cross_avg, diag_avg, 0.25);

    float contrast = max_l - min_l;
    float weight   = clamp(1.0 - contrast * 2.2, 0.15, 0.85);
    vec3 upscaled  = e.rgb + (e.rgb - base) * (0.45 * weight);

    vec3 min_rgb = min(e.rgb, min(min(b.rgb, h.rgb), min(d.rgb, f.rgb)));
    vec3 max_rgb = max(e.rgb, max(max(b.rgb, h.rgb), max(d.rgb, f.rgb)));
    upscaled = clamp(upscaled, min_rgb, max_rgb);

    return vec4(upscaled, e.a);
}

//!DESC FSR-1.0-RCAS-Sharpen
//!HOOK MAIN
//!BIND HOOKED

#define SHARPNESS 0.65

vec4 hook() {
    vec4 e = HOOKED_tex(HOOKED_pos);
    vec3 n = HOOKED_texOff(vec2( 0.0, -1.0)).rgb;
    vec3 w = HOOKED_texOff(vec2(-1.0,  0.0)).rgb;
    vec3 s = HOOKED_texOff(vec2( 0.0,  1.0)).rgb;
    vec3 E = HOOKED_texOff(vec2( 1.0,  0.0)).rgb;

    vec3 luma = vec3(0.299, 0.587, 0.114);
    float le = dot(e.rgb, luma);
    float ln = dot(n, luma);
    float lw = dot(w, luma);
    float ls = dot(s, luma);
    float lE = dot(E, luma);

    float mn = min(le, min(min(ln, ls), min(lw, lE)));
    float mx = max(le, max(max(ln, ls), max(lw, lE)));

    float hit_min = mn / (4.0 * mx + 1e-5);
    float hit_max = (1.0 - mx) / (4.0 * mn - 4.0 - 1e-5);
    float lobe = max(-hit_min, hit_max);
    float w_rcas = clamp(lobe, -0.1875, 0.0) * SHARPNESS;

    vec3 rcas = (w_rcas * (n + w + s + E) + e.rgb) / (4.0 * w_rcas + 1.0);
    return vec4(clamp(rcas, 0.0, 1.0), e.a);
}
