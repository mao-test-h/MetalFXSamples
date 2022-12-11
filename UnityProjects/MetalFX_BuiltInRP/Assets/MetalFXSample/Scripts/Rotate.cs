using UnityEngine;

namespace MetalFXSample.Scripts
{
    sealed class Rotate : MonoBehaviour
    {
        [SerializeField] private float speed = 10.0f;

        private void Update()
        {
            transform.Rotate(Vector3.up, speed * Time.deltaTime);
        }
    }
}