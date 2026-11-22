public RespawnLogicType PlayerRespawnLogic = RespawnLogicType.RandomSpawn;
# 描述
玩家重生逻辑
```C#
public enum RespawnLogicType
{
    RandomSpawn, //在随机出生点重生
    InitialPosition  //在该玩家首次出生点重生
}
```


