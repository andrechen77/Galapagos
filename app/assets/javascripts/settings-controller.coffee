locales = [
  { code: "zh_cn", description: "Chinese, simplified - 中文 (简体)" }
, { code: "en_us", description: "English, United States" }
]

settings = new Map()
settings.set('locale', {
  def: ''
, ractiveName: 'locale'
, in:  ((l) -> l)
, out: ((l) -> l)
})
settings.set('workInProgress.enabled', {
  def: 'Enabled'
, ractiveName: 'workInProgressSetting'
, in:  ((wipEnabled) -> if wipEnabled then 'Enabled' else 'Disabled')
, out: ((value)      -> value is 'Enabled')
})
settings.set('useVerticalLayout', {
  def: 'below'
, ractiveName: 'verticalLayoutSetting'
, in:  ((useVerticalLayout) -> if useVerticalLayout then 'below' else 'right')
, out: ((value)             -> value is 'below')
})
settings.set('viewQuality', {
  def: Math.max(window.devicePixelRatio ? 2, 2),
  ractiveName: 'viewQualitySetting',
  in: (viewQuality) -> viewQuality,
  out: (value) -> value
})

settingNames = Array.from(settings.keys())

template = """
<div class="settings-panel">
  <h1 class="settings-header">NetLogo Web Settings</h1>

  <label class="setting-label">
    Command center, NetLogo code, and model info position:
  </label>
  <div class="setting-control">
    <select value={{verticalLayoutSetting}} on-change="setting-changed">
      <option value="below">Below the model</option>
      <option value="right">To the right of the model</option>
    </select>
  </div>

  <label class="setting-label">
    Automatically save changes made to models and reuse them when reloading:
  </label>
  <div class="setting-control">
    <select value={{workInProgressSetting}} on-change="setting-changed">
      <option>Enabled</option>
      <option>Disabled</option>
    </select>
  </div>

  <div class="setting-label">
    Language override (for runtime errors only):
  </div>
  <div class="setting-control">
    <select value={{locale}} on-change="setting-changed">
      <option value="">Use browser language or English when unavailable</option>
      {{#locales}}
      <option value={{code}}>{{description}}</option>
      {{/}}
    </select>
  </div>

  <label class="setting-label">
    View quality (number of actual pixels calculated per model pixel):
  </label>
  <div class="setting-control">
    <input type="number" min=1 step=1 value="{{viewQualitySetting}}" on-change="setting-changed" />
  </div>

</div>
"""

# (HtmlDivElement, NamespaceStorage) => Ractive
createSettingsRactive = (container, storage) ->
  data = { locales }
  settingNames.forEach( (name) ->
    setting = settings.get(name)
    data[setting.ractiveName] = if storage.hasKey(name)
      setting.in(storage.get(name))
    else
      setting.def
  )

  ractive = new Ractive({
    el: container
  , data
  , template
  , on: {
    'setting-changed': (_) ->
      settingNames.forEach( (name) =>
        setting = settings.get(name)
        value   = @get(setting.ractiveName)
        if setting.def is value
          storage.remove(name)
        else
          storage.set(name, setting.out(value))

        return
      )

      return
  }
  })
  ractive

export { createSettingsRactive }
