Shader "Custom/GerstnerWater"
{
    Properties
    {
        [Header(Water Color)]
        _ShallowColor("Shallow Color", Color) = (0.1, 0.6, 0.7, 0.95)
        _DeepColor("Deep Color", Color) = (0.0, 0.15, 0.35, 1.0)
        
        [Header(Surface)]
        _Smoothness("Smoothness", Range(0, 1)) = 0.9
        _Alpha("Alpha", Range(0, 1)) = 0.95
        
        [Header(Fresnel Reflection)]
        _FresnelPower("Fresnel Power", Range(1, 10)) = 4
        _ReflectionStrength("Reflection Strength", Range(0, 1)) = 0.4
        
        [Header(Sun Sparkle)]
        _SparkleIntensity("Sparkle Intensity", Range(0, 5)) = 2.0
        _SparklePower("Sparkle Power", Range(32, 1024)) = 256
        
        [Header(Ripple)]
        _RippleScale("Ripple Scale", Range(0.1, 2)) = 0.5
        _RippleSpeed1("Ripple Speed 1", Float) = 0.3
        _RippleSpeed2("Ripple Speed 2", Float) = -0.2
        _RippleNoiseScale1("Ripple Noise Scale 1", Float) = 20
        _RippleNoiseScale2("Ripple Noise Scale 2", Float) = 30
        _RippleStrength("Ripple Strength", Range(0, 2)) = 0.5
        
        [Header(Environment)]
        [NoScaleOffset] _ReflectionCubemap("Reflection Cubemap", Cube) = "" {}
        _UseCustomCubemap("Use Custom Cubemap", Float) = 0
        
        [Header(Wave 1 Main)]
        _Dir1("Wave 1 Direction", Vector) = (1, 0, 0, 0)
        _Wavelength1("Wave 1 Wavelength", Float) = 10
        _Amplitude1("Wave 1 Amplitude", Float) = 0.5
        _Steepness1("Wave 1 Steepness", Range(0, 1)) = 0.5
        _Speed1("Wave 1 Speed", Float) = 2
        
        [Header(Wave 2)]
        _Dir2("Wave 2 Direction", Vector) = (0.7, 0.7, 0, 0)
        _Wavelength2("Wave 2 Wavelength", Float) = 6
        _Amplitude2("Wave 2 Amplitude", Float) = 0.25
        _Steepness2("Wave 2 Steepness", Range(0, 1)) = 0.4
        _Speed2("Wave 2 Speed", Float) = 1.5
        
        [Header(Wave 3)]
        _Dir3("Wave 3 Direction", Vector) = (-0.3, 0.9, 0, 0)
        _Wavelength3("Wave 3 Wavelength", Float) = 3
        _Amplitude3("Wave 3 Amplitude", Float) = 0.1
        _Steepness3("Wave 3 Steepness", Range(0, 1)) = 0.3
        _Speed3("Wave 3 Speed", Float) = 1
        
        [Header(Wave 4)]
        _Dir4("Wave 4 Direction", Vector) = (0.5, -0.5, 0, 0)
        _Wavelength4("Wave 4 Wavelength", Float) = 1.5
        _Amplitude4("Wave 4 Amplitude", Float) = 0.05
        _Steepness4("Wave 4 Steepness", Range(0, 1)) = 0.2
        _Speed4("Wave 4 Speed", Float) = 0.8
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // ============================================
            // 定数
            // ============================================
            #define PI 3.14159265359
            #define TWO_PI 6.28318530718
            
            // ============================================
            // プロパティ
            // ============================================
            CBUFFER_START(UnityPerMaterial)
                float4 _ShallowColor;
                float4 _DeepColor;
                float _Smoothness;
                float _Alpha;
                float _FresnelPower;
                float _ReflectionStrength;
                float _UseCustomCubemap;
                
                // Sparkle
                float _SparkleIntensity;
                float _SparklePower;
                
                // Ripple
                float _RippleScale;
                float _RippleSpeed1;
                float _RippleSpeed2;
                float _RippleNoiseScale1;
                float _RippleNoiseScale2;
                float _RippleStrength;
                
                // Wave parameters
                float4 _Dir1;
                float _Wavelength1;
                float _Amplitude1;
                float _Steepness1;
                float _Speed1;
                
                float4 _Dir2;
                float _Wavelength2;
                float _Amplitude2;
                float _Steepness2;
                float _Speed2;
                
                float4 _Dir3;
                float _Wavelength3;
                float _Amplitude3;
                float _Steepness3;
                float _Speed3;
                
                float4 _Dir4;
                float _Wavelength4;
                float _Amplitude4;
                float _Steepness4;
                float _Speed4;
            CBUFFER_END
            
            TEXTURECUBE(_ReflectionCubemap);
            SAMPLER(sampler_ReflectionCubemap);
            
            // ============================================
            // 構造体
            // ============================================
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float waveHeight : TEXCOORD3;
                float fogFactor : TEXCOORD4;
                float2 noiseUV : TEXCOORD5;
            };
            
            // ============================================
            // Gradient Noise (Perlin風)
            // ============================================
            float2 GradientNoiseDir(float2 p)
            {
                p = p % 289;
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }
            
            float GradientNoise(float2 p, float scale)
            {
                p *= scale;
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(GradientNoiseDir(ip), fp);
                float d01 = dot(GradientNoiseDir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(GradientNoiseDir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(GradientNoiseDir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
            }
            
            // ============================================
            // Normal From Height
            // ============================================
            float3 NormalFromHeight(float2 uv, float scale1, float scale2, float time, float strength)
            {
                float2 offset = float2(0.01, 0);
                
                // UV1 (スクロール1)
                float2 uv1 = uv + time * _RippleSpeed1;
                // UV2 (スクロール2)
                float2 uv2 = uv + time * _RippleSpeed2;
                
                // 2つのノイズを合成
                float h = (GradientNoise(uv1, scale1) + GradientNoise(uv2, scale2)) * 0.5;
                float hx = (GradientNoise(uv1 + offset.xy, scale1) + GradientNoise(uv2 + offset.xy, scale2)) * 0.5;
                float hy = (GradientNoise(uv1 + offset.yx, scale1) + GradientNoise(uv2 + offset.yx, scale2)) * 0.5;
                
                float3 normal;
                normal.x = (h - hx) * strength;
                normal.z = (h - hy) * strength;
                normal.y = 1;
                
                return normalize(normal);
            }
            
            // ============================================
            // Gerstner Wave 計算
            // ============================================
            void CalculateGerstnerWave(
                float2 position,
                float time,
                float2 direction,
                float wavelength,
                float amplitude,
                float steepness,
                float speed,
                inout float3 displacement,
                inout float3 normal)
            {
                float2 dir = normalize(direction);
                float w = TWO_PI / max(wavelength, 0.001);
                float phi = speed * w;
                float Q = steepness / (w * amplitude + 0.001);
                float phase = w * dot(dir, position) + phi * time;
                
                float sinPhase = sin(phase);
                float cosPhase = cos(phase);
                
                // 変位を加算
                displacement.x += Q * amplitude * dir.x * cosPhase;
                displacement.y += amplitude * sinPhase;
                displacement.z += Q * amplitude * dir.y * cosPhase;
                
                // 法線を加算
                float WA = w * amplitude;
                normal.x += -dir.x * WA * cosPhase;
                normal.y += 1.0 - Q * WA * sinPhase;
                normal.z += -dir.y * WA * cosPhase;
            }
            
            void CalculateGerstnerWaves4(
                float2 position,
                float time,
                out float3 displacement,
                out float3 normal)
            {
                displacement = float3(0, 0, 0);
                normal = float3(0, 0, 0);
                
                CalculateGerstnerWave(position, time, _Dir1.xy, _Wavelength1, _Amplitude1, _Steepness1, _Speed1, displacement, normal);
                CalculateGerstnerWave(position, time, _Dir2.xy, _Wavelength2, _Amplitude2, _Steepness2, _Speed2, displacement, normal);
                CalculateGerstnerWave(position, time, _Dir3.xy, _Wavelength3, _Amplitude3, _Steepness3, _Speed3, displacement, normal);
                CalculateGerstnerWave(position, time, _Dir4.xy, _Wavelength4, _Amplitude4, _Steepness4, _Speed4, displacement, normal);
                
                normal = normalize(normal);
            }
            
            // ============================================
            // Fresnel 計算
            // ============================================
            float CalculateFresnel(float3 normal, float3 viewDir, float power)
            {
                return pow(1.0 - saturate(dot(normal, viewDir)), power);
            }
            
            // ============================================
            // 頂点シェーダー
            // ============================================
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // ワールド座標を取得
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                // Gerstner Wave を計算
                float3 displacement;
                float3 waveNormal;
                CalculateGerstnerWaves4(positionWS.xz, _Time.y, displacement, waveNormal);
                
                // 変位を適用
                positionWS += displacement;
                
                // 出力
                output.positionCS = TransformWorldToHClip(positionWS);
                output.positionWS = positionWS;
                output.normalWS = waveNormal;
                output.viewDirWS = normalize(GetCameraPositionWS() - positionWS);
                output.waveHeight = displacement.y;
                output.fogFactor = ComputeFogFactor(output.positionCS.z);
                output.noiseUV = positionWS.xz * _RippleScale;
                
                return output;
            }
            
            // ============================================
            // フラグメントシェーダー
            // ============================================
            half4 frag(Varyings input) : SV_Target
            {
                // 波の法線
                float3 waveNormal = normalize(input.normalWS);
                
                // ゆらぎ法線を計算
                float3 rippleNormal = NormalFromHeight(
                    input.noiseUV, 
                    _RippleNoiseScale1, 
                    _RippleNoiseScale2, 
                    _Time.y, 
                    _RippleStrength
                );
                
                // 法線を合成
                float3 normalWS = normalize(waveNormal + rippleNormal);
                
                float3 viewDirWS = normalize(input.viewDirWS);
                
                // 波の高さで色を補間
                float totalAmplitude = _Amplitude1 + _Amplitude2 + _Amplitude3 + _Amplitude4;
                float heightFactor = saturate((input.waveHeight / totalAmplitude) * 0.5 + 0.5);
                heightFactor = smoothstep(0, 1, heightFactor);
                float4 waterColor = lerp(_DeepColor, _ShallowColor, heightFactor);
                
                // Fresnel
                float fresnel = CalculateFresnel(normalWS, viewDirWS, _FresnelPower);
                fresnel *= _ReflectionStrength;
                
                // 反射
                float3 reflectDir = reflect(-viewDirWS, normalWS);
                float3 reflectionColor;
                
                if (_UseCustomCubemap > 0.5)
                {
                    reflectionColor = SAMPLE_TEXTURECUBE(_ReflectionCubemap, sampler_ReflectionCubemap, reflectDir).rgb;
                }
                else
                {
                    reflectionColor = GlossyEnvironmentReflection(reflectDir, 0, 1.0);
                }
                
                // 水の色と反射を混合
                float3 finalColor = lerp(waterColor.rgb, reflectionColor, fresnel);
                
                // ライティング
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                float3 diffuse = finalColor * mainLight.color * (NdotL * 0.5 + 0.5);
                
                // 太陽スペキュラ（きらきら）
                float3 reflectedLight = reflect(-mainLight.direction, normalWS);
                float specDot = saturate(dot(reflectedLight, viewDirWS));
                float sparkle = pow(specDot, _SparklePower) * _SparkleIntensity;
                
                // スペキュラハイライト
                float3 halfDir = normalize(mainLight.direction + viewDirWS);
                float NdotH = saturate(dot(normalWS, halfDir));
                float specular = pow(NdotH, _Smoothness * 128.0) * _Smoothness;
                
                // 最終色
                float3 color = diffuse + (specular + sparkle) * mainLight.color;
                
                // フォグ適用
                color = MixFog(color, input.fogFactor);
                
                // アルファ
                float alpha = lerp(_Alpha, 1.0, fresnel * 0.5);
                
                return half4(color, alpha);
            }
            
            ENDHLSL
        }
        
        // シャドウキャスターパス
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #define PI 3.14159265359
            #define TWO_PI 6.28318530718
            
            CBUFFER_START(UnityPerMaterial)
                float4 _ShallowColor;
                float4 _DeepColor;
                float _Smoothness;
                float _Alpha;
                float _FresnelPower;
                float _ReflectionStrength;
                float _UseCustomCubemap;
                float _SparkleIntensity;
                float _SparklePower;
                float _RippleScale;
                float _RippleSpeed1;
                float _RippleSpeed2;
                float _RippleNoiseScale1;
                float _RippleNoiseScale2;
                float _RippleStrength;
                
                float4 _Dir1;
                float _Wavelength1;
                float _Amplitude1;
                float _Steepness1;
                float _Speed1;
                
                float4 _Dir2;
                float _Wavelength2;
                float _Amplitude2;
                float _Steepness2;
                float _Speed2;
                
                float4 _Dir3;
                float _Wavelength3;
                float _Amplitude3;
                float _Steepness3;
                float _Speed3;
                
                float4 _Dir4;
                float _Wavelength4;
                float _Amplitude4;
                float _Steepness4;
                float _Speed4;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            void CalculateGerstnerWaveShadow(
                float2 position,
                float time,
                float2 direction,
                float wavelength,
                float amplitude,
                float steepness,
                float speed,
                inout float3 displacement)
            {
                float2 dir = normalize(direction);
                float w = TWO_PI / max(wavelength, 0.001);
                float phi = speed * w;
                float Q = steepness / (w * amplitude + 0.001);
                float phase = w * dot(dir, position) + phi * time;
                
                float sinPhase = sin(phase);
                float cosPhase = cos(phase);
                
                displacement.x += Q * amplitude * dir.x * cosPhase;
                displacement.y += amplitude * sinPhase;
                displacement.z += Q * amplitude * dir.y * cosPhase;
            }
            
            Varyings ShadowVert(Attributes input)
            {
                Varyings output;
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                float3 displacement = float3(0, 0, 0);
                CalculateGerstnerWaveShadow(positionWS.xz, _Time.y, _Dir1.xy, _Wavelength1, _Amplitude1, _Steepness1, _Speed1, displacement);
                CalculateGerstnerWaveShadow(positionWS.xz, _Time.y, _Dir2.xy, _Wavelength2, _Amplitude2, _Steepness2, _Speed2, displacement);
                CalculateGerstnerWaveShadow(positionWS.xz, _Time.y, _Dir3.xy, _Wavelength3, _Amplitude3, _Steepness3, _Speed3, displacement);
                CalculateGerstnerWaveShadow(positionWS.xz, _Time.y, _Dir4.xy, _Wavelength4, _Amplitude4, _Steepness4, _Speed4, displacement);
                
                positionWS += displacement;
                
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }
            
            half4 ShadowFrag(Varyings input) : SV_Target
            {
                return 0;
            }
            
            ENDHLSL
        }
        
        // 深度パス
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #define PI 3.14159265359
            #define TWO_PI 6.28318530718
            
            CBUFFER_START(UnityPerMaterial)
                float4 _ShallowColor;
                float4 _DeepColor;
                float _Smoothness;
                float _Alpha;
                float _FresnelPower;
                float _ReflectionStrength;
                float _UseCustomCubemap;
                float _SparkleIntensity;
                float _SparklePower;
                float _RippleScale;
                float _RippleSpeed1;
                float _RippleSpeed2;
                float _RippleNoiseScale1;
                float _RippleNoiseScale2;
                float _RippleStrength;
                
                float4 _Dir1;
                float _Wavelength1;
                float _Amplitude1;
                float _Steepness1;
                float _Speed1;
                
                float4 _Dir2;
                float _Wavelength2;
                float _Amplitude2;
                float _Steepness2;
                float _Speed2;
                
                float4 _Dir3;
                float _Wavelength3;
                float _Amplitude3;
                float _Steepness3;
                float _Speed3;
                
                float4 _Dir4;
                float _Wavelength4;
                float _Amplitude4;
                float _Steepness4;
                float _Speed4;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            void CalculateGerstnerWaveDepth(
                float2 position,
                float time,
                float2 direction,
                float wavelength,
                float amplitude,
                float steepness,
                float speed,
                inout float3 displacement)
            {
                float2 dir = normalize(direction);
                float w = TWO_PI / max(wavelength, 0.001);
                float phi = speed * w;
                float Q = steepness / (w * amplitude + 0.001);
                float phase = w * dot(dir, position) + phi * time;
                
                float sinPhase = sin(phase);
                float cosPhase = cos(phase);
                
                displacement.x += Q * amplitude * dir.x * cosPhase;
                displacement.y += amplitude * sinPhase;
                displacement.z += Q * amplitude * dir.y * cosPhase;
            }
            
            Varyings DepthVert(Attributes input)
            {
                Varyings output;
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                float3 displacement = float3(0, 0, 0);
                CalculateGerstnerWaveDepth(positionWS.xz, _Time.y, _Dir1.xy, _Wavelength1, _Amplitude1, _Steepness1, _Speed1, displacement);
                CalculateGerstnerWaveDepth(positionWS.xz, _Time.y, _Dir2.xy, _Wavelength2, _Amplitude2, _Steepness2, _Speed2, displacement);
                CalculateGerstnerWaveDepth(positionWS.xz, _Time.y, _Dir3.xy, _Wavelength3, _Amplitude3, _Steepness3, _Speed3, displacement);
                CalculateGerstnerWaveDepth(positionWS.xz, _Time.y, _Dir4.xy, _Wavelength4, _Amplitude4, _Steepness4, _Speed4, displacement);
                
                positionWS += displacement;
                
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }
            
            half4 DepthFrag(Varyings input) : SV_Target
            {
                return 0;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
