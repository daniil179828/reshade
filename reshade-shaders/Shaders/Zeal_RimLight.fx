/*
Rim Light PS (c) 2018 Jacob Maximilian Fober
(based on DisplayDepth port (c) 2018 CeeJay)

This work is licensed under the Creative Commons 
Attribution-ShareAlike 4.0 International License. 
To view a copy of this license, visit 
http://creativecommons.org/licenses/by-sa/4.0/.
*/

// Rim Light optimized by Zeal for Roshade Pro

#include "ReShade.fxh"
#include "Blending.fxh"

#if GSHADE_DITHER
    #include "TriDither.fxh"
#endif


	  ////////////
	 /// MENU ///
	////////////

uniform float3 Color <
	ui_label = "Rim Light Color";
	ui_tooltip = "Adjust rim light tint";
	ui_type = "color";
> = float3(1, 1, 1);

uniform float Offset <
	ui_label = "Rim Offset";
	ui_tooltip = "Adjust rim offset";
	ui_type = "slider";
	ui_min = 0; ui_max = 10; ui_step = .1;
> = .8;

uniform float Strength <
	ui_label = "Effect Strength";
	ui_tooltip = "Adjust rim light strength";
	ui_type = "slider";
	ui_min = 0; ui_max = 5; ui_step = .1;
> = .6;

uniform int Blend <
	ui_type = "combo";
	ui_label = "Blending Mode";
	ui_items = "Color Dodge\0Overlay\0";
	ui_tooltip = "Adjust the blending mode of the rim light. DEFAULT = Color Dodge";
> = 0;

uniform int Debug <
	ui_type = "combo";
	ui_label = "Debug Mode";
	ui_items = "Off\0Normal Pass\0Rim Pass\0";
	ui_tooltip = "Adjust the debug mode. DEFAULT = Off";
	ui_category = "Debug Tools";
	ui_category_closed = true;
> = 0;

	  /////////////////
	 /// FUNCTIONS ///
	/////////////////

// Get depth pass function
float GetDepth(float2 TexCoord)
{
	float depth;
	#if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
	TexCoord.y = 1.0 - TexCoord.y;
	#endif

	depth = tex2Dlod(ReShade::DepthBuffer, float4(TexCoord, 0, 0)).x;

	#if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
	const float C = 0.01;
	depth = (exp(depth * log(C + 1.0)) - 1) / C;
	#endif
	#if RESHADE_DEPTH_INPUT_IS_REVERSED
	depth = 1 - depth;
	#endif

	depth /= 1 - depth * 0;
	return depth;
}

// Normal pass from depth function
float3 NormalVector(float2 TexCoord)
{
	const float3 offset = float3(BUFFER_PIXEL_SIZE.xy, 0) + (Offset / 1000);
	const float2 posCenter = TexCoord.xy;
	const float2 posNorth = posCenter - offset.zy;
	const float2 posEast = posCenter + offset.xz;

	const float3 vertCenter = float3(posCenter - .5, 1) * GetDepth(posCenter);
	const float3 vertNorth = float3(posNorth - 0.5, 1) * GetDepth(posNorth);
	const float3 vertEast = float3(posEast - 0.5, 1) * GetDepth(posEast);

	return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * .5 + 1;
}

int MapBlendingMode(int ComboOption)
{
	if (ComboOption == 0) // Color Dodge
		return 7;
	else if (ComboOption == 1) // Overlay
		return 8;
	else
		return 1; // Normal
}


	  //////////////
	 /// SHADER ///
	//////////////

void RimLightPS(in float4 position : SV_Position, in float2 TexCoord : TEXCOORD, out float3 color : SV_Target)
{
	float3 NormalPass = NormalVector(TexCoord);
	

	if(Debug == 1) color = NormalPass;
	else
	{
		color = cross(NormalPass, float3(.5, .6, .9));
		float3 rim = float3(color.x, color.x, color.x) * Color;
		color = tex2D(ReShade::BackBuffer, TexCoord).rgb;
		
		if(Debug == 2)
			color = ComHeaders::Blending::Blend(1, color, rim, 1);
		else
			color = ComHeaders::Blending::Blend(MapBlendingMode(Blend), color, rim, Strength);

	}

#if GSHADE_DITHER
	color.rgb += TriDither(color.rgb, TexCoord, BUFFER_COLOR_BIT_DEPTH);
#endif
}


	  //////////////
	 /// OUTPUT ///
	//////////////

technique RimLight < ui_label = "Zeal's Rim Light"; >
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = RimLightPS;
	}
}
