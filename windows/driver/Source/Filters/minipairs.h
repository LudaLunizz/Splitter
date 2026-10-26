/*++

Splitter: the twenty-two endpoints (eleven cables, a render and a capture
half each). Cables 1..6 belong to the input strips, 7..11 to buses A1, A2,
A3, B1, B2 (see common.h).

Derived from minipairs.h of Microsoft's SimpleAudioSample
(Copyright (c) Microsoft Corporation, MS-PL; see LICENSE-MS-PL.txt).

The names below (L"TopologyRender1" ...) must match the KSNAME_* strings in
Splitter.inx.
--*/

#ifndef _SIMPLEAUDIOSAMPLE_MINIPAIRS_H_
#define _SIMPLEAUDIOSAMPLE_MINIPAIRS_H_

#include "cabletopo.h"
#include "cabletoptable.h"
#include "cablewavtable.h"


NTSTATUS
CreateMiniportWaveRTSimpleAudioSample
(
    _Out_       PUNKNOWN *,
    _In_        REFCLSID,
    _In_opt_    PUNKNOWN,
    _In_        POOL_FLAGS,
    _In_        PUNKNOWN,
    _In_opt_    PVOID,
    _In_        PENDPOINT_MINIPAIR
);

NTSTATUS
CreateMiniportTopologySimpleAudioSample
(
    _Out_       PUNKNOWN *,
    _In_        REFCLSID,
    _In_opt_    PUNKNOWN,
    _In_        POOL_FLAGS,
    _In_        PUNKNOWN,
    _In_opt_    PVOID,
    _In_        PENDPOINT_MINIPAIR
);

/*********************************************************************
* Render half of a strip's cable. A bus's cable is the same, named   *
* "Splitter B1 Input" ..., and bus B1 plays into it.                 *
*                                                                    *
*              +------+                +------+                      *
*              | Wave |                | Topo |                      *
*              |      |                |      |                      *
* Apps     --->|0    1|--------------->|0    1|---> "Splitter N"     *
*              |      |                |      |                      *
*              +------+                +------+                      *
*********************************************************************/
static
PHYSICALCONNECTIONTABLE CableRenderTopologyPhysicalConnections[] =
{
    {
        KSPIN_TOPO_WAVEOUT_SOURCE,  // TopologyIn
        KSPIN_WAVE_RENDER3_SOURCE,  // WaveOut
        CONNECTIONTYPE_WAVE_OUTPUT
    }
};

/*********************************************************************
* Capture half of a strip's cable. A bus's cable is the same, named  *
* "Splitter B1" ..., and apps record it.                             *
*                                                                    *
*                     +------+    +------+                           *
*                     | Topo |    | Wave |                           *
*                     |      |    |      |                           *
* "Splitter N Output"-|0    1|===>|0    1|---> BananaSplit strip N   *
*                     |      |    |      |                           *
*                     +------+    +------+                           *
*********************************************************************/
static
PHYSICALCONNECTIONTABLE CableCaptureTopologyPhysicalConnections[] =
{
    {
        KSPIN_TOPO_BRIDGE,          // TopologyOut
        KSPIN_WAVE_BRIDGE,          // WaveIn
        CONNECTIONTYPE_TOPOLOGY_OUTPUT
    }
};

#define SPLITTER_RENDER_MINIPAIR(N)                                             \
static                                                                          \
ENDPOINT_MINIPAIR CableRender##N##Miniports =                                   \
{                                                                               \
    eCableRender##N,                                                            \
    L"TopologyRender" #N,                                                      \
    NULL,                                                                       \
    CreateMiniportTopologySimpleAudioSample,                                    \
    &CableRender##N##TopoFilterDescriptor,                                      \
    0, NULL,                                                                    \
    L"WaveRender" #N,                                                          \
    NULL,                                                                       \
    CreateMiniportWaveRTSimpleAudioSample,                                      \
    &CableRenderWaveFilterDescriptor,                                           \
    0,                                                                          \
    NULL,                                                                       \
    CABLE_CHANNELS,                                                             \
    CableRenderPinDeviceFormatsAndModes,                                        \
    SIZEOF_ARRAY(CableRenderPinDeviceFormatsAndModes),                          \
    CableRenderTopologyPhysicalConnections,                                     \
    SIZEOF_ARRAY(CableRenderTopologyPhysicalConnections),                       \
    ENDPOINT_NO_FLAGS,                                                          \
};

#define SPLITTER_CAPTURE_MINIPAIR(N)                                            \
static                                                                          \
ENDPOINT_MINIPAIR CableCapture##N##Miniports =                                  \
{                                                                               \
    eCableCapture##N,                                                           \
    L"TopologyCapture" #N,                                                     \
    NULL,                                                                       \
    CreateMiniportTopologySimpleAudioSample,                                    \
    &CableCapture##N##TopoFilterDescriptor,                                     \
    0, NULL,                                                                    \
    L"WaveCapture" #N,                                                         \
    NULL,                                                                       \
    CreateMiniportWaveRTSimpleAudioSample,                                      \
    &CableCaptureWaveFilterDescriptor,                                          \
    0,                                                                          \
    NULL,                                                                       \
    CABLE_CHANNELS,                                                             \
    CableCapturePinDeviceFormatsAndModes,                                       \
    SIZEOF_ARRAY(CableCapturePinDeviceFormatsAndModes),                         \
    CableCaptureTopologyPhysicalConnections,                                    \
    SIZEOF_ARRAY(CableCaptureTopologyPhysicalConnections),                      \
    ENDPOINT_NO_FLAGS,                                                          \
};

SPLITTER_RENDER_MINIPAIR(1)
SPLITTER_RENDER_MINIPAIR(2)
SPLITTER_RENDER_MINIPAIR(3)
SPLITTER_RENDER_MINIPAIR(4)
SPLITTER_RENDER_MINIPAIR(5)
SPLITTER_RENDER_MINIPAIR(6)
SPLITTER_RENDER_MINIPAIR(7)
SPLITTER_RENDER_MINIPAIR(8)
SPLITTER_RENDER_MINIPAIR(9)
SPLITTER_RENDER_MINIPAIR(10)
SPLITTER_RENDER_MINIPAIR(11)

SPLITTER_CAPTURE_MINIPAIR(1)
SPLITTER_CAPTURE_MINIPAIR(2)
SPLITTER_CAPTURE_MINIPAIR(3)
SPLITTER_CAPTURE_MINIPAIR(4)
SPLITTER_CAPTURE_MINIPAIR(5)
SPLITTER_CAPTURE_MINIPAIR(6)
SPLITTER_CAPTURE_MINIPAIR(7)
SPLITTER_CAPTURE_MINIPAIR(8)
SPLITTER_CAPTURE_MINIPAIR(9)
SPLITTER_CAPTURE_MINIPAIR(10)
SPLITTER_CAPTURE_MINIPAIR(11)

//=============================================================================
//
// Render miniport pairs, in cable order.
//
static
PENDPOINT_MINIPAIR  g_RenderEndpoints[] =
{
    &CableRender1Miniports,
    &CableRender2Miniports,
    &CableRender3Miniports,
    &CableRender4Miniports,
    &CableRender5Miniports,
    &CableRender6Miniports,
    &CableRender7Miniports,
    &CableRender8Miniports,
    &CableRender9Miniports,
    &CableRender10Miniports,
    &CableRender11Miniports,
};

#define g_cRenderEndpoints  (SIZEOF_ARRAY(g_RenderEndpoints))

//=============================================================================
//
// Capture miniport pairs, in cable order.
//
static
PENDPOINT_MINIPAIR  g_CaptureEndpoints[] =
{
    &CableCapture1Miniports,
    &CableCapture2Miniports,
    &CableCapture3Miniports,
    &CableCapture4Miniports,
    &CableCapture5Miniports,
    &CableCapture6Miniports,
    &CableCapture7Miniports,
    &CableCapture8Miniports,
    &CableCapture9Miniports,
    &CableCapture10Miniports,
    &CableCapture11Miniports,
};

#define g_cCaptureEndpoints (SIZEOF_ARRAY(g_CaptureEndpoints))

C_ASSERT(g_cRenderEndpoints == SPLITTER_CABLE_COUNT);
C_ASSERT(g_cCaptureEndpoints == SPLITTER_CABLE_COUNT);

//=============================================================================
//
// Total miniports = # endpoints * 2 (topology + wave).
//
#define g_MaxMiniports  ((g_cRenderEndpoints + g_cCaptureEndpoints) * 2)

#endif // _SIMPLEAUDIOSAMPLE_MINIPAIRS_H_
