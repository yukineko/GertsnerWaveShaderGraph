// WaveURP.shader
Shader "Custom/URP/WaveHeight"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (0.1, 0.3, 0.6, 1)
        _DeepColor ("Deep Color", Color) = (0.02, 0.1, 0.3, 1)
        _ShallowColor ("Shallow Color", Color) = (0.2, 0.5, 0.7, 1)
        
        [Header(Wave Settings)]
        _WaveSpeed ("Wave Speed", Float) = 1.0
        _WaveFrequency ("Wave Frequency", Float) = 2.0
        _WaveAmplitude ("Wave Amplitude", Float) = 0.3
        _WaveSteepness ("Wave Steepness", Range(0, 1)) = 0.5
        
        [Header(Wave 2)]
        _Wave2Direction ("Wave2 Direction", Vector) = (0.7, 0.7, 0, 0)
        _Wave2Frequency ("Wave2 Frequency", Float) = 3.5
        _Wave2Amplitude ("Wave2 Amplitude", Float) = 0.15
        
        [Header(Wave 3)]
        _Wave3Direction ("Wave3 Direction", Vector) = (-0.4, 0.9, 0, 0)
        _Wave3Frequency ("Wave3 Frequency", Float) = 5.0
        _Wave3Amplitude ("Wave3 Amplitude", Float) = 0.08
        
        [Header(Foam)]
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 1)
        _FoamThreshold ("Foam Threshold", Range(0, 1)) = 0.7
        
        [Header(Lighting)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.9
        _FresnelPower ("Fresnel Power", Range(1, 10)) = 4.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
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
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float waveHeight : TEXCOORD4;
                float fogFactor : TEXCOORD5;
            };
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _DeepColor;
                half4 _ShallowColor;
                
                float _WaveSpeed;
                float _WaveFrequency;
                float _WaveAmplitude;
                float _WaveSteepness;
                
                float4 _Wave2Direction;
                float _Wave2Frequency;
                float _Wave2Amplitude;
                
                float4 _Wave3Direction;
                float _Wave3Frequency;
                float _Wave3Amplitude;
                
                half4 _FoamColor;
                float _FoamThreshold;
                
                float _Smoothness;
                float _FresnelPower;
            CBUFFER_END
            
            // Gerstner波の計算
            struct GerstnerResult
            {
                float3 offset;
                float3 tangent;
                float3 binormal;
            };
            
            GerstnerResult GerstnerWave(float2 pos, float amplitude, float frequency, 
                                        float speed, float2 direction, float steepness)
            {
                GerstnerResult result;
                
                direction = normalize(direction);
                float k = TWO_PI * frequency;
                float c = sqrt(9.8 / k);
                float d = dot(direction, pos);
                float f = k * (d - c * _Time.y * speed);
                
                float a = steepness * amplitude;
                float sinF = sin(f);
                float cosF = cos(f);
                
                // 位置オフセット
                result.offset.x = direction.x * a * cosF;
                result.offset.z = direction.y * a * cosF;
                result.offset.y = amplitude * sinF;
                
                // 接線計算用
                result.tangent = float3(
                    1 - direction.x * direction.x * steepness * sinF,
                    direction.x * steepness * cosF,
                    -direction.x * direction.y * steepness * sinF
                );
                
                result.binormal = float3(
                    -direction.x * direction.y * steepness * sinF,
                    direction.y * steepness * cosF,
                    1 - direction.y * direction.y * steepness * sinF
                );
                
                return result;
            }
            
            // 複数波の合成
            void CalculateWaves(float2 pos, out float3 offset, out float3 normal)
            {
                GerstnerResult wave1 = GerstnerWave(
                    pos, _WaveAmplitude, _WaveFrequency, 
                    _WaveSpeed, float2(1, 0), _WaveSteepness
                );
                
                GerstnerResult wave2 = GerstnerWave(
                    pos, _Wave2Amplitude, _Wave2Frequency, 
                    _WaveSpeed * 1.2, _Wave2Direction.xy, _WaveSteepness * 0.8
                );
                
                GerstnerResult wave3 = GerstnerWave(
                    pos, _Wave3Amplitude, _Wave3Frequency, 
                    _WaveSpeed * 1.5, _Wave3Direction.xy, _WaveSteepness * 0.6
                );
                
                offset = wave1.offset + wave2.offset + wave3.offset;
                
                float3 tangent = wave1.tangent + wave2.tangent + wave3.tangent - float3(2, 0, 0);
                float3 binormal = wave1.binormal + wave2.binormal + wave3.binormal - float3(0, 0, 2);
                
                normal = normalize(cross(binormal, tangent));
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // ワールド座標を取得
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float2 xz = positionWS.xz;
                
                // 波の計算
                float3 waveOffset;
                float3 waveNormal;
                CalculateWaves(xz, waveOffset, waveNormal);
                
                // 位置を更新
                positionWS += waveOffset;
                
                output.positionCS = TransformWorldToHClip(positionWS);
                output.positionWS = positionWS;
                output.normalWS = waveNormal;
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(positionWS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.waveHeight = waveOffset.y;
                output.fogFactor = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // メインライト取得
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                
                // 法線とビュー方向
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = normalize(input.viewDirWS);
                
                // 高さに基づく色補間
                float heightFactor = saturate(input.waveHeight / (_WaveAmplitude * 2.0) + 0.5);
                half3 waterColor = lerp(_DeepColor.rgb, _ShallowColor.rgb, heightFactor);
                
                // フレネル効果
                float fresnel = pow(1.0 - saturate(dot(normalWS, viewDirWS)), _FresnelPower);
                
                // スペキュラ (Blinn-Phong)
                float3 halfDir = normalize(mainLight.direction + viewDirWS);
                float spec = pow(saturate(dot(normalWS, halfDir)), _Smoothness * 128.0);
                
                // ディフューズ
                float ndotl = saturate(dot(normalWS, mainLight.direction));
                
                // フォーム（白波）
                float foam = saturate((input.waveHeight / _WaveAmplitude - _FoamThreshold) / (1.0 - _FoamThreshold));
                foam = foam * foam;
                
                // 最終カラー合成
                half3 diffuse = waterColor * (ndotl * 0.5 + 0.5);
                half3 specular = mainLight.color * spec * _Smoothness;
                half3 fresnelColor = lerp(half3(0, 0, 0), half3(0.5, 0.6, 0.7), fresnel);
                
                half3 finalColor = diffuse + specular + fresnelColor;
                finalColor = lerp(finalColor, _FoamColor.rgb, foam);
                
                // シャドウ適用
                finalColor *= mainLight.shadowAttenuation;
                
                // フォグ適用
                finalColor = MixFog(finalColor, input.fogFactor);
                
                return half4(finalColor, 1.0);
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _DeepColor;
                half4 _ShallowColor;
                float _WaveSpeed;
                float _WaveFrequency;
                float _WaveAmplitude;
                float _WaveSteepness;
                float4 _Wave2Direction;
                float _Wave2Frequency;
                float _Wave2Amplitude;
                float4 _Wave3Direction;
                float _Wave3Frequency;
                float _Wave3Amplitude;
                half4 _FoamColor;
                float _FoamThreshold;
                float _Smoothness;
                float _FresnelPower;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            float3 SimpleWaveOffset(float2 pos)
            {
                float3 offset = float3(0, 0, 0);
                float t = _Time.y * _WaveSpeed;
                
                offset.y += sin(dot(pos, float2(1, 0)) * _WaveFrequency * TWO_PI + t) * _WaveAmplitude;
                offset.y += sin(dot(pos, _Wave2Direction.xy) * _Wave2Frequency * TWO_PI + t * 1.2) * _Wave2Amplitude;
                offset.y += sin(dot(pos, _Wave3Direction.xy) * _Wave3Frequency * TWO_PI + t * 1.5) * _Wave3Amplitude;
                
                return offset;
            }
            
            Varyings ShadowVert(Attributes input)
            {
                Varyings output;
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                positionWS += SimpleWaveOffset(positionWS.xz);
                
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));
                
                return output;
            }
            
            half4 ShadowFrag(Varyings input) : SV_Target
            {
                return 0;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}