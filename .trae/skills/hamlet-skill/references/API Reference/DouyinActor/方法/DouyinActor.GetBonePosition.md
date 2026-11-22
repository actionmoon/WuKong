public Vector3 GetBonePosition(HumanBodyBones humanBoneId)
# 参数
| 参数  | 参数描述 |
| --- | --- |
| humanBoneld | 一个枚举类型的参数，用于指定要获取位置的人体骨骼。HumanBodyBones 枚举定义了人体各个骨骼的标识符 |

# 返回
Vector3
指定骨骼在世界空间中的位置。
如果 DouyinService.Proxy 为 null，则返回 Vector3.zero（即坐标为 (0, 0, 0)的位置）。

# 描述
获取 [Actor ](../../DouyinActor.md)指定人体骨骼在世界空间中的位置。

