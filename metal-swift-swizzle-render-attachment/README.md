This was a check to see if Metal ignores or errors when there is a
swizzle defined on a texture used as a render attachment.

It errors:

```
MTL_DEBUG_LAYER=1 ./main
2025-09-11 13:47:12.743 main[29462:15319348] Metal API Validation Enabled
-[MTLTextureDescriptorInternal validateWithDevice:]:1405: failed assertion `Texture Descriptor Validation
Texture swizzling is not compatable with MTLTextureUsageRenderTarget
```
