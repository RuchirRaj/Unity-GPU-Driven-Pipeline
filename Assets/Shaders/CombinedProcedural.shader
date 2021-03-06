﻿ Shader "Maxwell/CombinedProcedural" {
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		
	// ------------------------------------------------------------
	// Surface shader code generated out of a CGPROGRAM block:
CGINCLUDE
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#pragma target 5.0
#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityShaderUtilities.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityMetaPass.cginc"
#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"
#include "CGINC/Procedural.cginc"
	Texture2DArray<float4> _MainTex; SamplerState sampler_MainTex;
  Texture2DArray<float3> _LightMap; SamplerState sampler_LightMap;
	StructuredBuffer<PropertyValue> _PropertiesBuffer;


	//Return: 1: not using lightmap 0: using lightmap
	float surf (float2 uv, float2 lightmapUV, int lightmapIndex, uint index, inout SurfaceOutputStandardSpecular o) {
		PropertyValue prop = _PropertiesBuffer[index];
    float2 detailUV = uv * prop.detailScaleOffset.xy + prop.detailScaleOffset.zw;
    float4 detailAlbedo = 0;
    float3 detailNormal = 0;
    int usedetail = 1;
    if(prop.detailTextureIndex.x >= 0)
    {
      detailAlbedo = _MainTex.Sample(sampler_MainTex, float3(detailUV, prop.detailTextureIndex.x));
    }else{
      usedetail--;
    }
    if(prop.detailTextureIndex.y >= 0)
    {
      detailNormal = UnpackNormal(_MainTex.Sample(sampler_MainTex, float3(detailUV, prop.detailTextureIndex.y)));
    }else{
      usedetail--;
    }
    uv *= prop.mainScaleOffset.xy;
    uv += prop.mainScaleOffset.zw;
    float4 spec = prop.textureIndex.z >= 0 ? _MainTex.Sample(sampler_MainTex, float3(uv, prop.textureIndex.z)) : 1;
		float4 c = (prop.textureIndex.x >= 0 ? _MainTex.Sample(sampler_MainTex, float3(uv, prop.textureIndex.x)) : 1);
    c.a = usedetail < 0 ? 1 : c.a;
    if(prop.textureIndex.y >= 0){
			o.Normal =  UnpackNormal(_MainTex.Sample(sampler_MainTex, float3(uv, prop.textureIndex.y)));
		}else{
			o.Normal =  float3(0,0,1);
		}
    float uselightmap = 1;
    if(lightmapIndex >= 0)
    {
      uselightmap = 0;
      o.Emission.rgb = _LightMap.Sample(sampler_LightMap, float3(lightmapUV, lightmapIndex)) * c.rgb;
    }   
		o.Albedo = c.rgb;
    o.Albedo = lerp(detailAlbedo.rgb, o.Albedo, c.a) * prop._Color;
		o.Alpha = 1;
		o.Specular = lerp(prop._SpecularIntensity * spec.g, o.Albedo * prop._SpecularIntensity * spec.g, prop._MetallicIntensity); 
		o.Smoothness = prop._Glossiness * spec.r;
    o.Occlusion = lerp(1, spec.b, prop._Occlusion);
		o.Emission += prop._EmissionColor;
    o.Normal = lerp(detailNormal, o.Normal, c.a);
    return uselightmap;
	}


#define GetScreenPos(pos) ((float2(pos.x, pos.y) * 0.5) / pos.w + 0.5)


float4 ProceduralStandardSpecular_Deferred (SurfaceOutputStandardSpecular s, float3 viewDir, out float4 outGBuffer0, out float4 outGBuffer1, out float4 outGBuffer2)
{
    // energy conservation
    float oneMinusReflectivity;
    s.Albedo = EnergyConservationBetweenDiffuseAndSpecular (s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);
    // RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
    outGBuffer0 = float4(s.Albedo, s.Occlusion);
    // RT1: spec color (rgb), smoothness (a) - sRGB rendertarget
    outGBuffer1 = float4(s.Specular, s.Smoothness);
    // RT2: normal (rgb), --unused, very low precision-- (a)
    outGBuffer2 = float4(s.Normal * 0.5f + 0.5f, 0);
    float4 emission = float4(s.Emission, 1);
    return emission;
}

float4x4 _LastVp;
float4x4 _NonJitterVP;
inline float2 CalculateMotionVector(float4x4 lastvp, float3 worldPos, float2 screenUV)
{
	float4 lastScreenPos = mul(lastvp, float4(worldPos, 1));
	float2 lastScreenUV = GetScreenPos(lastScreenPos);
	return screenUV - lastScreenUV;
}

struct v2f_surf {
  UNITY_POSITION(pos);
  float4 pack0 : TEXCOORD0; 
  float4 worldTangent : TEXCOORD1;
  float4 worldBinormal : TEXCOORD2;
  float4 worldNormal : TEXCOORD3;
  float3 worldViewDir : TEXCOORD4;
  nointerpolation uint objectIndex : TEXCOORD5;
  nointerpolation int lightmapIndex : TEXCOORD6;
};
float4 _MainTex_ST;
v2f_surf vert_surf (uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID) 
{
  	Point v = getVertex(vertexID, instanceID);
  	v2f_surf o;
  	o.pack0.xy = v.texcoord;
    o.pack0.zw = v.lightmapUV;
	o.objectIndex = v.objIndex;
  o.lightmapIndex = v.lightmapIndex;
  	o.pos = mul(UNITY_MATRIX_VP, float4(v.vertex, 1));
  	o.worldTangent = float4( v.tangent.xyz, v.vertex.x);
	o.worldNormal =float4(v.normal, v.vertex.z);
  	float tangentSign = v.tangent.w;
  	o.worldBinormal = float4(cross(v.normal, o.worldTangent.xyz) * tangentSign, v.vertex.y);
  	o.worldViewDir = UnityWorldSpaceViewDir(v.vertex);
    
  	return o;
}
float4x4 _VP;
v2f_surf vert_gbuffer (uint vertexID : SV_VertexID, uint instanceID : SV_InstanceID) 
{
  	Point v = getVertex(vertexID, instanceID);
  	v2f_surf o;
  	o.pack0.xy = v.texcoord;
    o.pack0.zw = v.lightmapUV;
	o.objectIndex = v.objIndex;
  o.lightmapIndex = v.lightmapIndex;
  	o.pos = mul(_VP, float4(v.vertex, 1));
  	o.worldTangent = float4( v.tangent.xyz, v.vertex.x);
	o.worldNormal =float4(v.normal, v.vertex.z);
  	float tangentSign = v.tangent.w;
  	o.worldBinormal = float4(cross(v.normal, o.worldTangent.xyz) * tangentSign, v.vertex.y);
  	o.worldViewDir = UnityWorldSpaceViewDir(v.vertex);
  	return o;
}
float3 _SceneOffset;

// fragment shader
void frag_surf (v2f_surf IN,
    out float4 outGBuffer0 : SV_Target0,
    out float4 outGBuffer1 : SV_Target1,
    out float4 outGBuffer2 : SV_Target2,
    out float4 outEmission : SV_Target3,
	out float2 outMotionVector : SV_Target4,
  out float depth : SV_TARGET5
) {
  depth = IN.pos.z;
  // prepare and unpack data
  float3 worldPos = float3(IN.worldTangent.w, IN.worldBinormal.w, IN.worldNormal.w);
  float3 worldViewDir = normalize(IN.worldViewDir);
  SurfaceOutputStandardSpecular o;
  float3x3 wdMatrix= float3x3(normalize(IN.worldTangent.xyz), normalize(IN.worldBinormal.xyz), normalize(IN.worldNormal.xyz));
  // call surface function
  float uselightmap = surf (IN.pack0.xy, IN.pack0.zw, IN.lightmapIndex, IN.objectIndex, o);
  o.Normal = normalize(mul(o.Normal, wdMatrix));
  outEmission = ProceduralStandardSpecular_Deferred (o, worldViewDir, outGBuffer0, outGBuffer1, outGBuffer2); //GI neccessary here!
  //Calculate Motion Vector
  float4 screenPos = mul(_NonJitterVP, float4(worldPos, 1));
  float2 screenUV = GetScreenPos(screenPos);
  outMotionVector = CalculateMotionVector(_LastVp, worldPos - _SceneOffset, screenUV);
  outGBuffer2.a = uselightmap;
}


float3 frag_gi (v2f_surf IN) : SV_TARGET{
  // prepare and unpack data
  float3 worldPos = float3(IN.worldTangent.w, IN.worldBinormal.w, IN.worldNormal.w);
  float3 worldViewDir = normalize(IN.worldViewDir);
  SurfaceOutputStandardSpecular o;
  float3x3 wdMatrix= float3x3(normalize(IN.worldTangent.xyz), normalize(IN.worldBinormal.xyz), normalize(IN.worldNormal.xyz));
  // call surface function
  surf (IN.pack0.xy, IN.pack0.zw, IN.lightmapIndex, IN.objectIndex, o);
  return o.Emission;
  //TODO
}

ENDCG

//Pass 0 deferred
Pass {
stencil{
  Ref 1
  comp always
  pass replace
}
ZTest Less
CGPROGRAM

#pragma vertex vert_surf
#pragma fragment frag_surf
#pragma exclude_renderers nomrt
ENDCG
}

Pass {
ZTest Less
Cull off
CGPROGRAM

#pragma vertex vert_gbuffer
#pragma fragment frag_gi
#pragma exclude_renderers nomrt
ENDCG
}
}
}

