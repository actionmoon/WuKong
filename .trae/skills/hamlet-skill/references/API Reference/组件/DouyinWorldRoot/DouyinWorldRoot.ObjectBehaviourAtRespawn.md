public ObjectBehaviourAtRespawn ObjectBehaviourAtRespawn = ObjectBehaviourAtRespawn.Respawn;
# 描述
物体重生逻辑，pickup对象在世界掉落的逻辑
```C#
public enum ObjectBehaviourAtRespawn
{
    Destroy, //删除该pickup对象
    Respawn, // 在重生点重新生成该拾取物品
}
```


