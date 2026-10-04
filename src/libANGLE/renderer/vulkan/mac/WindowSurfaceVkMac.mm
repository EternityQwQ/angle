//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// WindowSurfaceVkMac.mm:
//    Implements methods from WindowSurfaceVkMac.
//

#include "libANGLE/renderer/vulkan/mac/WindowSurfaceVkMac.h"

#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>

#include "libANGLE/renderer/vulkan/vk_renderer.h"
#include "libANGLE/renderer/vulkan/vk_utils.h"

namespace rx
{

WindowSurfaceVkMac::WindowSurfaceVkMac(const egl::SurfaceState &surfaceState,
                                       EGLNativeWindowType window)
    : WindowSurfaceVk(surfaceState, window), mMetalLayer(nullptr)
{}

WindowSurfaceVkMac::~WindowSurfaceVkMac()
{
    [mMetalDevice release];
    // Only release what we created; the host layer belongs to the view hierarchy.
    // Owned children are also detached so stale layers never linger on screen.
    if (mOwnsMetalLayer)
    {
        [mMetalLayer removeFromSuperlayer];
        [mMetalLayer release];
        mMetalLayer     = nullptr;
        mOwnsMetalLayer = false;
    }
}

angle::Result WindowSurfaceVkMac::createSurfaceVk(vk::ErrorContext *context)
{
    mMetalDevice = MTLCreateSystemDefaultDevice();

    CALayer *layer = reinterpret_cast<CALayer *>(mNativeWindowType);

    // Mirror SurfaceMtl: when the host already is a CAMetalLayer, render into
    // it directly instead of stacking our own child (same compositor path as
    // the working Metal backend; no mounting/ownership questions at all).
    // Contents scale is set BEFORE deriving drawableSize: a fresh layer
    // defaults to 1.0, which would size the initial swapchain at 1x.
    if ([layer isKindOfClass:[CAMetalLayer class]])
    {
        mMetalLayer     = (CAMetalLayer *)layer;
        mOwnsMetalLayer = false;
    }
    else
    {
        mMetalLayer        = [[CAMetalLayer alloc] init];
        mMetalLayer.frame  = CGRectMake(0, 0, layer.frame.size.width, layer.frame.size.height);
        mMetalLayer.contentsScale = layer.contentsScale;
#if TARGET_OS_OSX
        // autoresizingMask is macOS-only; iOS layers are resized by UIKit.
        mMetalLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
#else
        // MoltenVK-only iOS device build: our own child layer must not wait for
        // CATransactions (render threads have no runloop, so presented drawables
        // would never reach the screen despite successful swaps).
        mMetalLayer.presentsWithTransaction = NO;
#endif
        mOwnsMetalLayer = true;
        [layer addSublayer:mMetalLayer];
    }
    mMetalLayer.device = mMetalDevice;
    mMetalLayer.drawableSize =
        CGSizeMake(mMetalLayer.bounds.size.width * mMetalLayer.contentsScale,
                   mMetalLayer.bounds.size.height * mMetalLayer.contentsScale);
    mMetalLayer.framebufferOnly = NO;

    VkMetalSurfaceCreateInfoEXT createInfo = {};
    createInfo.sType                       = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT;
    createInfo.flags                       = 0;
    createInfo.pNext                       = nullptr;
    createInfo.pLayer                      = mMetalLayer;
    ANGLE_VK_TRY(context, VK_CALL(vkCreateMetalSurfaceEXT, context->getRenderer()->getInstance(),
                                  &createInfo, nullptr, &mSurface));

    return angle::Result::Continue;
}

angle::Result WindowSurfaceVkMac::getCurrentWindowSize(vk::ErrorContext *context,
                                                       gl::Extents *extentsOut) const
{
    ANGLE_VK_CHECK(context, (mMetalLayer != nullptr), VK_ERROR_INITIALIZATION_FAILED);

#if !TARGET_OS_OSX
    // Manual autoresizing follow (iOS has no kCALayerWidthSizable), owned child
    // layers only: never fight UIKit over a reused host layer's frame.
    if (mOwnsMetalLayer)
    {
        CALayer *hostLayer = reinterpret_cast<CALayer *>(mNativeWindowType);
        mMetalLayer.frame =
            CGRectMake(0, 0, hostLayer.bounds.size.width, hostLayer.bounds.size.height);
    }
#endif

    mMetalLayer.drawableSize =
        CGSizeMake(mMetalLayer.bounds.size.width * mMetalLayer.contentsScale,
                   mMetalLayer.bounds.size.height * mMetalLayer.contentsScale);
    *extentsOut = gl::Extents(static_cast<int>(mMetalLayer.drawableSize.width),
                              static_cast<int>(mMetalLayer.drawableSize.height), 1);

    return angle::Result::Continue;
}

}  // namespace rx
