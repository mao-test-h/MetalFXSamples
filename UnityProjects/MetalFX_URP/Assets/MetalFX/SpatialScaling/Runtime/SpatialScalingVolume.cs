using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace MetalFX.SpatialScaling.Runtime
{
    [Serializable]
    [VolumeComponentMenu("MetalFX/Spatial Scaling")]
    public sealed class SpatialScalingVolume : VolumeComponent
    {
        [SerializeField] bool isEnable = true;

        public bool IsActive => isEnable;
    }
}