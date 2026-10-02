//
// Copyright 2026 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// desktop_gl_shims.cpp:
//    Hand-written desktop-GL-named entry points that stock ANGLE does not
//    generate (OpenGL ES has no singular DrawBuffer / no PolygonMode), but
//    that downstream wrappers (e.g. tinygl4angle's AliasDeclPriv trampolines:
//    `_glDrawBuffer: b _GL_DrawBuffer`) bind against at dyld load time on
//    Apple platforms. Missing exports make the *whole* wrapper library fail
//    to load, so these shims must exist even if some are rarely called.
//
//    MoltenVK-only iOS device build note: GL_DrawBuffer forwards exactly to
//    GL_DrawBuffers; GL_PolygonMode is a documented no-op because OpenGL ES
//    always rasterizes filled.

#include <GLES3/gl3.h>
#include <export.h>

#include "libGLESv2/entry_points_gles_3_0_autogen.h"

extern "C" {

ANGLE_EXPORT void GL_APIENTRY GL_DrawBuffer(GLenum buf)
{
    GL_DrawBuffers(1, &buf);
}

ANGLE_EXPORT void GL_APIENTRY GL_PolygonMode(GLenum face, GLenum mode)
{
    // OpenGL ES has no polygon mode; rasterization is always filled.
    // Accept the call silently so desktop-GL callers keep working.
    (void)face;
    (void)mode;
}

}  // extern "C"
