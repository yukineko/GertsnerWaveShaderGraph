#ifndef GERSTNER_WAVE_INCLUDED
#define GERSTNER_WAVE_INCLUDED

// ============================================
// Gerstner Wave Implementation for Unity URP
// ============================================

// 定数
#define GRAVITY 9.81
#define PI 3.14159265359
#define TWO_PI 6.28318530718

// ============================================
// コア計算関数（float版）
// ============================================

void CalculateSingleGerstnerWave(
    float2 position,
    float time,
    float2 direction,
    float wavelength,
    float amplitude,
    float steepness,
    float speed,
    out float3 displacement,
    out float3 normal)
{
    // 方向を正規化
    float2 dir = normalize(direction);
    
    // 周波数 w = 2π / wavelength
    float w = TWO_PI / max(wavelength, 0.001);
    
    // 位相速度 φ = speed * w
    float phi = speed * w;
    
    // Q: 波の急峻さを制御するパラメータ
    float Q = steepness / (w * amplitude + 0.001);
    
    // 波の位相
    float phase = w * dot(dir, position) + phi * time;
    
    // 三角関数の計算
    float sinPhase = sin(phase);
    float cosPhase = cos(phase);
    
    // Gerstner Wave変位
    displacement.x = Q * amplitude * dir.x * cosPhase;
    displacement.y = amplitude * sinPhase;
    displacement.z = Q * amplitude * dir.y * cosPhase;
    
    // 法線計算
    float WA = w * amplitude;
    normal.x = -dir.x * WA * cosPhase;
    normal.y = 1.0 - Q * WA * sinPhase;
    normal.z = -dir.y * WA * cosPhase;
}

// ============================================
// Shader Graph用インターフェース（単一波）
// ============================================

void GerstnerWave_float(
    float2 Position,
    float Time,
    float2 Direction,
    float Wavelength,
    float Amplitude,
    float Steepness,
    float Speed,
    out float3 Displacement,
    out float3 Normal)
{
    CalculateSingleGerstnerWave(
        Position,
        Time,
        Direction,
        Wavelength,
        Amplitude,
        saturate(Steepness),
        Speed,
        Displacement,
        Normal
    );
    Normal = normalize(Normal);
}

void GerstnerWave_half(
    half2 Position,
    half Time,
    half2 Direction,
    half Wavelength,
    half Amplitude,
    half Steepness,
    half Speed,
    out half3 Displacement,
    out half3 Normal)
{
    // half版も直接計算（キャスト問題を回避）
    half2 dir = normalize(Direction);
    half w = TWO_PI / max(Wavelength, (half)0.001);
    half phi = Speed * w;
    half Q = Steepness / (w * Amplitude + (half)0.001);
    half phase = w * dot(dir, Position) + phi * Time;
    
    half sinPhase = sin(phase);
    half cosPhase = cos(phase);
    
    Displacement.x = Q * Amplitude * dir.x * cosPhase;
    Displacement.y = Amplitude * sinPhase;
    Displacement.z = Q * Amplitude * dir.y * cosPhase;
    
    half WA = w * Amplitude;
    Normal.x = -dir.x * WA * cosPhase;
    Normal.y = (half)1.0 - Q * WA * sinPhase;
    Normal.z = -dir.y * WA * cosPhase;
    Normal = normalize(Normal);
}

// ============================================
// 4波合成用（Shader Graph用）
// ============================================

void GerstnerWaves4_float(
    float2 Position,
    float Time,
    float2 Dir1, float Wavelength1, float Amplitude1, float Steepness1, float Speed1,
    float2 Dir2, float Wavelength2, float Amplitude2, float Steepness2, float Speed2,
    float2 Dir3, float Wavelength3, float Amplitude3, float Steepness3, float Speed3,
    float2 Dir4, float Wavelength4, float Amplitude4, float Steepness4, float Speed4,
    out float3 Displacement,
    out float3 Normal)
{
    float3 disp1, disp2, disp3, disp4;
    float3 norm1, norm2, norm3, norm4;
    
    CalculateSingleGerstnerWave(Position, Time, Dir1, Wavelength1, Amplitude1, saturate(Steepness1), Speed1, disp1, norm1);
    CalculateSingleGerstnerWave(Position, Time, Dir2, Wavelength2, Amplitude2, saturate(Steepness2), Speed2, disp2, norm2);
    CalculateSingleGerstnerWave(Position, Time, Dir3, Wavelength3, Amplitude3, saturate(Steepness3), Speed3, disp3, norm3);
    CalculateSingleGerstnerWave(Position, Time, Dir4, Wavelength4, Amplitude4, saturate(Steepness4), Speed4, disp4, norm4);
    
    Displacement = disp1 + disp2 + disp3 + disp4;
    Normal = normalize(norm1 + norm2 + norm3 + norm4);
}

void GerstnerWaves4_half(
    half2 Position,
    half Time,
    half2 Dir1, half Wavelength1, half Amplitude1, half Steepness1, half Speed1,
    half2 Dir2, half Wavelength2, half Amplitude2, half Steepness2, half Speed2,
    half2 Dir3, half Wavelength3, half Amplitude3, half Steepness3, half Speed3,
    half2 Dir4, half Wavelength4, half Amplitude4, half Steepness4, half Speed4,
    out half3 Displacement,
    out half3 Normal)
{
    half3 disp1, disp2, disp3, disp4;
    half3 norm1, norm2, norm3, norm4;
    
    // Wave 1
    half2 d1 = normalize(Dir1);
    half w1 = TWO_PI / max(Wavelength1, (half)0.001);
    half phi1 = Speed1 * w1;
    half Q1 = Steepness1 / (w1 * Amplitude1 + (half)0.001);
    half phase1 = w1 * dot(d1, Position) + phi1 * Time;
    disp1.x = Q1 * Amplitude1 * d1.x * cos(phase1);
    disp1.y = Amplitude1 * sin(phase1);
    disp1.z = Q1 * Amplitude1 * d1.y * cos(phase1);
    half WA1 = w1 * Amplitude1;
    norm1.x = -d1.x * WA1 * cos(phase1);
    norm1.y = (half)1.0 - Q1 * WA1 * sin(phase1);
    norm1.z = -d1.y * WA1 * cos(phase1);
    
    // Wave 2
    half2 d2 = normalize(Dir2);
    half w2 = TWO_PI / max(Wavelength2, (half)0.001);
    half phi2 = Speed2 * w2;
    half Q2 = Steepness2 / (w2 * Amplitude2 + (half)0.001);
    half phase2 = w2 * dot(d2, Position) + phi2 * Time;
    disp2.x = Q2 * Amplitude2 * d2.x * cos(phase2);
    disp2.y = Amplitude2 * sin(phase2);
    disp2.z = Q2 * Amplitude2 * d2.y * cos(phase2);
    half WA2 = w2 * Amplitude2;
    norm2.x = -d2.x * WA2 * cos(phase2);
    norm2.y = (half)1.0 - Q2 * WA2 * sin(phase2);
    norm2.z = -d2.y * WA2 * cos(phase2);
    
    // Wave 3
    half2 d3 = normalize(Dir3);
    half w3 = TWO_PI / max(Wavelength3, (half)0.001);
    half phi3 = Speed3 * w3;
    half Q3 = Steepness3 / (w3 * Amplitude3 + (half)0.001);
    half phase3 = w3 * dot(d3, Position) + phi3 * Time;
    disp3.x = Q3 * Amplitude3 * d3.x * cos(phase3);
    disp3.y = Amplitude3 * sin(phase3);
    disp3.z = Q3 * Amplitude3 * d3.y * cos(phase3);
    half WA3 = w3 * Amplitude3;
    norm3.x = -d3.x * WA3 * cos(phase3);
    norm3.y = (half)1.0 - Q3 * WA3 * sin(phase3);
    norm3.z = -d3.y * WA3 * cos(phase3);
    
    // Wave 4
    half2 d4 = normalize(Dir4);
    half w4 = TWO_PI / max(Wavelength4, (half)0.001);
    half phi4 = Speed4 * w4;
    half Q4 = Steepness4 / (w4 * Amplitude4 + (half)0.001);
    half phase4 = w4 * dot(d4, Position) + phi4 * Time;
    disp4.x = Q4 * Amplitude4 * d4.x * cos(phase4);
    disp4.y = Amplitude4 * sin(phase4);
    disp4.z = Q4 * Amplitude4 * d4.y * cos(phase4);
    half WA4 = w4 * Amplitude4;
    norm4.x = -d4.x * WA4 * cos(phase4);
    norm4.y = (half)1.0 - Q4 * WA4 * sin(phase4);
    norm4.z = -d4.y * WA4 * cos(phase4);
    
    Displacement = disp1 + disp2 + disp3 + disp4;
    Normal = normalize(norm1 + norm2 + norm3 + norm4);
}

#endif // GERSTNER_WAVE_INCLUDED
