//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// DisplayVkMac.mm:
//    Implements methods from DisplayVkMac
//

#include "libANGLE/renderer/vulkan/mac/DisplayVkMac.h"

#include <vulkan/vulkan.h>

#if TARGET_OS_OSX
#    include "libANGLE/renderer/vulkan/mac/IOSurfaceSurfaceVkMac.h"
#endif
#include "libANGLE/renderer/vulkan/mac/WindowSurfaceVkMac.h"
#include "libANGLE/renderer/vulkan/vk_caps_utils.h"
#include "libANGLE/renderer/vulkan/vk_renderer.h"

// MoltenVK-only iOS device build: Cocoa is macOS-only; CALayer comes from
// QuartzCore on both platforms.
#if TARGET_OS_OSX
#    import <Cocoa/Cocoa.h>
#else
#    import <Foundation/Foundation.h>
#    import <QuartzCore/CALayer.h>
#endif

namespace rx
{

DisplayVkMac::DisplayVkMac(const egl::DisplayState &state) : DisplayVk(state) {}

bool DisplayVkMac::isValidNativeWindow(EGLNativeWindowType window) const
{
    NSObject *layer = reinterpret_cast<NSObject *>(window);
    return [layer isKindOfClass:[CALayer class]];
}

SurfaceImpl *DisplayVkMac::createWindowSurfaceVk(const egl::SurfaceState &state,
                                                 EGLNativeWindowType window)
{
    ASSERT(isValidNativeWindow(window));
    return new WindowSurfaceVkMac(state, window);
}

SurfaceImpl *DisplayVkMac::createPbufferFromClientBuffer(const egl::SurfaceState &state,
                                                         EGLenum buftype,
                                                         EGLClientBuffer clientBuffer,
                                                         const egl::AttributeMap &attribs)
{
#if TARGET_OS_OSX
    ASSERT(buftype == EGL_IOSURFACE_ANGLE);

    return new IOSurfaceSurfaceVkMac(state, clientBuffer, attribs, mRenderer);
#else
    // IOSurface client buffers are macOS-only (headers private on iOS).
    UNREACHABLE();
    return nullptr;
#endif
}

egl::ConfigSet DisplayVkMac::generateConfigs()
{
    constexpr GLenum kColorFormats[] = {GL_BGRA8_EXT, GL_BGRX8_ANGLEX};
    return egl_vk::GenerateConfigs(kColorFormats, egl_vk::kConfigDepthStencilFormats, this);
}

void DisplayVkMac::checkConfigSupport(egl::Config *config)
{
    // TODO(geofflang): Test for native support and modify the config accordingly.
    // anglebug.com/42261400
}

const char *DisplayVkMac::getWSIExtension() const
{
    return VK_EXT_METAL_SURFACE_EXTENSION_NAME;
}

bool IsVulkanMacDisplayAvailable()
{
    return true;
}

DisplayImpl *CreateVulkanMacDisplay(const egl::DisplayState &state)
{
    return new DisplayVkMac(state);
}

void DisplayVkMac::generateExtensions(egl::DisplayExtensions *outExtensions) const
{
#if TARGET_OS_OSX
    outExtensions->iosurfaceClientBuffer = true;
#endif

    DisplayVk::generateExtensions(outExtensions);
}

egl::Error DisplayVkMac::validateClientBuffer(const egl::Config *configuration,
                                              EGLenum buftype,
                                              EGLClientBuffer clientBuffer,
                                              const egl::AttributeMap &attribs) const
{
#if TARGET_OS_OSX
    ASSERT(buftype == EGL_IOSURFACE_ANGLE);

    if (!IOSurfaceSurfaceVkMac::ValidateAttributes(this, clientBuffer, attribs))
    {
        return egl::Error(EGL_BAD_ATTRIBUTE);
    }
    return egl::NoError();
#else
    // IOSurface client buffers are macOS-only (headers private on iOS).
    return egl::Error(EGL_BAD_ATTRIBUTE);
#endif
}

}  // namespace rx
