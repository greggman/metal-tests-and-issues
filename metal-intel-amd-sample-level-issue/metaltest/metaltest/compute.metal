#include <metal_stdlib>
using namespace metal;

kernel void doit(device float4* result,
                 metal::texture2d<float> tex [[texture(0)]],
                 metal::sampler smp [[sampler(0)]],
                 uint id [[thread_position_in_grid]]) {
  float mipLevel = float(id) / float(16);
  uint size = tex.get_width();
  float2 uv = float2((0.5 + mipLevel) / float(size), 0);
  result[id] = float4(tex.sample(smp, float2(0), level(mipLevel)).r,
                      tex.sample(smp, uv, level(0)).r,
                      0,
                      0);
}

