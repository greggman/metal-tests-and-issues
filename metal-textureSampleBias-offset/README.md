# Sample Bias offset issue in Metal

The code in `main.swift` make render pass to sample a texture with mostly hard coded values
to show a bug in Metal on M1/M2 (+) GPUs

Here is the MSL

```cpp
  float2 dims = float2(T.get_width(), T.get_height());
  float2 derivativeBase = (fragCoord.xy - 0.5) / dims;
  float2 derivativeMult = float2(0, 2445.079343096111);
  float2 baseCoords = float2(0.20833333333333334, 0.5416666666666666);
  float2 coords = baseCoords + derivativeBase * derivativeMult;
  
  return T.sample(S, coords, 0, bias(-9.655665566213429), int2(-2, -3));
```

To explain the code

`baseCoords`: this the texture coordinate we are trying to sample (before adding the offset)

`derivativeBase`: This is a used to make derivatives but if you look at the math,
                  it will be (0, 0) when we sample. The only thing this is used
                  for is to generate a derivative for the GPU to select a mip level

`derivativeMult`: This is used to affect the derivative calculation.

In this particular case the derivative should instruct the GPU to select
mip level 11.25567

We then add in the hard coded bias(-9.655665566213429) so the actual mip
sampled will be 11.25567 + -9.655665566213429 = ~1.6  This works as you can see from the result.

The Bug is with the offset. A mip level of 1.6 means we will sample mip levels 1 and 2
The texture is 12x12x4 (2d-array) with 3 mip levels

Mip level 0: 12x12
Mip leve1 1: 6x6
Mip level 2: 3x3

For mip level 1: The baseCoords of float2(0.20833333333333334, 0.5416666666666666)
translate to texel (1.250, 3.250)

```
       0   1   2   3   4   5 
     ╔═══╤═══╤═══╤═══╤═══╤═══╗
   0 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   1 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   2 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   3 ║   │ x │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   4 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   5 ║   │   │   │   │   │   ║
     ╚═══╧═══╧═══╧═══╧═══╧═══╝
```

But, we have an offset of (-2, -3) and the sampler is set to

```
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .repeat
```

Adding offset(-2, -3) to texel (1.250, 3.250) = texel (-1.750, 0.250)
Applying the address mode makes it texel(0, 0.250). The 0.250 means
for the 4 pixels it needs to sample for linear filtering it should
sample up one texel and given the tAddressMode = repeat it should wrap
around

That means these are the texels that should be sampled in mip level 1

```
       0   1   2   3   4   5 
     ╔═══╤═══╤═══╤═══╤═══╤═══╗
   0 ║ a │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   1 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   2 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   3 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   4 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   5 ║ b │   │   │   │   │   ║
     ╚═══╧═══╧═══╧═══╧═══╧═══╝
```

But if we check what's being sampled by M1/M2 GPU it's this

```
       0   1   2   3   4   5 
     ╔═══╤═══╤═══╤═══╤═══╤═══╗
   0 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   1 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   2 ║ a │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   3 ║ b │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   4 ║   │   │   │   │   │   ║
     ╟───┼───┼───┼───┼───┼───╢
   5 ║   │   │   │   │   │   ║
     ╚═══╧═══╧═══╧═══╧═══╧═══╝
```

The code finds the sample points by setting different texels to white and then running the shader
and looking at the result. If the result is (0,0,0,0) then the white pixels were not sampled. By
changing which pixels are white it can narrow down which pixels were sampled.

## from the sample code mip(1) incorrect, mip(2) correct

```
  sample points:
got:
layer: 0 mip(1)
at: [0, 2, 0], weight: 0.10196
at: [0, 3, 0], weight: 0.30588
mip level (1) weight: 0.40784

layer: 0 mip(2)
at: [0, 1, 0], weight: 0.51765
at: [0, 2, 0], weight: 0.07451
mip level (2) weight: 0.59216
```

Note: This issue only seems to exist with `bias`.  Without bias, all texture samplers work correctly, even with offsets.
