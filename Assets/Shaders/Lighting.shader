﻿Shader "Hidden/Lighting"
{
    SubShader
    {
        CGINCLUDE
        #pragma target 5.0

	#include "UnityCG.cginc"
	#include "UnityPBSLighting.cginc"
	#include "CGINC/VoxelLight.cginc"
	#include "CGINC/Shader_Include/Common.hlsl"
	#include "CGINC/Random.cginc"
	#include "CGINC/Shader_Include/BSDF_Library.hlsl"
	#include "CGINC/Shader_Include/AreaLight.hlsl"
	#include "CGINC/Lighting.cginc"
	#include "CGINC/Sunlight.cginc"
    #include "CGINC/VolumetricLight.cginc"
	#pragma multi_compile _ ENABLE_SUN
	#pragma multi_compile _ ENABLE_SUNSHADOW
	#pragma multi_compile _ POINTLIGHT
	#pragma multi_compile _ SPOTLIGHT
    #pragma multi_compile _ EnableGTAO
			float4x4 _InvVP;
			
			Texture2D<float4> _CameraGBufferTexture0; SamplerState sampler_CameraGBufferTexture0;
			Texture2D<float4> _CameraGBufferTexture1; SamplerState sampler_CameraGBufferTexture1;
			Texture2D<float4> _CameraGBufferTexture2; SamplerState sampler_CameraGBufferTexture2;
			Texture2D<float> _CameraDepthTexture; SamplerState sampler_CameraDepthTexture;
            Texture2D<float2> _AOROTexture; SamplerState sampler_AOROTexture;
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                return o;
            }

        ENDCG
        Pass
        {
            Cull Off ZWrite Off ZTest Greater
            Blend one one
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
	
            float3 frag (v2f i) : SV_Target
            {
                float4 gbuffer0 = _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, i.uv);
    			float4 gbuffer1 = _CameraGBufferTexture1.Sample(sampler_CameraGBufferTexture1, i.uv);
    			float4 gbuffer2 = _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, i.uv);
				float depth = _CameraDepthTexture.Sample(sampler_CameraDepthTexture, i.uv);
                
				float4 wpos = mul(_InvVP, float4(i.uv * 2 - 1, depth, 1));
                wpos /= wpos.w;
                float2 aoro = gbuffer0.a;
				#if EnableGTAO
				aoro = min(aoro, _AOROTexture.Sample(sampler_AOROTexture, i.uv));
                #endif
				float3 viewDir = normalize(wpos.xyz - _WorldSpaceCameraPos);
				UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);
                float roughness = clamp(1 - data.smoothness, 0.02, 1);
                float linearEyeDepth = LinearEyeDepth(depth);
                float3 finalColor = 0;
                #if ENABLE_SUN
				#if ENABLE_SUNSHADOW
					finalColor += CalculateSunLight(data, depth, wpos, viewDir);
				#else
					finalColor += CalculateSunLight_NoShadow(data, viewDir);
				#endif
                #endif
                #if SPOTLIGHT || POINTLIGHT
				finalColor += CalculateLocalLight(i.uv, wpos, linearEyeDepth, data.diffuseColor, data.normalWorld, gbuffer1, roughness, -viewDir);
                #endif
                
                return finalColor;
            }
            ENDCG
        }

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Blend oneminusSrcalpha srcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
	
            float4 frag (v2f i) : SV_Target
            {
             
				float depth = _CameraDepthTexture.Sample(sampler_CameraDepthTexture, i.uv);
                float linear01Depth = Linear01Depth(depth);
				return Fog(linear01Depth, i.uv);
            }
            ENDCG
        }
    }
}
