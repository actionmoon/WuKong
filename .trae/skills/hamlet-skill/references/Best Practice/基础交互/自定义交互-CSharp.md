# 通用交互（C#）

本文提供通用交互的 C# 实现。使用代码前，必须阅读 [基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)、[触发交互最佳实践](./触发交互-最佳实践.md)和[自定义交互最佳实践](./自定义交互-最佳实践.md)。

> **开始实现前必须阅读**：[自定义交互最佳实践中的常见错误](./%E8%87%AA%E5%AE%9A%E4%B9%89%E4%BA%A4%E4%BA%92-%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.md#常见错误)。该清单说明按钮生命周期、联网事件和多按钮分发里最容易遗漏的问题。

> 脚本类必须继承 `DouyinMonoBehaviour` 并放在 `GameScripts/` 目录下。若重写 `Awake`，第一句必须调用 `base.Awake()`。

## 一、最小化写法：单按钮状态切换

概念参考：[基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)。

下面的示例包含通用交互的最小闭环：本地玩家触发、打开交互通道、焦点时创建按钮、C# 按钮监听、失焦清理、本地按钮请求和同步状态刷新。持久状态请求只从本地按钮监听发出一次，不经过 `OnInteract`。

```csharp
using Douyin;
using Douyin.Netcode;
using UnityEngine;
using UnityEngine.UI;

public class SimpleInteraction : DouyinMonoBehaviour
{
    private readonly NetworkVariable<bool> isActive = new(false);
    private Button interactionButton;
    private int localActorId;
    private bool hasLocalActorId;

    public override void Awake()
    {
        base.Awake();
    }

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();
        isActive.OnValueChanged += HandleActiveStateChanged;
        // 网络初始化会触发一次 OnValueChanged，用于恢复初始展示。
    }

    public override void OnNetworkDespawn()
    {
        isActive.OnValueChanged -= HandleActiveStateChanged;
        base.OnNetworkDespawn();
    }

    public override void OnActorTriggerEnter(DouyinActor actor)
    {
        if (actor == null || !actor.isLocal) return;
        localActorId = actor.actorID;
        hasLocalActorId = true;
        EnableInteraction();
    }

    public override void OnActorTriggerExit(DouyinActor actor)
    {
        if (actor == null || !actor.isLocal) return;
        hasLocalActorId = false;
        DisableInteraction();
    }

    public override void OnFocus()
    {
        interactionButton = AddInteractorButton();
        if (interactionButton == null) return;

        // C# 不自动派发 OnInteractorButtonClick，必须监听 Button.onClick。
        interactionButton.onClick.AddListener(HandleButtonClick);
        // 焦点重新获得时按已确认同步状态设置按钮文案。
        RefreshButtonText();
    }

    public override void OnLostFocus()
    {
        if (interactionButton != null)
        {
            interactionButton.onClick.RemoveAllListeners();
            RemoveInteractorButton(interactionButton);
            interactionButton = null;
        }
    }

    private void HandleButtonClick()
    {
        if (!IsSpawned || !hasLocalActorId) return;
        if (!DouyinNetService.isNetworkSettled) return;

        var actor = DouyinActorService.GetActorById(localActorId);
        if (actor == null) return;

        if (IsOwner)
        {
            // 主权端直接切换通用业务状态。
            ToggleActiveState();
            return;
        }

        // 非主权点击端只向当前主权端发起一次状态请求。
        ToggleActiveStateRpc();
    }

    [Rpc(SendTo.Owner)]
    private void ToggleActiveStateRpc()
    {
        // 主权可能在请求到达前转移，写入前再次确认。
        ToggleActiveState();
    }

    private void ToggleActiveState()
    {
        if (!IsOwner) return;

        var currentState = isActive.Value;
        isActive.Value = !currentState;
    }

    private void RefreshButtonText()
    {
        if (interactionButton == null) return;

        var label = interactionButton.GetComponentInChildren<Text>(true);
        if (label == null) return;

        if (isActive.Value)
        {
            // 按业务含义替换为对应文案，例如“关闭”“停止”“已领取”。
            label.text = "停止";
        }
        else
        {
            // 按业务含义替换为对应文案，例如“打开”“启动”“领取”。
            label.text = "启动";
        }
    }

    private void HandleActiveStateChanged(bool previous, bool current)
    {
        RefreshButtonText();
    }
}
```

> **默认联网口径**：按钮点击只在本地发起一次状态请求；主权方写入同步变量，所有端在 `OnValueChanged` 按已确认状态刷新表现。网络初始化也会触发一次该回调，用于后进房和重连恢复。只有需要全端瞬时反馈时，才额外调用 `actor.Interact(gameObject)`。

需要全端即时音效、粒子或短动画时，`HandleButtonClick` 可以在状态请求代码后额外执行 `actor.Interact(gameObject)`；此时可实现 `OnInteract(DouyinActor actor)` 播放瞬时反馈。`OnInteract` 中禁止调用状态 RPC、修改 `NetworkVariable` 或申请主权，否则每个在线端都会重复发起同一状态请求。

## 二、扩展写法

### 2.1 多按钮分发

C# 不使用 `OnInteractorButtonClick(int index)` 分发按钮。每个按钮创建后，直接为自己的 `Button.onClick` 添加监听：

```csharp
private Button dialogButton;
private Button shopButton;
private Button questButton;

public override void OnFocus()
{
    dialogButton = AddInteractorButton();
    shopButton = AddInteractorButton();

    if (dialogButton != null)
    {
        dialogButton.onClick.AddListener(OpenDialog);
        RefreshButtonText(dialogButton, "对话");
    }

    if (shopButton != null)
    {
        shopButton.onClick.AddListener(OpenShop);
        RefreshButtonText(shopButton, "商店");
    }

    questButton = AddInteractorButton();
    if (questButton != null)
    {
        questButton.onClick.AddListener(OpenQuest);
        RefreshButtonText(questButton, "任务");
    }
}

public override void OnLostFocus()
{
    if (dialogButton != null) dialogButton.onClick.RemoveAllListeners();
    if (shopButton != null) shopButton.onClick.RemoveAllListeners();
    if (questButton != null) questButton.onClick.RemoveAllListeners();
    RemoveAllInteractorButtons();
    dialogButton = null;
    shopButton = null;
    questButton = null;
}

private static void RefreshButtonText(Button button, string text)
{
    if (button == null) return;
    var label = button.GetComponentInChildren<Text>(true);
    if (label != null) label.text = text;
}

private void OpenDialog() { /* 对话业务 */ }
private void OpenShop() { /* 商店业务 */ }
private void OpenQuest() { /* 任务业务 */ }
```

### 2.2 距离 + 按键触发（无 UI 按钮）

有些交互不显示交互按钮，只在玩家靠近并按下按键时触发。这类逻辑属于输入系统，不需要 `AddInteractorButton`：

```csharp
using Douyin;
using UnityEngine;

public class KeyInteractor : DouyinMonoBehaviour
{
    [SerializeField] private float interactDistance = 3.0f;

    private void Update()
    {
        var actor = DouyinActorService.GetLocalActor();
        if (actor == null || !Input.GetKeyDown(KeyCode.E)) return;
        TryInteract(actor);
    }

    private void TryInteract(DouyinActor actor)
    {
        if (actor.IsBusy()) return;
        if (Vector3.Distance(actor.position, transform.position) > interactDistance) return;
        actor.Interact(gameObject);
    }

    public override void OnInteract(DouyinActor actor)
    {
        if (actor == null) return;
        Debug.Log("交互触发");
    }
}
```

此示例只演示无 UI 按钮的瞬时交互事件。若交互会改变门、机关或奖励等持久状态，应在本地按键入口发起一次主权 RPC 或其它状态请求，再由 `NetworkVariable` 变化刷新展示。

### 2.3 交互管理器：自动找最近交互对象

场景中有多个交互对象时，可以由玩家侧管理器找到最近目标，再按对象类型调用对应入口：

```csharp
using Douyin;
using UnityEngine;

public class InteractionManager : DouyinMonoBehaviour
{
    [SerializeField] private float interactRange = 2.5f;

    private readonly Collider[] hitColliders = new Collider[10];
    private GameObject currentTarget;

    private void Update()
    {
        var actor = DouyinActorService.GetLocalActor();
        if (actor == null)
        {
            currentTarget = null;
            return;
        }

        FindNearestInteractable(actor);
        if (Input.GetKeyDown(KeyCode.F) && currentTarget != null)
        {
            PerformInteraction(actor);
        }
    }

    private void FindNearestInteractable(DouyinActor actor)
    {
        int hitCount = Physics.OverlapSphereNonAlloc(
            actor.position, interactRange, hitColliders);

        float nearestDistance = float.MaxValue;
        GameObject nearest = null;
        for (int i = 0; i < hitCount; i++)
        {
            var col = hitColliders[i];
            if (col == null || col.gameObject == gameObject) continue;

            var distance = Vector3.Distance(actor.position, col.transform.position);
            if (distance < nearestDistance)
            {
                nearestDistance = distance;
                nearest = col.gameObject;
            }
        }

        currentTarget = nearest;
    }

    private void PerformInteraction(DouyinActor actor)
    {
        if (actor.IsBusy() || currentTarget == null) return;

        if (currentTarget.GetComponent<AdvancedPickup>() != null)
        {
            if (actor.GetPickupInHand(HandType.All) == null)
            {
                actor.Pickup(currentTarget, HandType.Right);
            }
            return;
        }

        if (currentTarget.GetComponent<SimpleSeat>() != null)
        {
            if (actor.IsSitting())
            {
                actor.StandUp(currentTarget);
            }
            else
            {
                actor.SitDown(currentTarget);
            }
            return;
        }

        actor.Interact(currentTarget);
    }
}
```

`AdvancedPickup` / `SimpleSeat` 只是项目中的示例标记类型，实际项目应替换为自己的组件类型。

### 2.4 可视化配置组件

如果使用自定义组件在 属性面板 中配置按钮，可以按以下方式创建按钮并绑定 `onClick`。C# 不能依赖自动派发的 `OnInteractorButtonClick`：

```csharp
public override void OnFocus()
{
    interactorButtons = new Button[ButtonConfigs.Length];
    for (int i = 0; i < ButtonConfigs.Length; i++)
    {
        var button = AddInteractorButton();
        ApplyButtonConfig(button, ButtonConfigs[i]);
        interactorButtons[i] = button;

        int buttonIndex = i;
        button.onClick.AddListener(() => HandleConfiguredButton(buttonIndex));
    }
}

private void HandleConfiguredButton(int index)
{
    var actor = DouyinActorService.GetLocalActor();
    if (actor == null) return;

    // 在本地根据 index 分发状态请求或本地动作。
    ButtonConfigs[index].ButtonActions?.Invoke();

    // 只有需要全端瞬时反馈时才额外调用：
    // actor.Interact(gameObject);
}
```

移除按钮前需要清理每个按钮的监听器。`ButtonConfigs`、`ApplyButtonConfig` 和 `ButtonActions` 是自定义组件字段，不是 SDK API。

### 2.5 多人同步

通用交互不会自动同步业务状态。需要跨端一致时，在本地 `Button.onClick` 监听中使用项目已有的 `[Rpc(SendTo.Owner)]` 或主权流程发起一次状态请求；主权端校验后写入 `NetworkVariable`，所有端在 `OnValueChanged` 中刷新展示。网络初始化也会触发一次该回调，用于后进房和重连恢复。不要在 `OnInteract` 中发送状态 RPC 或写入状态，否则在线端会重复请求。

## 三、C# 常见错误

### 1. 覆写 `OnInteractorButtonClick` 等待 SDK 自动调用

C# 当前不会自动派发这个回调。必须保存 `AddInteractorButton()` 返回的 `Button`，并通过 `button.onClick.AddListener(...)` 接入点击；移除前调用 `RemoveAllListeners()`。

### 2. 在 Trigger 或 `Awake` 中创建按钮

Trigger 只负责调用 `EnableInteraction` / `DisableInteraction`；按钮必须在 `OnFocus` 创建，在 `OnLostFocus` 清理。

### 3. 忘记调用 `base.Awake()`

`DouyinMonoBehaviour.Awake` 负责初始化 SDK 上下文。派生类重写 `Awake` 时不调用基类，触发和交互回调可能无法正常工作。

### 4. 在 `OnInteract` 中发起状态 RPC

`OnInteract` 会在所有在线端执行。若在其中调用 `[Rpc(SendTo.Owner)]`、申请主权或写入 `NetworkVariable`，一次点击会变成多个状态请求。持久状态请求必须由点击端的 `Button.onClick` 监听发起；`OnInteract` 仅用于可丢失、无需晚进房恢复的瞬时反馈。
