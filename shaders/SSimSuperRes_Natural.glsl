// GPLv3 / MIT - Perceptual SSIM Super-Resolution Shader for mpv
// Designed for Cinema, Live-Action Movies, and Natural Textures

//!DESC SSimSuperRes-Perceptual-Cinema
//!HOOK MAIN
//!BIND HOOKED
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h

#define STRENGTH 0.55

vec4 hook() {
    vec4 c0 = HOOKED_tex(HOOKED_pos);
    vec3 n  = HOOKED_texOff(vec2( 0.0, -1.0)).rgb;
    vec3 s  = HOOKED_texOff(vec2( 0.0,  1.0)).rgb;
    vec3 w  = HOOKED_texOff(vec2(-1.0,  0.0)).rgb;
    vec3 e  = HOOKED_texOff(vec2( 1.0,  0.0)).rgb;
    vec3 nw = HOOKED_texOff(vec2(-1.0, -1.0)).rgb;
    vec3 ne = HOOKED_texOff(vec2( 1.0, -1.0)).rgb;
    vec3 sw = HOOKED_texOff(vec2(-1.0,  1.0)).rgb;
    vec3 se = HOOKED_texOff(vec2( 1.0,  1.0)).rgb;

    // Gaussian local mean (mu)
    vec3 mu = (c0.rgb * 4.0 + (n + s + w + e) * 2.0 + (nw + ne + sw + se)) / 16.0;

    // Local structural variance (SSIM modulation)
    vec3 diff = c0.rgb - mu;
    vec3 var_sum = (
        (n - mu) * (n - mu) + (s - mu) * (s - mu) +
        (w - mu) * (w - mu) + (e - mu) * (e - mu)
    ) * 0.25;

    vec3 std_dev = sqrt(var_sum + 1e-6);
    vec3 ssim_gain = std_dev / (std_dev + 0.035);

    // High-frequency fine texture recovery without haloing
    vec3 enhanced = c0.rgb + diff * ssim_gain * STRENGTH;

    vec3 min_v = min(c0.rgb, min(min(n, s), min(w, e)));
    vec3 max_v = max(c0.rgb, max(max(n, s), max(w, e)));
    enhanced = clamp(enhanced, min_v - 0.02, max_v + 0.02);

    return vec4(clamp(enhanced, 0.0, 1.0), c0.a);
}
