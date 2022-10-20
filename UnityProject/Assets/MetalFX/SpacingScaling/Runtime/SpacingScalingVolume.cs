using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace MetalFX.SpacingScaling.Runtime
{
    [Serializable]
    [VolumeComponentMenu("MetalFX/Spacing Scaling")]
    public sealed class SpacingScalingVolume : VolumeComponent
    {
        [SerializeField] bool isEnable = true;

        public bool IsActive => isEnable;
    }
}
