#ifndef _TESSELLATION_
#define _TESSELLATION_

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

float _TessellationUniform;

TessellationFactors patchConstantFunction(InputPatch<Attributes, 3> patch)
{
    TessellationFactors f;
    f.edge[0] = _TessellationUniform;
    f.edge[1] = _TessellationUniform;
    f.edge[2] = _TessellationUniform;
    f.inside = _TessellationUniform;
    return f;
}

[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("integer")]
[patchconstantfunc("patchConstantFunction")] 
Attributes hull(InputPatch<Attributes, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}

Attributes MyTessellationVertexProgram(Attributes v)
{
    return v;
}

[domain("tri")] 
Varyings domain(TessellationFactors factors, OutputPatch<Attributes, 3> patch, float3 barycentricCoordinates: SV_DomainLocation)
{
    Attributes data;
#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName =                                    \
                                                     patch[0].fieldName * barycentricCoordinates.x + \
                                                     patch[1].fieldName * barycentricCoordinates.y + \
                                                     patch[2].fieldName * barycentricCoordinates.z;

    MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS)
    MY_DOMAIN_PROGRAM_INTERPOLATE(normal) 
     MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
  //  MY_DOMAIN_PROGRAM_INTERPOLATE(tangentOS)
    MY_DOMAIN_PROGRAM_INTERPOLATE(color)
    MY_DOMAIN_PROGRAM_INTERPOLATE(lightmapUV)
  
     // 生成新的点后``才``进行顶点着色器的工作，而不是进行了两次
    // 输出到几何着色器或者插值
    return vert(data);
}

#endif