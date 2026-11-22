public SpawnOrder SpawnOrder = SpawnOrder.Random
# 描述

出生的顺序规则
```C#
public enum SpawnOrder
{
    First, //始终从第一个出生点生成玩家    
    Sequential, // 按队列顺序生成玩家
    Random,  // 随机顺序生成玩家
}
```


