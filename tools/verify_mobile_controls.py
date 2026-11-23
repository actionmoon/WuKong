"""Exercise production pointer lifecycles and verify the approved layout geometry."""
import json
import math
import re
from pathlib import Path
from lupa.lua53 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("""
        UnityEngine={Time={frameCount=1},Vector2=setmetatable({zero={x=0,y=0}},
            {__call=function(_,x,y) return {x=x,y=y} end})}
        UnityEngine.Vector3=function(x,y,z) return {x=x,y=y,z=z} end
        UnityEngine.RectTransformUtility={RectangleContainsScreenPoint=function(r,p)
            return p.x>=r.x and p.x<=r.x+50 and p.y>=0 and p.y<=50 end}
        UnityEngine.Input={touchCount=0}
        UnityEngine.Input.GetMouseButtonDown=function() return false end
        UnityEngine.Input.GetMouseButtonUp=function() return false end
        UnityEngine.Input.GetMouseButton=function() return false end
        UnityEngine.TouchPhase={Began=0,Moved=1,Ended=2,Canceled=3}
        WKCombatConfig={};WKCombatClock={};WKJson={}
    """)
    # Read the production closure directly; expose only the state under test.
    source = (ROOT / "unity/Assets/WuKong/Lua/Client/CombatInput.lua").read_text()
    lua.execute(source + """
        hud={IsModal=function() return false end,CanPress=function(n) return n~="spirit" end}
        uiBindings={}
        for i,n in ipairs({"heavy","dodge","spin","spirit"}) do
            uiBindings[i]={name=n,rect={x=(i-1)*100},button={gameObject={activeInHierarchy=true}}}
        end
        function testDown(id,x) pointerDown(id,{x=x,y=20}) end
        function testMove(id,x) pointerMove(id,{x=x,y=20}) end
        function testUp(id) pointerUp(id) end
        function testCount() return #uiPressed end
        function testModal(value) hud.IsModal=function() return value end end
        function testPoll(touches)
            UE.Input.touchCount=#touches
            UE.Input.GetTouch=function(i) return touches[i+1] end
            pointerControls()
        end
    """)
    g = lua.globals()
    results = []

    def run(name, body):
        g.ClearControls()
        body()
        results.append({"name": name, "pass": True})

    def duplicate():
        g.testDown(1, 10)
        g.testDown(1, 10)
        assert g.testCount() == 1 and g.IsHeld("heavy")
        g.testUp(1)
        assert not g.IsHeld("heavy")

    def slide():
        g.testDown(1, 10)
        g.testMove(1, 110)
        assert not g.IsHeld("heavy") and g.testCount() == 1
        g.testMove(1, 10)
        assert not g.IsHeld("heavy")

    def blank():
        g.testDown(1, 70)
        g.testMove(1, 110)
        assert g.testCount() == 0

    def multi():
        g.testDown(1, 10)
        g.testDown(2, 10)
        g.testDown(3, 110)
        assert g.testCount() == 3
        g.testUp(1)
        assert g.IsHeld("heavy")
        g.testUp(2)
        assert not g.IsHeld("heavy")

    def canceled():
        touches = lua.table_from([lua.table_from(dict(fingerId=1, phase=0, position=lua.table_from(dict(x=210, y=20))))])
        g.testPoll(touches)
        assert g.IsHeld("spin")
        touches[1].phase = 3
        g.testPoll(touches)
        assert not g.IsHeld("spin") and g.testCount() == 1

    def blocked():
        g.testDown(1, 310)
        assert g.testCount() == 0
        g.testModal(True)
        g.testDown(2, 110)
        assert g.testCount() == 0
        g.testModal(False)
        g.testDown(3, 10)
        g.ClearControls()
        g.testMove(3, 10)
        assert g.testCount() == 0 and not g.IsHeld("heavy")

    for name, body in [("same pointer callback + polling", duplicate), ("slide permanently releases without transfer", slide),
                       ("blank origin never acquires button", blank), ("independent fingers and repeated presses", multi),
                       ("touch cancellation", canceled), ("unavailable/modal/reset", blocked)]:
        run(name, body)

    g.WKSkillsConfig = lua.execute((ROOT / "unity/Assets/WuKong/Lua/Shared/Modules/SkillsConfig.lua").read_text())
    g.UnityEngine.Screen = lua.table_from(dict(width=1280, height=720))
    lua.execute((ROOT / "unity/Assets/WuKong/Lua/Client/PresentationHUD.lua").read_text())
    view = lua.table_from(dict(epoch=1, hp=390, challenge="fight", form="wukong", formPhase="none",
                               spiritPhase="none", mp=220, transEnergy=150, vigor=212, gourd=6,
                               cooldowns=lua.table(), kind="light"))
    g.Apply(view)
    assert g.CanPress("immobilize", False)[0]  # Attacking does not suppress legal queueing.
    view.cooldowns.immobilize = 2
    assert g.CanPress("immobilize", False) == (False, "冷却中")
    view.cooldowns.immobilize = 0
    view.mp = g.WKSkillsConfig.spells.immobilize.skills["10518"].mpRequired - 1
    assert g.CanPress("immobilize", False) == (False, "法力不足")
    view.mp = 220
    view.transEnergy = 149
    assert not g.CanPress("transform", False)[0]
    view.vigor = 211
    assert not g.CanPress("spirit", False)[0]
    view.form, view.formPhase = "lang", "born"
    assert g.CanPress("transform", False)[0] and g.CanPress("heavy", False)[0]
    assert not g.CanPress("cloud", False)[0]
    view.form, view.formPhase, view.spiritPhase = "wukong", "none", "enter"
    assert not g.CanPress("heavy", False)[0]
    view.hp = 0
    assert not g.CanPress("dodge", False)[0] and g.CanPress("challenge", False) is True
    results.append({"name": "production HUD cooldown/resources/forms/queueing/death eligibility", "pass": True})

    builder = (ROOT / "unity/Assets/WuKong/Editor/WuKongPresentationBuilder.cs").read_text()
    # Obtain the values actually used by the scene builder.
    arrays = {name: [float(x) for x in re.search(name + r"=\{([^}]+)\}", builder)[1].split(",")]
              for name in ("radii", "diameters", "starts", "ends")}
    sizes = [(960, 540, 0, 0), (960, 540, 18, 18), (1280, 720, 24, 24),
             (1600, 720, 48, 24), (1024, 768, 32, 24)]
    layouts = []
    for w, h, right, bottom in sizes:
        scale = min(h / 720, min(.4 * w - right, w - right) / 408,
                    min(.6 * h - bottom, h - bottom) / 408)
        boxes = []
        for layer, count in enumerate((1, 2, 4, 5)):
            radius, diameter = arrays["radii"][layer], arrays["diameters"][layer]
            if layer:
                assert abs(radius - arrays["radii"][layer-1] - (diameter + arrays["diameters"][layer-1]) / 2 - 24) < 1e-6
            for i in range(count):
                angle = math.radians(arrays["starts"][layer] + (arrays["ends"][layer] - arrays["starts"][layer]) * (i / (count-1) if count > 1 else 0))
                cx, cy = w-right+(-20-radius*math.cos(angle))*scale, bottom+(20+radius*math.sin(angle))*scale
                half = diameter * scale / 2
                box = (cx-half, cy-half, cx+half, cy+half)
                assert box[0] >= .6*w and box[1] >= bottom and box[2] <= w-right and box[3] <= .6*h
                boxes.append(box)
        for i, a in enumerate(boxes):
            for b in boxes[i+1:]:
                assert a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1]
        toast_width = float(re.search(r'Label\("CombatToast".*?new Vector2\((\d+),24\)', builder)[1])
        toast = (w-right-(204+toast_width/2)*scale, bottom+376*scale,
                 w-right-(204-toast_width/2)*scale, bottom+400*scale)
        for b in boxes:
            assert toast[2] <= b[0] or b[2] <= toast[0] or toast[3] <= b[1] or b[3] <= toast[1]
        assert 408*scale+right <= .4*w and 408*scale+bottom <= .6*h
        layouts.append(dict(width=w, height=h, right=right, bottom=bottom, scale=scale,
                            outerTouchSize=68*scale, buttons=12, outside=0, overlap=0))
    path = ROOT / "docs/reference/mobile-controls-input-layout-evidence.json"
    path.write_text(json.dumps({"input": results, "geometry": layouts, "scope": "production Lua lifecycle; mathematical builder geometry, not device input"},
                               ensure_ascii=False, indent=2) + "\n")
    print(f"Passed {len(results)} input cases and {len(layouts)} layouts: {path}")


if __name__ == "__main__":
    main()
