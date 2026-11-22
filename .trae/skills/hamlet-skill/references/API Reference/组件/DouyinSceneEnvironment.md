# 描述
您可以通过该类设置游戏中场景环境

# 公开属性
| 属性 | 描述 |
| --- | --- |
| [JsonAsset](./DouyinSceneEnvironment/DouyinSceneEnvironment.JsonAsset.md) | 返回场景效果参数配置表，该对象通过读取json文件获取，并且不能被创建成一个新类 |
| [settings.enableMainLight](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.enableMainLight.md) | 启用或配置主光源的属性调整面板 |
| [settings.mainLightType](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.mainLightType.md) | 返回或设置主光源的模式。 |
| [settings.mainLightStrength](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.mainLightStrength.md) | 返回或设置主光源的强度 |
| [settings.mainLightDir](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.mainLightDir.md) | 返回或设置主光源的方向。 |
| [settings.enableShadow](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.enableShadow.md) | 设置或返回光影模式。可用值为 None、Hard 和 Soft。 |
| [settings.shadowStrength](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.shadowStrength.md) | 返回或设置主光源的阴影强度。 |
| [settings.enableCharacterLight](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.enableCharacterLight.md) | 启用或禁用角色光照照的属性面板。启用后场景内的角色将收此光照影响，未启用则仅受场景光源的影响。 |
| [settings.characterLightColor](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.characterLightColor.md) | 返回或设置角色光照的颜色。 |
| [settings.characterStrength](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.characterStrength.md) | 返回或设置角色光照的强度。 |
| [settings.characterRotation](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.characterRotation.md) | 返回或设置角色光照的方向。 |
| [settings.characterAmbientEnable](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.characterAmbientEnable.md) | 启用或禁用环境的灯光配置。 |
| [settings.characterCubemapEnable](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.characterCubemapEnable.md) | 启用或配置角色的立方体贴图。 |
| [settings.characterAmbient](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.characterAmbient.md) | 返回或设置环境灯光的颜色。 |
| [settings.fogEnable](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.fogEnable.md) | 启用或禁用雾相关的配置面板 |
| [settings.fogColor](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.fogColor.md) | 返回或设置雾的颜色 |
| [settings.startFog](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.startFog.md) | 返回或设置雾的起始距离。 |
| [settings.endFog](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.endFog.md) | 返回或设置雾的结束距离。 |
| [settings.skyMaterial](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.skyMaterial.md) | 返回或设置天空的材质对象。 |
| [settings.flareEnable](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.flareEnable.md) | 启用或禁用镜头光晕效果面板。 |
| [settings.followCamera](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.followCamera.md) | 启用或禁用镜头光晕的效果是否跟随主相机 |
| [settings.lenFlare](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlare.md) | 返回或设置镜头光晕的数据对象。 |
| [settings.lenFlarePosition](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlarePosition.md) | 返回或设置镜头光晕的位置。 |
| [settings.lenFlareIntensity](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlareIntensity.md) | 返回或设置镜头光晕的强度。 |
| [settings.lenFlareScale](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlareScale.md) | 返回或设置镜头光晕的缩放。 |
| [settings.lenFlareAttenuationDistance](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlareAttenuationDistance.md) | 返回或设置镜头光晕的衰减距离。 |
| [settings.lenFlareScaleDistance](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlareScaleDistance.md) | 返回或设置镜头光晕的缩放距离。 |
| [settings.lenFlareEnableOcclusion](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlareEnableOcclusion.md) | 启用或禁用镜头光晕的遮挡效果。 |
| [settings.lenFlareAllowOffScreen](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.lenFlareAllowOffScreen.md) | 启用或禁用镜头光晕是否允许在屏幕外渲染 |
| [settings.enablePostProcess](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.enablePostProcess.md) | 启用或禁用后处理效果的属性面板 |
| [settings.BloomEnabled](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.BloomEnabled.md) | 启用或禁用泛光效果 |
| [settings.BloomColor](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.BloomColor.md) | 返回或设置泛光颜色 |
| [settings.BloomThreshold](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.BloomThreshold.md) | 返回或设置泛光的阈值，定义场景中哪些物体将出现泛光,即场景中物体亮度低于此阈值时将不会显示泛光效果 |
| [settings.BloomIntensity](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.BloomIntensity.md) | 返回或设置泛光的强度 |
| [settings.BloomScatter](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.BloomScatter.md) | 返回或设置泛光的范围 |
| [settings.LUT](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.LUT.md) | 启用或禁用色彩校正的颜色查找表效果 |
| [settings.LutAmount](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.LutAmount.md) | 返回或者设置颜色校正的颜色数量 |
| [settings.SourceLut](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.SourceLut.md) | 返回或者设置颜色校正的贴图 |
| [settings.ImageFiltering](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.ImageFiltering.md) | 启用或者禁用图片校色效果 |
| [settings.Color](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Color.md) | 返回或者设置图片校色的颜色 |
| [settings.Contrast](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Contrast.md) | 返回或者设置图片校色的对比度 |
| [settings.Brightness](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Brightness.md) | 返回或者设置图片校色的亮度 |
| [settings.Saturation](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Saturation.md) | 返回或者设置图片校色的饱和度 |
| [settings.ChromaticAberration](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.ChromaticAberration.md) | 启用或者禁用图片色差效果 |
| [settings.Offset](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Offset.md) | 返回或者设置图片的偏移量 |
| [settings.Distortion](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Distortion.md) | 启用或者禁用暗角 |
| [settings.DistortionIntensity](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.DistortionIntensity.md) | 返回或者设置暗角强度 |
| [settings.Vignette](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.Vignette.md) | 启用或禁用屏幕渐晕效果 |
| settings.VignetteColor | 返回或者设置屏幕渐晕颜色 |
| [settings.VignetteAmount](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.VignetteAmount.md) | 返回或者设置屏幕渐晕强度 |
| [settings.VignetteSoftness](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.VignetteSoftness.md) | 返回或者设置屏幕渐晕平滑度 |
| [settings.EnableCustomizedPass](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.EnableCustomizedPass.md) | 启用或者禁用自定义后期处理 |
| [settings.CustomizedPassMaterial](./DouyinSceneEnvironment/DouyinSceneEnvironment.settings.CustomizedPassMaterial.md) | 启用后，自定义后期处理材质 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [LoadJson](./DouyinSceneEnvironment/DouyinSceneEnvironment.LoadJson.md) | 加载一个json asset的数据对象，对环境参数进行配置 |
| [Change](./DouyinSceneEnvironment/DouyinSceneEnvironment.Change.md) | 在规定的时间帧内，将当前环境的切换至目标环境 |
