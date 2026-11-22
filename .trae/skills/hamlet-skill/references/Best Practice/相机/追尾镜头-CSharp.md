# 追尾镜头（CSharp）最佳实践

> 💡 **理论与机制指引**：关于 pitch / distance / offset 的 API 用途、通用硬约束、驾驶态数值建议、与 yaw 回正的分工、平台跟随行为，请参考手册：[相机视角控制.md](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%8E%A9%E5%AE%B6%E7%BD%91%E7%BB%9C%E5%AF%B9%E8%B1%A1/%E7%9B%B8%E6%9C%BA%E6%8E%A7%E5%88%B6/%E7%9B%B8%E6%9C%BA%E8%A7%86%E8%A7%92%E6%8E%A7%E5%88%B6.md) §五。
> 本文仅提供追尾镜头在 C# 侧的标准代码骨架。

---

## 1. 车后追尾镜头（SetDistance + SetPitch + SetOffset）

驾驶 / 骑乘态想要"更靠后、略高"的相机。yaw 回正另走 [相机回正-CSharp.md](./相机回正-CSharp.md)，本骨架只负责 pitch / distance / offset 的进入与恢复。

```csharp
using Douyin.Netcode;
using UnityEngine;

public class DriveCameraController : DouyinMonoBehaviour
{
    // 驾驶态相机参数
    [SerializeField] private float driveCameraDistance = 8f;
    [SerializeField] private float driveCameraPitch = 12f;
    [SerializeField] private Vector3 driveCameraOffset = new Vector3(0, 1.2f, 0);

    // 宿主约定的默认值（通用硬约束 #3：不假设 GetDistance 存在，自己缓存）
    [SerializeField] private float defaultCameraDistance = 4f;
    [SerializeField] private float defaultCameraPitch = 0f;
    [SerializeField] private Vector3 defaultCameraOffset = Vector3.zero;

    private bool hasPassenger;

    private void ApplyDriveCameraView()
    {
        DouyinCameraService.SetDistance(driveCameraDistance);
        DouyinCameraService.SetPitch(driveCameraPitch);
        DouyinCameraService.SetOffset(driveCameraOffset);
    }

    private void RestoreDefaultCameraView()
    {
        DouyinCameraService.SetDistance(defaultCameraDistance);
        DouyinCameraService.SetPitch(defaultCameraPitch);
        DouyinCameraService.SetOffset(defaultCameraOffset);
    }

    public override void OnSeatEntered(DouyinActor actor)
    {
        if (actor == null) return;
        hasPassenger = true;
        if (actor.isLocal)
        {
            ApplyDriveCameraView();
        }
    }

    public override void OnSeatExited(DouyinActor actor)
    {
        if (actor == null) return;
        hasPassenger = false;
        if (actor.isLocal)
        {
            RestoreDefaultCameraView();  // 通用硬约束 #3：退出状态显式恢复
        }
    }

    private void OnDestroy()
    {
        RestoreDefaultCameraView();  // 兜底：脚本销毁时未离座也恢复
    }
}
```
