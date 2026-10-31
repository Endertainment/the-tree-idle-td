# Android release keystore (local only)

`tools/keystore/release.keystore` is **never committed** (`*.keystore` is in
`.gitignore`). It lives only on the build machine. Back it up offline: losing it
means you cannot publish an update for `com.endertainment.thetree`.

## Placeholder password

> **Password:** `CHANGE_ME_THE_TREE_2026`
> **Alias:** `thetree`
> **Distinguished name:** `CN=The Tree, OU=Games, O=Entertainment, L=Kyiv, C=UA`

The password above is a **placeholder for local QA builds**. Before a real Play
Console upload, regenerate the keystore with your own password and update this
file. `tools/export_release.ps1` reads the password from this line, or from the
`THE_TREE_KEYSTORE_PASSWORD` environment variable when set.

## Regenerate

```powershell
& "C:\Tools\jdk-17\bin\keytool.exe" -genkeypair -v `
  -keystore tools/keystore/release.keystore -alias thetree `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass <password> -keypass <password> `
  -dname "CN=The Tree, OU=Games, O=Entertainment, L=Kyiv, C=UA"
```

## Build

```powershell
pwsh -NoProfile -File tools/export_release.ps1
```

The script injects the absolute keystore path and the password into a temporary
copy of `export_presets.cfg`, exports `build/the-tree.aab`, and restores the
committed preset (which contains no secret) even when the export fails.
