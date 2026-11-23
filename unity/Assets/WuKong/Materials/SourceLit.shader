Shader "WuKong/Source Lit"
{
    Properties
    {
        [MainTexture] _BaseMap("Base colour", 2D) = "white" {}
        [MainColor] _BaseColor("Base colour factor", Color) = (1,1,1,1)
        _BumpMap("Normal", 2D) = "bump" {}
        _BumpScale("Normal scale", Float) = 1
        _MetallicGlossMap("Metalness / smoothness", 2D) = "white" {}
        _Metallic("Metalness", Range(0,1)) = 0
        _Smoothness("Smoothness", Range(0,1)) = 0
        _OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Occlusion strength", Range(0,1)) = 1
        _EmissionMap("Emission", 2D) = "white" {}
        _EmissionColor("Emission factor", Color) = (0,0,0,1)
        _Cutoff("Alpha cutoff", Range(0,1)) = .5
        [HideInInspector] _SpecColor("Specular", Color) = (.2,.2,.2,1)
        [HideInInspector] _Surface("Surface", Float) = 0
        [HideInInspector] _AlphaClip("Alpha clip", Float) = 0
        [HideInInspector] _Blend("Blend", Float) = 0
        [HideInInspector] _SrcBlend("Source blend", Float) = 1
        [HideInInspector] _DstBlend("Destination blend", Float) = 0
        [HideInInspector] _ZWrite("Depth write", Float) = 1
        [HideInInspector] _Cull("Cull", Float) = 2
        [HideInInspector] _ReceiveShadows("Receive shadows", Float) = 1
        [HideInInspector] _WorkflowMode("Workflow", Float) = 1
        [HideInInspector] _SmoothnessTextureChannel("Smoothness channel", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex SourceVertex
            #pragma fragment SourceFragment
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _METALLICSPECGLOSSMAP
            #pragma shader_feature_local _OCCLUSIONMAP
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                half4 color : COLOR;
                half4 fogAndLight : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            Varyings SourceVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                VertexPositionInputs position = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normal = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.positionCS = position.positionCS;
                output.positionWS = position.positionWS;
                output.normalWS = normal.normalWS;
                output.tangentWS = half4(normal.tangentWS, input.tangentOS.w * GetOddNegativeScale());
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.color = input.color;
                output.fogAndLight = half4(ComputeFogFactor(position.positionCS.z), VertexLighting(position.positionWS, normal.normalWS));
                return output;
            }
            half4 SourceFragment(Varyings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                SurfaceData surface;
                InitializeStandardLitSurfaceData(input.uv, surface);
                surface.albedo *= input.color.rgb;
                surface.alpha *= input.color.a;
                #if defined(_ALPHATEST_ON)
                    clip(surface.alpha - _Cutoff);
                #endif
                InputData data = (InputData)0;
                data.positionWS = input.positionWS;
                half3 normal = input.normalWS;
                half3 tangent = input.tangentWS.xyz;
                half3 bitangent = cross(normal, tangent) * input.tangentWS.w;
                // Three.js DoubleSide flips the shading normal on the back face.
                half faceSign = IS_FRONT_VFACE(frontFace, 1.0h, -1.0h);
                data.normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(surface.normalTS, half3x3(tangent, bitangent, normal)) * faceSign);
                data.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                data.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                data.fogCoord = input.fogAndLight.x;
                data.vertexLighting = input.fogAndLight.yzw;
                data.bakedGI = SampleSH(data.normalWS);
                data.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                data.shadowMask = half4(1,1,1,1);
                half4 color = UniversalFragmentPBR(data, surface);
                color.rgb = MixFog(color.rgb, data.fogCoord);
                color.a = OutputAlpha(color.a, _Surface);
                return color;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
