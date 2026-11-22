public Transform GetBoneTransform(HumanBodyBones humanBoneId)
# 参数
| 参数 | 参数描述 |
| --- | --- |
| humanBoneId | 一个枚举类型参数，用于指定要获取的 Transform 的人体骨骼 |
# 返回
Transform
返回指定骨骼的 Transform 对象。
若 DouyinService.Proxy 为 null，则返回当前 gameObject 的 Transform。

# 描述
获取 [Actor ](../../DouyinActor.md)的人骨下的 Transform 对象。
