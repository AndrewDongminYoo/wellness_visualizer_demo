#version 460 core
// Aurora / northern-lights curtains, layered over the track's theme image.
// Palette and motion are deliberately slow and muted (premium wellness feel).
// Audio mapping:
//   uBass   -> curtain width & vertical reach (the sky "breathes")
//   uMid    -> brightness of the main curtain
//   uTreble -> shimmer detail in the high-frequency ripples
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;

out vec4 fragColor;

// -- value noise + fbm -------------------------------------------------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
               u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(11.3, 7.7);
        a *= 0.5;
    }
    return v;
}

// One aurora curtain: a noisy horizontal ridge with exponential falloff.
float curtain(vec2 uv, float t, float seed, float width) {
    // The ridge line wanders slowly across the sky.
    float ridge = 0.35 + 0.25 * fbm(vec2(uv.x * 1.4 + seed, t * 0.05 + seed * 3.0));
    // Vertical shimmer: fine ripples running along the curtain.
    float ripple = fbm(vec2(uv.x * 6.0 - t * 0.12, uv.y * 2.0 + seed)) * (0.35 + 0.65 * uTreble);
    float d = abs(uv.y - ridge);
    float body = exp(-d / max(width, 1e-3));
    return body * (0.55 + 0.45 * ripple);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    // Work in a sky-space where y=0 is the top.
    vec2 sky = vec2(uv.x, uv.y);

    float t = uTime;
    float breathe = 0.5 + 0.5 * sin(t * 0.35); // ~18s ambient cycle
    float width = mix(0.05, 0.16, clamp(uBass * 0.8 + breathe * 0.2, 0.0, 1.0));

    float c1 = curtain(sky, t, 0.0, width);
    float c2 = curtain(sky, t * 0.8, 4.7, width * 0.7);
    float c3 = curtain(sky, t * 1.15, 9.2, width * 1.5) * 0.5;

    // Muted teal -> violet ramp; hue drifts very slowly.
    vec3 teal = vec3(0.10, 0.75, 0.60);
    vec3 violet = vec3(0.45, 0.25, 0.85);
    vec3 blue = vec3(0.15, 0.35, 0.80);

    vec3 col = teal * c1 + violet * c2 + blue * c3;
    col *= 0.35 + 0.65 * uMid; // main curtain brightness follows the music

    // Gentle vertical fade so the aurora lives in the upper 2/3 of the frame.
    col *= smoothstep(1.0, 0.45, uv.y);

    // Premultiplied-ish additive output; the widget blends with BlendMode.plus.
    fragColor = vec4(col, 0.0);
}
